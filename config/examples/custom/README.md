# Custom 模式示例（Starlark + agents.yaml）

1. 将本目录复制到任意位置，或在主配置 `agent.yaml` 中设置：

```yaml
agent:
  mode: custom
  custom_script: "@./config/examples/custom/orchestrate.star"
  # custom_agents_file 省略时默认使用与脚本同目录的 agents.yaml
```

2. `orchestrate.star` 必须定义顶层函数 `run(user_text)`，返回字符串作为对用户的主回复。

3. 内置函数（见脚本内注释）：`cfg`、`state`、`call`、`read_text`、`load_yaml`、`rand_shuffle`。

4. TUI：在 `agent.mode=custom` 下使用 `/custom build` 进入 LLM 创建助手，`/custom run` 回到按脚本编排的对话。
