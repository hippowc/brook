# codex 常见用法（OpenAI 终端编码 agent）

## 启动与模式

```bash
codex                    # 交互式 REPL（流式输出，推荐日常）
codex exec "任务描述"     # 一次性执行（脚本里用，非交互）
codex plan "任务"        # 先给方案不动手
codex 对话内换模型: /model
```

## 配置（第一优先：brook config）

```bash
brook config codex bailian      # 接入百炼（qwen/deepseek/glm 四模型目录 + key）
# key 存 ~/.bashrc 的 export OPENAI_API_KEY=...（brook 会自动持久化）
```

## 模型切换

```bash
/model                        # 会话内切换（qwen3.8-max-preview / deepseek-v4-pro / deepseek-v4-flash / glm-5.2）
/mode                         # 普通/全自动 模式切换
```

## 常用对话技巧

```bash
/p 查看提示词；/status 看当前模型与模式；/tokens 看上下文占用
# 任务写具体：目标+约束+验收；长线程提前拆小任务（防上下文压缩失真）
# 新主题开新线程（长线程多次压缩会降精度，上方已选 1M 窗口可多撑一会）
```

## 与 brook

- 装完先 `brook config codex bailian`，否则没有可用模型
- 百炼不通时：确认 key/网络；或换 provider（后续 brook 会支持 deepseek 官方/硅基）

## 排查

- 卡在 Working 无输出 → 模型思考阶段（大窗口下正常），耐心等
- `model not found` → catalog 没配对，重跑 `brook config codex bailian`
- 上下文报错超限 → /tokens 看占用，新开线程
