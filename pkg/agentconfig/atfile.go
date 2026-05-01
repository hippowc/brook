package agentconfig

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ExpandAtFileRefs 将 instruction、user_prompt 中以 @ 开头的路径替换为文件内容。
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
	if r.Modes.Custom != nil {
		r.Modes.Custom.Script, err = resolveBundlePath(r.Modes.Custom.Script, configDir, "modes.custom.script")
		if err != nil {
			return err
		}
		r.Modes.Custom.AgentsFile, err = resolveBundlePath(r.Modes.Custom.AgentsFile, configDir, "modes.custom.agents_file")
		if err != nil {
			return err
		}
	}
	return nil
}

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
