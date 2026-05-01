package agentconfig

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// PatchAgentModeInYAMLFile 仅写入 agent.mode，并补齐目标模式最小配置（modes.* + agents 占位）。
func PatchAgentModeInYAMLFile(path string, mode AgentMode) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var doc map[string]any
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("agentconfig: parse yaml: %w", err)
	}
	agent, ok := doc["agent"].(map[string]any)
	if !ok {
		return fmt.Errorf("agentconfig: missing or invalid agent section")
	}
	agent["mode"] = string(mode)
	doc["agent"] = agent

	modesAny, _ := doc["modes"].(map[string]any)
	if modesAny == nil {
		modesAny = map[string]any{}
	}
	defModes, defAgents := DefaultModeState(mode)
	switch mode {
	case ModeDeep:
		modesAny["deep"] = map[string]any{}
	case ModeSequential:
		modesAny["sequential"] = map[string]any{"agent_ids": defModes.Sequential.AgentIDs}
	case ModeParallel:
		modesAny["parallel"] = map[string]any{"agent_ids": defModes.Parallel.AgentIDs}
	case ModeLoop:
		modesAny["loop"] = map[string]any{"agent_ids": defModes.Loop.AgentIDs, "max_iterations": defModes.Loop.MaxIterations}
	case ModeSupervisor:
		modesAny["supervisor"] = map[string]any{"supervisor_id": defModes.Supervisor.SupervisorID, "worker_ids": defModes.Supervisor.WorkerIDs}
	case ModePlanExecute:
		modesAny["plan_execute"] = map[string]any{"planner_id": defModes.PlanExecute.PlannerID, "executor_id": defModes.PlanExecute.ExecutorID, "replanner_id": defModes.PlanExecute.ReplannerID}
	case ModeCustom:
		if _, ok := modesAny["custom"]; !ok {
			modesAny["custom"] = map[string]any{}
		}
	}
	doc["modes"] = modesAny

	if len(defAgents) > 0 {
		agentsAny, _ := doc["agents"].(map[string]any)
		if agentsAny == nil {
			agentsAny = map[string]any{}
		}
		for id, spec := range defAgents {
			if _, exists := agentsAny[id]; exists {
				continue
			}
			agentsAny[id] = map[string]any{"name": spec.Name, "instruction": spec.Instruction}
		}
		doc["agents"] = agentsAny
	}

	out, err := yaml.Marshal(doc)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, out, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func TryValidateModeSwitch(r *Root, mode AgentMode) error {
	if r == nil {
		return fmt.Errorf("agentconfig: nil root")
	}
	cp := *r
	cp.Agent.Mode = mode
	defModes, defAgents := DefaultModeState(mode)
	switch mode {
	case ModeDeep:
		cp.Modes.Deep = defModes.Deep
	case ModeSequential:
		cp.Modes.Sequential = defModes.Sequential
	case ModeParallel:
		cp.Modes.Parallel = defModes.Parallel
	case ModeLoop:
		cp.Modes.Loop = defModes.Loop
	case ModeSupervisor:
		cp.Modes.Supervisor = defModes.Supervisor
	case ModePlanExecute:
		cp.Modes.PlanExecute = defModes.PlanExecute
	case ModeCustom:
		if cp.Modes.Custom == nil {
			cp.Modes.Custom = &CustomModeConfig{}
		}
	}
	if cp.Agents == nil {
		cp.Agents = map[string]SubAgentSpec{}
	}
	for id, spec := range defAgents {
		if _, ok := cp.Agents[id]; !ok {
			cp.Agents[id] = spec
		}
	}
	return cp.Validate()
}
