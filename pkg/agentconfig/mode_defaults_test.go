package agentconfig

import "testing"

func TestTryValidateModeSwitch_WithDefaults(t *testing.T) {
	r := &Root{
		Version: "2",
		Agent:   AgentSpec{Mode: ModeReAct, Name: "a", Instruction: "x", MaxIterations: 10, Tools: ToolsSpec{}},
		Models:  ModelsSpec{Providers: map[string]ProviderConfig{"p": {Driver: "openai"}}, Active: ModelRef{Provider: "p", Model: "m"}},
		Memory:  MemorySpec{SessionStore: "memory"},
	}

	for _, mode := range []AgentMode{ModeReAct, ModeDeep, ModeSequential, ModeParallel, ModeLoop, ModeSupervisor, ModePlanExecute, ModeCustom} {
		if err := TryValidateModeSwitch(r, mode); err != nil {
			t.Fatalf("TryValidateModeSwitch(%s): %v", mode, err)
		}
	}
}

func TestDefaultModeState_Sequential(t *testing.T) {
	m, agents := DefaultModeState(ModeSequential)
	if m.Sequential == nil || len(m.Sequential.AgentIDs) < 2 {
		t.Fatalf("unexpected sequential default: %#v", m.Sequential)
	}
	if len(agents) < 2 {
		t.Fatalf("unexpected agents defaults: %#v", agents)
	}
}
