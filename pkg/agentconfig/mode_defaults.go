package agentconfig

// DefaultModeState 切换 agent.mode 时补齐对应模式最小配置（仅该模式，不覆盖其他模式）。
func DefaultModeState(mode AgentMode) (modes ModesSpec, agents map[string]SubAgentSpec) {
	agents = map[string]SubAgentSpec{}
	switch mode {
	case ModeSequential:
		agents["step_a"] = SubAgentSpec{Name: "step_a", Instruction: "你是子步骤 A"}
		agents["step_b"] = SubAgentSpec{Name: "step_b", Instruction: "你是子步骤 B"}
		modes.Sequential = &SequentialModeConfig{AgentIDs: []string{"step_a", "step_b"}}
	case ModeParallel:
		agents["step_a"] = SubAgentSpec{Name: "step_a", Instruction: "你是并行子步骤 A"}
		agents["step_b"] = SubAgentSpec{Name: "step_b", Instruction: "你是并行子步骤 B"}
		modes.Parallel = &ParallelModeConfig{AgentIDs: []string{"step_a", "step_b"}}
	case ModeLoop:
		agents["loop_worker"] = SubAgentSpec{Name: "loop_worker", Instruction: "你是循环处理子 Agent"}
		modes.Loop = &LoopModeConfig{AgentIDs: []string{"loop_worker"}, MaxIterations: 5}
	case ModeSupervisor:
		agents["supervisor"] = SubAgentSpec{Name: "supervisor", Instruction: "你负责调度 worker"}
		agents["worker_1"] = SubAgentSpec{Name: "worker_1", Instruction: "你是 worker 1"}
		modes.Supervisor = &SupervisorModeConfig{SupervisorID: "supervisor", WorkerIDs: []string{"worker_1"}}
	case ModePlanExecute:
		agents["planner"] = SubAgentSpec{Name: "planner", Instruction: "你负责规划"}
		agents["executor"] = SubAgentSpec{Name: "executor", Instruction: "你负责执行"}
		modes.PlanExecute = &PlanExecuteModeConfig{PlannerID: "planner", ExecutorID: "executor", ReplannerID: "planner"}
	case ModeDeep:
		modes.Deep = &DeepModeConfig{}
	case ModeCustom:
		modes.Custom = &CustomModeConfig{}
	}
	if len(agents) == 0 {
		agents = nil
	}
	return modes, agents
}

func ModeSwitchUserHint(mode AgentMode) string {
	switch mode {
	case ModeSequential, ModeParallel, ModeLoop, ModeSupervisor, ModePlanExecute:
		return "已切换模式，并补齐该模式最小配置到 modes.*；子 Agent 定义位于顶层 agents。"
	case ModeDeep:
		return "已切换到 deep。deep 不强制要求子 Agent；可在 modes.deep.agent_ids 配置。"
	case ModeCustom:
		return "已切换到 custom。请在 modes.custom.script / modes.custom.agents_file 填写路径，或用 /custom build 生成。"
	default:
		return "已切换模式。"
	}
}
