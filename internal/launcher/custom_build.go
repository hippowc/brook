// Package launcher 的 CustomBuildRunner：TUI「创建」模式下调试用 LLM 辅助编写 Starlark / agents.yaml（与主 Runner 独立）。
package launcher

import (
	"context"
	"fmt"

	"github.com/cloudwego/eino/adk"
	"github.com/cloudwego/eino/compose"

	agentmodel "github.com/hippowc/brook/internal/core/model"
	"github.com/hippowc/brook/pkg/agentconfig"
)

const customBuildSystemInstruction = `你是 Brook 的「自定义 Agent 编排」助手。文件落盘根目录已是 ~/.brook/custom/，因此 save_custom_file 的 relative_path 只写 orchestrate.star、agents.yaml 等，不要写 custom/orchestrate.star（否则会多一层 custom/custom/）。

你必须使用提供的工具将文件真正写入磁盘，并在完成后激活主配置：
1) save_custom_file：relative_path 例如 orchestrate.star、agents.yaml（可带子目录如 prompts/a.md，但不要以 custom/ 开头）。
2) activate_custom_bundle：在 orchestrate.star 与 agents.yaml 均已 save 成功后调用；custom_script_ref 推荐 @./custom/orchestrate.star，custom_agents_file_ref 推荐 @./custom/agents.yaml。

Starlark 须定义顶层函数 run(user_text)；内置：cfg、state、call(agent_id, content)、read_text、load_yaml、rand_shuffle。
agents.yaml 使用 agents: [{id,name,instruction}, ...]。
不要编造未提供的 API；说明可配合 Markdown 代码块，但最终必须以工具落盘。`

// CustomBuildRunner 构造专用于「创建模式」的 Runner（带写盘与激活配置工具），与主 Agent 隔离。
// agentYAMLPath 为主 agent.yaml 绝对路径，用于 activate_custom_bundle；空则使用 ~/.brook/agent.yaml。
func CustomBuildRunner(ctx context.Context, root *agentconfig.Root, agentYAMLPath string) (*adk.Runner, error) {
	if root.Agent.Mode != agentconfig.ModeCustom {
		return nil, fmt.Errorf("launcher: CustomBuildRunner only for agent.mode=custom")
	}
	cm, err := agentmodel.NewChatModel(ctx, root)
	if err != nil {
		return nil, err
	}
	tools, err := newCustomBuildTools(agentYAMLPath)
	if err != nil {
		return nil, err
	}
	ag, err := adk.NewChatModelAgent(ctx, &adk.ChatModelAgentConfig{
		Name:            "brook_custom_bundle_assistant",
		Description:     "LLM assistant for authoring Starlark custom bundles",
		Instruction:     customBuildSystemInstruction,
		Model:           cm,
		MaxIterations:   16,
		OutputKey:       "",
		ToolsConfig: adk.ToolsConfig{
			ToolsNodeConfig: compose.ToolsNodeConfig{
				Tools: tools,
			},
			ReturnDirectly: nil,
		},
	})
	if err != nil {
		return nil, err
	}
	return adk.NewRunner(ctx, adk.RunnerConfig{
		Agent:           ag,
		EnableStreaming: true,
	}), nil
}
