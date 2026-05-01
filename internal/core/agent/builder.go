// Package agent 根据 agentconfig 构造 adk.Agent（多种模式）。
package agent

import (
	"context"
	"fmt"
	"strings"

	"github.com/cloudwego/eino/adk"
	"github.com/cloudwego/eino/adk/prebuilt/deep"
	"github.com/cloudwego/eino/adk/prebuilt/planexecute"
	"github.com/cloudwego/eino/adk/prebuilt/supervisor"
	einomodel "github.com/cloudwego/eino/components/model"
	"github.com/cloudwego/eino/compose"

	agentfs "github.com/hippowc/brook/internal/core/fs"
	agentmodel "github.com/hippowc/brook/internal/core/model"
	extmw "github.com/hippowc/brook/internal/extension/middleware"
	"github.com/hippowc/brook/pkg/agentconfig"
)

func Build(ctx context.Context, root *agentconfig.Root) (adk.Agent, error) {
	if err := root.Validate(); err != nil {
		return nil, err
	}
	cm, err := agentmodel.NewChatModel(ctx, root)
	if err != nil {
		return nil, err
	}
	bundle, err := agentfs.Build(ctx, root)
	if err != nil {
		return nil, err
	}
	extraMW, err := extmw.FromRefs(ctx, root.Agent.Middlewares)
	if err != nil {
		return nil, err
	}

	switch root.Agent.Mode {
	case agentconfig.ModeReAct:
		return buildReact(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeDeep:
		return buildDeep(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeSequential:
		return buildSequential(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeParallel:
		return buildParallel(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeLoop:
		return buildLoop(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeSupervisor:
		return buildSupervisor(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModePlanExecute:
		return buildPlanExecute(ctx, root, cm, bundle, extraMW)
	case agentconfig.ModeCustom:
		return buildCustom(ctx, root, cm, bundle, extraMW)
	default:
		return nil, fmt.Errorf("agent: unknown mode %q", root.Agent.Mode)
	}
}

func chatHandlers(bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) []adk.ChatModelAgentMiddleware {
	var hs []adk.ChatModelAgentMiddleware
	if bundle != nil && bundle.Middleware != nil {
		hs = append(hs, bundle.Middleware)
	}
	hs = append(hs, extra...)
	hs = append(hs, newToolErrorAsObservationMiddleware())
	return hs
}

func buildReact(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	cfg := &adk.ChatModelAgentConfig{
		Name:          root.Agent.Name,
		Description:   root.Agent.Description,
		Instruction:   root.Agent.Instruction,
		Model:         cm,
		MaxIterations: root.Agent.MaxIterations,
		OutputKey:     root.Memory.OutputKey,
		Handlers:      chatHandlers(bundle, extra),
		ToolsConfig: adk.ToolsConfig{
			ToolsNodeConfig: compose.ToolsNodeConfig{},
			ReturnDirectly:  root.Agent.Tools.ReturnDirectly,
		},
	}
	return adk.NewChatModelAgent(ctx, cfg)
}

func buildDeep(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	var subs []adk.Agent
	if root.Modes.Deep != nil && len(root.Modes.Deep.AgentIDs) > 0 {
		var err error
		subs, err = buildNamedAgents(ctx, root, cm, bundle, extra, root.Modes.Deep.AgentIDs)
		if err != nil {
			return nil, err
		}
	}
	dc := &deep.Config{
		Name:         root.Agent.Name,
		Description:  root.Agent.Description,
		ChatModel:    cm,
		Instruction:  root.Agent.Instruction,
		SubAgents:    subs,
		MaxIteration: root.Agent.MaxIterations,
		OutputKey:    root.Memory.OutputKey,
		Handlers:     chatHandlers(bundle, extra),
		ToolsConfig:  adk.ToolsConfig{ToolsNodeConfig: compose.ToolsNodeConfig{}, ReturnDirectly: root.Agent.Tools.ReturnDirectly},
	}
	if root.Modes.Deep != nil {
		dc.WithoutWriteTodos = root.Modes.Deep.WithoutWriteTodos
		dc.WithoutGeneralSubAgent = root.Modes.Deep.WithoutGeneralSubAgent
		if root.Modes.Deep.MaxIteration > 0 {
			dc.MaxIteration = root.Modes.Deep.MaxIteration
		}
	}
	if bundle != nil {
		dc.Backend = bundle.Backend
		dc.Shell = bundle.Shell
		dc.StreamingShell = bundle.StreamingShell
	}
	return deep.New(ctx, dc)
}

func buildNamedAgents(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, _ []adk.ChatModelAgentMiddleware, ids []string) ([]adk.Agent, error) {
	var out []adk.Agent
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		spec, ok := root.Agents[id]
		if !ok {
			return nil, fmt.Errorf("agent: unknown agent id %q", id)
		}
		name := strings.TrimSpace(spec.Name)
		if name == "" {
			name = id
		}
		inst := strings.TrimSpace(spec.Instruction)
		if inst == "" {
			inst = root.Agent.Instruction + fmt.Sprintf("\n\n[Your role: sub-agent %q]", id)
		}
		cfg := &adk.ChatModelAgentConfig{
			Name:          name,
			Description:   root.Agent.Description + " / " + id,
			Instruction:   inst,
			Model:         cm,
			MaxIterations: root.Agent.MaxIterations,
			Handlers:      chatHandlers(bundle, nil),
			ToolsConfig:   adk.ToolsConfig{ToolsNodeConfig: compose.ToolsNodeConfig{}, ReturnDirectly: root.Agent.Tools.ReturnDirectly},
		}
		a, err := adk.NewChatModelAgent(ctx, cfg)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}

func buildSequential(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	subs, err := buildNamedAgents(ctx, root, cm, bundle, extra, root.Modes.Sequential.AgentIDs)
	if err != nil {
		return nil, err
	}
	return adk.NewSequentialAgent(ctx, &adk.SequentialAgentConfig{Name: root.Agent.Name, Description: root.Agent.Description, SubAgents: subs})
}

func buildParallel(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	subs, err := buildNamedAgents(ctx, root, cm, bundle, extra, root.Modes.Parallel.AgentIDs)
	if err != nil {
		return nil, err
	}
	return adk.NewParallelAgent(ctx, &adk.ParallelAgentConfig{Name: root.Agent.Name, Description: root.Agent.Description, SubAgents: subs})
}

func buildLoop(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	subs, err := buildNamedAgents(ctx, root, cm, bundle, extra, root.Modes.Loop.AgentIDs)
	if err != nil {
		return nil, err
	}
	maxIter := 3
	if root.Modes.Loop.MaxIterations > 0 {
		maxIter = root.Modes.Loop.MaxIterations
	}
	return adk.NewLoopAgent(ctx, &adk.LoopAgentConfig{Name: root.Agent.Name, Description: root.Agent.Description, SubAgents: subs, MaxIterations: maxIter})
}

func buildSupervisor(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	mc := root.Modes.Supervisor
	subs, err := buildNamedAgents(ctx, root, cm, bundle, extra, mc.WorkerIDs)
	if err != nil {
		return nil, err
	}
	spec := root.Agents[mc.SupervisorID]
	supInst := strings.TrimSpace(spec.Instruction)
	if supInst == "" {
		supInst = root.Agent.Instruction + "\n\nYou coordinate sub-agents."
	}
	sup, err := adk.NewChatModelAgent(ctx, &adk.ChatModelAgentConfig{
		Name:          mc.SupervisorID,
		Description:   root.Agent.Description + " (supervisor)",
		Instruction:   supInst,
		Model:         cm,
		MaxIterations: root.Agent.MaxIterations,
		Handlers:      chatHandlers(bundle, extra),
		ToolsConfig:   adk.ToolsConfig{ToolsNodeConfig: compose.ToolsNodeConfig{}, ReturnDirectly: root.Agent.Tools.ReturnDirectly},
	})
	if err != nil {
		return nil, err
	}
	return supervisor.New(ctx, &supervisor.Config{Supervisor: sup, SubAgents: subs})
}

func buildPlanExecute(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	pe := root.Modes.PlanExecute
	names := []string{pe.PlannerID, pe.ExecutorID, pe.ReplannerID}
	agents, err := buildNamedAgents(ctx, root, cm, bundle, extra, names)
	if err != nil {
		return nil, err
	}
	byName := map[string]adk.Agent{}
	for _, a := range agents {
		byName[a.Name(ctx)] = a
	}
	planner := byName[pe.PlannerID]
	exec := byName[pe.ExecutorID]
	replan := byName[pe.ReplannerID]
	if planner == nil || exec == nil || replan == nil {
		return nil, fmt.Errorf("agent: plan_execute agents not found for ids %+v", pe)
	}
	return planexecute.New(ctx, &planexecute.Config{Planner: planner, Executor: exec, Replanner: replan, MaxIterations: root.Agent.MaxIterations})
}
