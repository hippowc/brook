# fd 常见用法（find 的现代替代：默认忽略 .gitignore/隐藏目录，走正则）

## 基本

```bash
fd  pattern            # 当前目录递归搜（默认忽略隐藏与 .gitignore）
fd  -e md pattern      # 按扩展名过滤
fd  -t f / -t d        # 只要文件 / 只要目录
fd  -H pattern         # 连隐藏文件一起
fd  -I pattern         # 连 .gitignore 的也搜（慎）
fd  -d 3 pattern       # 限制深度
```

## 进阶：和 vim/fzf/ripgrep 组合

```bash
vim "$(fd -e md '笔记')"                 # 打开第一个命中
fd -e java | xargs -I{} grep -l 'TODO' {}   # 对结果批量操作
fzf --preview 'fd -t d | head'           # 目录选择
fd -e py -x wc -l {}                     # 对每个命中执行命令（-x 并行）
```

## 常用别名

```bash
alias f='fd -H -I'        # 全范围搜
# 让 fzf 默认走 fd（更快更干净）
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
```

## 排查

- 搜不到像是有文件 → 默认尊重 .gitignore 和隐藏，加 `-H -I`
- 慢 → 加 `-d` 限制深度，或 `--exclude node_modules`
