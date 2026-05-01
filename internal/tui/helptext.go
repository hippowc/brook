package tui

// TUIHelpText 为输入 /help 时展示的简短说明。
const TUIHelpText = `Brook TUI 内置命令（在输入框输入）：
  /help          本说明
  /config        用编辑器打开当前 agent.yaml
  /session new   开始新会话（新对话存档）
  /session list  列出最近会话（含短 ID、名称、预览）
  /session open <id|前缀>  打开已有会话
  /session rename <名称>   给当前会话重命名
  /agent mode X  切换 agent.mode，并补齐该模式最小配置到 modes.*（X 见下表）
  /custom build  仅当 agent.mode=custom：进入「创建」模式，用 LLM 辅助编写 Starlark / agents.yaml
  /custom run    回到「使用」模式（按 modes.custom.script 编排对话）

agent.mode 一览（具体参数在 modes.<mode> 下）：
  react          单 Agent ReAct
  deep           DeepAgents（可选 modes.deep.agent_ids）
  sequential     顺序执行 modes.sequential.agent_ids
  parallel       并行执行 modes.parallel.agent_ids
  loop           循环执行 modes.loop.agent_ids
  supervisor     调度 modes.supervisor.supervisor_id + worker_ids
  plan_execute   使用 modes.plan_execute planner/executor/replanner
  custom         使用 modes.custom.script / agents_file

更全说明：config/docs/agent-configuration-guide.md、config/agent.example.yaml 与 config/examples/custom/README.md。
`
