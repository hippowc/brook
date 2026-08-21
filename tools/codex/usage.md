# codex 常见用法

终端编码 Agent：读代码、改文件、跑命令、提交 git。先跑 `brook config codex bailian` 配好模型后端。

## 启动

```bash
codex                             # 交互模式（最常用）
codex "解释这个项目的架构"          # 带初始任务
codex exec "跑测试并修复失败的"      # 非交互（脚本/CI）
codex resume                      # 恢复上次会话
```

## 交互中的斜杠命令

```bash
/model     # 切模型        /plan    # 先出方案再动手
/compact   # 压缩上下文     /diff    # 看当前所有改动
/undo      # 撤销上一步     /fork    # 分叉对话试别的方案
/review    # 代码审查       /quit    # 退出
```

## 快捷键

```bash
Ctrl+C 中断当前任务    Ctrl+D 退出    Tab 忙碌时排队下一条指令
```

## 项目指令

项目根目录放 `AGENTS.md`（启动自动注入），全局放 `~/.codex/AGENTS.md`。
配置都在 `~/.codex/config.toml`（brook config codex bailian 生成）。
