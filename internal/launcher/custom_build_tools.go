package launcher

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudwego/eino/components/tool"
	toolutils "github.com/cloudwego/eino/components/tool/utils"
	"gopkg.in/yaml.v3"

	"github.com/hippowc/brook/internal/brookdir"
)

// normalizePathUnderCustomDir 去掉误传的 custom/ 前缀：写入根目录已是 ~/.brook/custom，
// 若再传 custom/orchestrate.star 会变成 ~/.brook/custom/custom/orchestrate.star，与 modes.custom.script=@./custom/orchestrate.star 不一致。
func normalizePathUnderCustomDir(rel string) string {
	rel = filepath.ToSlash(strings.TrimSpace(rel))
	rel = filepath.Clean(rel)
	for strings.HasPrefix(rel, "custom/") {
		rel = strings.TrimPrefix(rel, "custom/")
		rel = filepath.ToSlash(filepath.Clean(rel))
	}
	if rel == "." || rel == "custom" {
		return ""
	}
	return rel
}

type saveCustomFileParams struct {
	RelativePath string `json:"relative_path" jsonschema:"description=相对于 ~/.brook/custom 的路径：直接写 orchestrate.star、agents.yaml（不要带 custom/ 前缀，否则会多一层目录）"`
	Content      string `json:"content" jsonschema:"description=文件完整内容"`
}

type saveCustomFileResult struct {
	SavedPath string `json:"saved_path"`
	Message   string `json:"message"`
}

type activateCustomBundleParams struct {
	CustomScriptRef string `json:"custom_script_ref" jsonschema:"description=写入主配置 modes.custom.script，相对 agent.yaml 所在目录；推荐 @./custom/orchestrate.star"`
	CustomAgentsRef string `json:"custom_agents_file_ref" jsonschema:"description=可选，写入 modes.custom.agents_file，推荐 @./custom/agents.yaml"`
}

type activateCustomBundleResult struct {
	AgentYAML string `json:"agent_yaml"`
	Message   string `json:"message"`
}

func newCustomBuildTools(agentYAMLPath string) ([]tool.BaseTool, error) {
	saveT, err := toolutils.InferTool(
		"save_custom_file",
		"将内容写入 ~/.brook/custom/ 下指定相对路径（禁止 ..）。relative_path 不要带 custom/ 前缀（根目录已是 custom）。生成 orchestrate.star、agents.yaml 等后必须调用本工具保存，仅聊天输出不会落盘。",
		func(ctx context.Context, in saveCustomFileParams) (saveCustomFileResult, error) {
			_ = ctx
			rel := strings.TrimSpace(in.RelativePath)
			if rel == "" {
				return saveCustomFileResult{}, fmt.Errorf("relative_path is required")
			}
			if strings.Contains(rel, "..") {
				return saveCustomFileResult{}, fmt.Errorf("relative_path must not contain ..")
			}
			root, err := brookdir.CustomDir()
			if err != nil {
				return saveCustomFileResult{}, err
			}
			if err := os.MkdirAll(root, 0o755); err != nil {
				return saveCustomFileResult{}, err
			}
			rel = normalizePathUnderCustomDir(rel)
			if rel == "" {
				return saveCustomFileResult{}, fmt.Errorf("relative_path is invalid after normalization")
			}
			rel = filepath.ToSlash(filepath.Clean(rel))
			full := filepath.Join(root, filepath.FromSlash(rel))
			rp, err := filepath.Rel(root, full)
			if err != nil || strings.HasPrefix(rp, "..") {
				return saveCustomFileResult{}, fmt.Errorf("path escapes ~/.brook/custom")
			}
			if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
				return saveCustomFileResult{}, err
			}
			if err := os.WriteFile(full, []byte(in.Content), 0o600); err != nil {
				return saveCustomFileResult{}, err
			}
			return saveCustomFileResult{
				SavedPath: full,
				Message:   "已保存。若编排已齐，请调用 activate_custom_bundle 将主配置指向这些文件。",
			}, nil
		},
	)
	if err != nil {
		return nil, err
	}

	agentPath := strings.TrimSpace(agentYAMLPath)
	actT, err := toolutils.InferTool(
		"activate_custom_bundle",
		"更新主 agent.yaml：设置 modes.custom.script（及可选 custom_agents_file）为相对路径，使 Brook 从 ~/.brook/custom/ 加载 bundle。通常在 save_custom_file 写入 orchestrate.star 与 agents.yaml 后调用。",
		func(ctx context.Context, in activateCustomBundleParams) (activateCustomBundleResult, error) {
			_ = ctx
			p := agentPath
			if p == "" {
				var err error
				p, err = brookdir.AgentYAML()
				if err != nil {
					return activateCustomBundleResult{}, err
				}
			}
			scriptRef := strings.TrimSpace(in.CustomScriptRef)
			if scriptRef == "" {
				scriptRef = "@./custom/orchestrate.star"
			}
			agentsRef := strings.TrimSpace(in.CustomAgentsRef)
			if agentsRef == "" {
				agentsRef = "@./custom/agents.yaml"
			}
			if err := patchAgentYAMLCustomRefs(p, scriptRef, agentsRef); err != nil {
				return activateCustomBundleResult{}, err
			}
			return activateCustomBundleResult{
				AgentYAML: p,
				Message:   "已更新主配置。在 TUI 中执行 /custom run 会从磁盘重新加载并切回使用模式。",
			}, nil
		},
	)
	if err != nil {
		return nil, err
	}

	return []tool.BaseTool{saveT, actT}, nil
}

func patchAgentYAMLCustomRefs(agentYAMLPath, customScriptRef, customAgentsRef string) error {
	data, err := os.ReadFile(agentYAMLPath)
	if err != nil {
		return fmt.Errorf("read agent yaml: %w", err)
	}
	var doc map[string]any
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("parse agent yaml: %w", err)
	}
	agent, ok := doc["agent"].(map[string]any)
	if !ok {
		return fmt.Errorf("agent yaml: missing agent section")
	}
	modes, _ := doc["modes"].(map[string]any)
	if modes == nil {
		modes = map[string]any{}
	}
	custom, _ := modes["custom"].(map[string]any)
	if custom == nil {
		custom = map[string]any{}
	}
	custom["script"] = customScriptRef
	custom["agents_file"] = customAgentsRef
	modes["custom"] = custom
	doc["modes"] = modes
	agent["mode"] = "custom"
	doc["agent"] = agent
	out, err := yaml.Marshal(doc)
	if err != nil {
		return err
	}
	tmp := agentYAMLPath + ".tmp"
	if err := os.WriteFile(tmp, out, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, agentYAMLPath)
}
