# eza 常见用法

## 基本

```bash
eza -l --icons --git         # 长格式 + 图标 + git 状态
eza --tree --level=2         # 树视图（替 tree）
eza -D                       # 只看目录
eza -l -s modified --reverse # 按修改时间倒序
eza -la                      # 含隐藏文件
```

## 常用选项

```bash
-l / -a / -aa       # 长格式 / 含隐藏
--icons / --git     # 图标 / git 状态标记
--tree --level=N    # 树视图限深度
--git-ignore        # 跳过 .gitignore 排除的
-s size / --reverse # 排序 / 倒序
--group-directories-first
```

## 推荐 alias（写进 ~/.bashrc）

```bash
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --git-ignore'
alias la='eza -la --icons --git'
```
