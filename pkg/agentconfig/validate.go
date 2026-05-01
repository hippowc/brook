package agentconfig

import (
	"fmt"
	"path/filepath"
	"strings"
)

// Validate 对 Root 做基本一致性校验。
func (r *Root) Validate() error {
	if r == nil {
		return fmt.Errorf("agentconfig: root is nil")
	}
	if r.Version == "" {
		r.Version = "2"
	}
	if err := r.Agent.validate(); err != nil {
		return err
	}
	if err := r.Models.validate(); err != nil {
		return err
	}
	if r.Memory.SessionStore == "file" && strings.TrimSpace(r.Memory.SessionFilePath) == "" {
		return fmt.Errorf("agentconfig: memory.session_file_path required when session_store=file")
	}
	if r.Interrupt.Enabled && strings.EqualFold(r.Interrupt.CheckpointBackend, "file") &&
		strings.TrimSpace(r.Interrupt.CheckpointFilePath) == "" {
		return fmt.Errorf("agentconfig: interrupt.checkpoint_file_path required when checkpoint_backend=file")
	}
	if err := r.validateMode(); err != nil {
		return err
	}
	if err := r.validateAgentsRefs(); err != nil {
		return err
	}
	if err := r.Gateway.validate(); err != nil {
		return err
	}
	return nil
}

func (r *Root) validateAgentsRefs() error {
	if len(r.Agents) == 0 {
		return nil
	}
	for id := range r.Agents {
		if strings.TrimSpace(id) == "" {
			return fmt.Errorf("agentconfig: agents contains empty id")
		}
	}
	checkIDs := func(field string, ids []string) error {
		for _, id := range ids {
			id = strings.TrimSpace(id)
			if id == "" {
				continue
			}
			if _, ok := r.Agents[id]; !ok {
				return fmt.Errorf("agentconfig: %s references unknown agent id %q", field, id)
			}
		}
		return nil
	}
	if m := r.Modes.Deep; m != nil {
		if err := checkIDs("modes.deep.agent_ids", m.AgentIDs); err != nil {
			return err
		}
	}
	if m := r.Modes.Sequential; m != nil {
		if err := checkIDs("modes.sequential.agent_ids", m.AgentIDs); err != nil {
			return err
		}
	}
	if m := r.Modes.Parallel; m != nil {
		if err := checkIDs("modes.parallel.agent_ids", m.AgentIDs); err != nil {
			return err
		}
	}
	if m := r.Modes.Loop; m != nil {
		if err := checkIDs("modes.loop.agent_ids", m.AgentIDs); err != nil {
			return err
		}
	}
	if m := r.Modes.Supervisor; m != nil {
		if err := checkIDs("modes.supervisor.worker_ids", m.WorkerIDs); err != nil {
			return err
		}
		if strings.TrimSpace(m.SupervisorID) != "" {
			if _, ok := r.Agents[m.SupervisorID]; !ok {
				return fmt.Errorf("agentconfig: modes.supervisor.supervisor_id references unknown agent id %q", m.SupervisorID)
			}
		}
	}
	if m := r.Modes.PlanExecute; m != nil {
		if err := checkIDs("modes.plan_execute", []string{m.PlannerID, m.ExecutorID, m.ReplannerID}); err != nil {
			return err
		}
	}
	return nil
}

func (r *Root) validateMode() error {
	switch r.Agent.Mode {
	case ModeSequential:
		if r.Modes.Sequential == nil || len(r.Modes.Sequential.AgentIDs) == 0 {
			return fmt.Errorf("agentconfig: modes.sequential.agent_ids required when agent.mode=sequential")
		}
	case ModeParallel:
		if r.Modes.Parallel == nil || len(r.Modes.Parallel.AgentIDs) == 0 {
			return fmt.Errorf("agentconfig: modes.parallel.agent_ids required when agent.mode=parallel")
		}
	case ModeLoop:
		if r.Modes.Loop == nil || len(r.Modes.Loop.AgentIDs) == 0 {
			return fmt.Errorf("agentconfig: modes.loop.agent_ids required when agent.mode=loop")
		}
	case ModeSupervisor:
		if r.Modes.Supervisor == nil || strings.TrimSpace(r.Modes.Supervisor.SupervisorID) == "" || len(r.Modes.Supervisor.WorkerIDs) == 0 {
			return fmt.Errorf("agentconfig: modes.supervisor.supervisor_id and worker_ids are required when agent.mode=supervisor")
		}
	case ModePlanExecute:
		if r.Modes.PlanExecute == nil {
			return fmt.Errorf("agentconfig: modes.plan_execute required when agent.mode=plan_execute")
		}
		pe := r.Modes.PlanExecute
		if strings.TrimSpace(pe.PlannerID) == "" || strings.TrimSpace(pe.ExecutorID) == "" {
			return fmt.Errorf("agentconfig: modes.plan_execute.planner_id and executor_id are required")
		}
		if strings.TrimSpace(pe.ReplannerID) == "" {
			pe.ReplannerID = pe.PlannerID
		}
	case ModeCustom:
		// script 可空：未配置时由运行时占位 Agent / TUI 创建模式处理。
	}
	return nil
}

func (g *GatewaySpec) validate() error {
	if !g.Enabled {
		return nil
	}
	if strings.TrimSpace(g.Listen) == "" {
		g.Listen = ":8787"
	}
	mode := strings.ToLower(strings.TrimSpace(g.Auth.Mode))
	if mode == "" {
		mode = "none"
		g.Auth.Mode = "none"
	}
	switch mode {
	case "none", "bearer", "hmac":
	default:
		return fmt.Errorf("agentconfig: gateway.auth.mode must be none, bearer or hmac, got %q", g.Auth.Mode)
	}
	if mode == "bearer" && strings.TrimSpace(g.Auth.BearerTokenEnv) == "" {
		return fmt.Errorf("agentconfig: gateway.auth.bearer_token_env required when auth.mode=bearer")
	}
	if mode == "hmac" && strings.TrimSpace(g.Auth.HMACSecretEnv) == "" {
		return fmt.Errorf("agentconfig: gateway.auth.hmac_secret_env required when auth.mode=hmac")
	}
	store := strings.ToLower(strings.TrimSpace(g.Session.Store))
	if store == "" {
		store = "file"
		g.Session.Store = "file"
	}
	switch store {
	case "memory", "file":
	default:
		return fmt.Errorf("agentconfig: gateway.session.store must be memory or file, got %q", g.Session.Store)
	}
	if g.Session.FileDir != "" && !filepath.IsAbs(g.Session.FileDir) {
		return fmt.Errorf("agentconfig: gateway.session.file_dir must be absolute path, got %q", g.Session.FileDir)
	}
	if g.RateLimit != nil && g.RateLimit.Enabled {
		if g.RateLimit.RequestsPerMinute <= 0 {
			g.RateLimit.RequestsPerMinute = 120
		}
		if g.RateLimit.Burst <= 0 {
			g.RateLimit.Burst = 30
		}
	}
	return nil
}

func (a *AgentSpec) validate() error {
	if strings.TrimSpace(a.Name) == "" {
		return fmt.Errorf("agentconfig: agent.name is required")
	}
	if a.Mode == "" {
		a.Mode = ModeReAct
	}
	switch a.Mode {
	case ModeReAct, ModeDeep, ModeSequential, ModeParallel, ModeLoop, ModeSupervisor, ModePlanExecute, ModeCustom:
	default:
		return fmt.Errorf("agentconfig: unknown agent.mode %q", a.Mode)
	}
	if a.MaxIterations == 0 {
		a.MaxIterations = 20
	}
	if a.WorkingDirectory != "" && !filepath.IsAbs(a.WorkingDirectory) {
		return fmt.Errorf("agentconfig: agent.working_directory must be absolute path, got %q", a.WorkingDirectory)
	}
	if a.Tools.Filesystem != nil && a.Tools.Filesystem.Enabled {
		if a.Tools.Filesystem.Backend == "" {
			return fmt.Errorf("agentconfig: tools.filesystem.backend is required when filesystem.enabled")
		}
		if a.Tools.Filesystem.Shell && a.Tools.Filesystem.StreamingShell {
			return fmt.Errorf("agentconfig: filesystem.shell and filesystem.streaming_shell are mutually exclusive")
		}
	}
	return nil
}

func (m *ModelsSpec) validate() error {
	if len(m.Providers) == 0 {
		return fmt.Errorf("agentconfig: models.providers cannot be empty")
	}
	if strings.TrimSpace(m.Active.Provider) == "" || strings.TrimSpace(m.Active.Model) == "" {
		return fmt.Errorf("agentconfig: models.active.provider and models.active.model are required")
	}
	if _, ok := m.Providers[m.Active.Provider]; !ok {
		return fmt.Errorf("agentconfig: models.active.provider %q not found in providers", m.Active.Provider)
	}
	return nil
}
