# fnm 常见用法（Node 版本管理器，快、跨 shell）

## 装完必做（brook config fnm shell-init）

```bash
brook config fnm shell-init     # 写 eval "$(fnm env --use-on-cd)" 进 rc
# --use-on-cd：进含 .node-version/.nvmrc 的目录自动切版本
```

## 基本

```bash
fnm install --lts               # 装 LTS node（自带 npm/npx）
fnm install node/20             # 指定大版本
fnm ls                          # 已装版本
fnm use lts-lts                 # 切换当前目录用
fnm default lts-lts             # 设默认
fnm current                     # 当前版本
```

## 进阶

```bash
node -v && npm -v               # 验证 npm 随 node 来
npm i -g <包>                   # 全局装（装到当前 node 版本名下）
# 项目固定版本：echo "20" > .node-version（--use-on-cd 自动切）
fnm ls-remote                   # 看远端版本
```

## 与 brook

- fnm/uv/g/rustup 是 brook 的"语言工具"四件套：先装管理器，再让管理器装运行时
- npm 分发的 CLI（opencode 等）由 npm 装，brook 不代管

## 排查

- `fnm: command not found` → 重跑 `brook config fnm shell-init` 并 source
- npm 全局装完命令找不到 → fnm env 没生效（用 fnm 的 node，PATH 靠 fnm env）
