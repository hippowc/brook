package agentconfig

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ExpandAtFileRefs 将 instruction、user_prompt 中以 @ 开头的路径替换为文件内容（通常为 Markdown）。
// 形式：整段为 "@路径" 或 "@路径" 前后可有空白；路径可为绝对路径，或与配置文件同目录的相对路径。
// configDir 为 agent.yaml 所在目录；为空时不展开（用于无路径的 LoadYAML 测试）。
func ExpandAtFileRefs(r *Root, configDir string) error {
	if r == nil || configDir == "" {
		return nil
	}
	configDir = filepath.Clean(configDir)
	var err error
	r.Agent.Instruction, err = expandAtField(r.Agent.Instruction, configDir, "agent.instruction")
	if err != nil {
		return err
	}
	r.Agent.UserPrompt, err = expandAtField(r.Agent.UserPrompt, configDir, "agent.user_prompt")
	if err != nil {
		return err
	}
	r.Agent.CustomScript, err = resolveBundlePath(r.Agent.CustomScript, configDir, "agent.custom_script")
	if err != nil {
		return err
	}
	r.Agent.CustomAgentsFile, err = resolveBundlePath(r.Agent.CustomAgentsFile, configDir, "agent.custom_agents_file")
	if err != nil {
		return err
	}
	return nil
}

// resolveBundlePath 将 @path 或相对路径解析为绝对路径（不读取文件内容）；空字符串保持不变。
func resolveBundlePath(s, configDir, field string) (string, error) {
	raw := strings.TrimSpace(s)
	if raw == "" {
		return "", nil
	}
	path := raw
	if strings.HasPrefix(raw, "@") {
		path = strings.TrimSpace(raw[1:])
		if path == "" {
			return "", fmt.Errorf("agentconfig: %s: empty path after @", field)
		}
	}
	if !filepath.IsAbs(path) {
		path = filepath.Join(configDir, path)
	}
	return filepath.Clean(path), nil
}

func expandAtField(s, configDir, field string) (string, error) {
	raw := strings.TrimSpace(s)
	if raw == "" || !strings.HasPrefix(raw, "@") {
		return s, nil
	}
	path := strings.TrimSpace(raw[1:])
	if path == "" {
		return "", fmt.Errorf("agentconfig: %s: empty path after @", field)
	}
	if !filepath.IsAbs(path) {
		path = filepath.Join(configDir, path)
	}
	path = filepath.Clean(path)
	b, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("agentconfig: %s: read %q: %w", field, path, err)
	}
	return string(b), nil
}
