# Brook 配置指南（v2）

本文对应当前配置结构：`agent.mode + agents + modes.*`。字段定义以 `pkg/agentconfig/types.go` 与 `pkg/agentconfig/validate.go` 为准。

## 1. 结构总览

```yaml
version: "2"
agent:
  mode: react
  name: brook-assistant
  instruction: "..."

agents: {}

modes:
  deep: {}
  sequential: { agent_ids: [step_a, step_b] }
  parallel: { agent_ids: [step_a, step_b] }
  loop: { agent_ids: [loop_worker], max_iterations: 5 }
  supervisor: { supervisor_id: supervisor, worker_ids: [worker_1] }
  plan_execute: { planner_id: planner, executor_id: executor, replanner_id: planner }
  custom: { script: "@./custom/orchestrate.star", agents_file: "@./custom/agents.yaml", params: {} }

models: ...
memory: ...
interrupt: ...
gateway: ...
```

- `agent.mode` 只是**激活哪个模式**。
- 模式专属参数都在 `modes.<mode>`。
- 可复用子 Agent 放在顶层 `agents`，模式里通过 id 引用。

## 2. agent.mode 说明

| mode | 必要配置 | 说明 |
|---|---|---|
| `react` | 无 | 单 Agent ReAct |
| `deep` | 无（`modes.deep.agent_ids` 可选） | DeepAgents，可先零配置运行 |
| `sequential` | `modes.sequential.agent_ids` | 按顺序执行子 Agent |
| `parallel` | `modes.parallel.agent_ids` | 并行执行子 Agent |
| `loop` | `modes.loop.agent_ids` | 循环执行，可配 `max_iterations` |
| `supervisor` | `modes.supervisor.supervisor_id` + `worker_ids` | supervisor 调度 workers |
| `plan_execute` | `modes.plan_execute.planner_id` + `executor_id` | 可选 `replanner_id`（空时默认 planner） |
| `custom` | 可空（未配置脚本会进入创建模式） | Starlark 编排 |

## 3. custom 模式

```yaml
agent:
  mode: custom

modes:
  custom:
    script: "@./custom/orchestrate.star"
    agents_file: "@./custom/agents.yaml"
    params:
      random_seed: 1
```

- `script` 为主编排 `.star` 文件。
- `agents_file` 为空时，默认取脚本同目录 `agents.yaml`。
- TUI 支持：`/custom build` 生成文件，`/custom run` 切回使用。

## 4. /agent mode 的行为

`/agent mode <X>` 会：
1. 改写 `agent.mode=X`
2. 若 `modes.X` 缺失，则补最小模板
3. 对需要子 Agent 的模式，自动补示例 `agents` 占位（不会覆盖你已存在的同名 agent）

## 5. @ 文件引用

- `agent.instruction` / `agent.user_prompt` 支持 `"@path"` 读取文件内容。
- `modes.custom.script` / `modes.custom.agents_file` 支持 `@` 路径并解析为绝对路径。
- 相对路径基于 `agent.yaml` 所在目录。

## 6. gateway

`brook gateway` 与 TUI/CLI 读取同一份 `agent.yaml`。
- 开启：`gateway.enabled: true`
- 常用：`listen`、`auth`、`rate_limit`、`session`

## 7. 参考文件

- 完整示例：`config/agent.example.yaml`
- custom 示例：`config/examples/custom/README.md`
- 默认初始化模板：`internal/brookdir/default_agent.yaml`
