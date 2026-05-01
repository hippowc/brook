# Custom 模式示例（Starlark + agents.yaml）

在主配置 `agent.yaml` 中启用：

```yaml
agent:
  mode: custom

modes:
  custom:
    script: "@./config/examples/custom/orchestrate.star"
    # agents_file 省略时默认使用与脚本同目录的 agents.yaml
```

说明：
1. `orchestrate.star` 必须定义顶层函数 `run(user_text)`，返回字符串作为主回复。
2. 内置函数（见脚本注释）：`cfg`、`state`、`call`、`read_text`、`load_yaml`、`rand_shuffle`。
3. TUI：`/custom build` 进入创建模式，`/custom run` 回到脚本编排使用模式。
