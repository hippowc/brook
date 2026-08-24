# fzf 常见用法（模糊查找，终端里的 Ctrl+P 体验）

## 先把 shell 集成装上（推荐）

```bash
eval "$(fzf --bash)"    # 装完执行一次，写进 rc 永久生效（brook config fzf 可自动化）
# 随后：Ctrl+R 历史搜索 / Ctrl+T 文件选择 / Alt+C cd 跳转
```

## 基本

```bash
fzf                          # 从 stdin 选一行
vim $(fzf)                   # 选文件打开
ls | fzf                     # 任何列表都可以筛
```

## 进阶：预览与组合

```bash
fzf --preview 'bat --color=always {}'          # 文件预览（配合 bat）
fzf --preview 'cat {}' --preview-window=top:60%
rg -l "redis" | fzf --preview 'bat --color=always {}'
fzf --bind 'enter:execute(vim {})'             # 回车直接执行
git branch --all | fzf                          # 交互式切分支
git log --oneline | fzf | awk '{print $1}'      # 选 commit
```

## 配置

- `export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'`（更快更全）
- 历史搜索只搜命中：`export FZF_DEFAULT_OPTS='--height 40% --reverse --border'`

## 排查

- Ctrl+R 没反应 → 没执行 `fzf --bash`（或 zsh 用 `fzf --zsh`）
- 中文输入不出结果 → 确认终端输入法在英文模式测一下（fzf 对编码是字节匹配）
