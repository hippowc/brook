package agentconfig

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// PatchAgentModeInYAMLFile 写入 agent.mode，并按模式附带默认 mode_config（占位子 Agent 名等），其余键由 YAML 反序列化后再序列化（顺序可能变化）。
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
	mcMap, err := ModeConfigYAMLMap(mode)
	if err != nil {
		return fmt.Errorf("agentconfig: mode_config for %q: %w", mode, err)
	}
	agent["mode_config"] = mcMap
	if mode == ModeCustom {
		// 不写入占位路径；由用户在 agent.yaml 填写 custom_script，或在 TUI「创建」模式中生成。
	} else {
		delete(agent, "custom_script")
		delete(agent, "custom_agents_file")
		delete(agent, "custom_params")
	}
	doc["agent"] = agent
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

// TryValidateModeSwitch 在写入与 PatchAgentModeInYAMLFile 相同的 mode + 默认 mode_config 后校验配置是否合法。
func TryValidateModeSwitch(r *Root, mode AgentMode) error {
	if r == nil {
		return fmt.Errorf("agentconfig: nil root")
	}
	cp := *r
	cp.Agent.Mode = mode
	cp.Agent.ModeConfig = DefaultModeConfig(mode)
	return cp.Validate()
}
