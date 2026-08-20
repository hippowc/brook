# zoxide 常见用法

按"频率+最近度"记住你去过的目录，几个字母跳过去。

## 必做：初始化（否则 z 命令不存在）

```bash
echo 'eval "$(zoxide init bash)"' >> ~/.bashrc && source ~/.bashrc
# zsh 用 zoxide init zsh；想让 z 直接接管 cd：zoxide init bash --cmd cd
```

## 基本

```bash
z notes                # 跳到最匹配的目录
z foo bar              # 多关键词，按顺序匹配路径片段
zi                     # 交互式选择（需 fzf）
zoxide query --list    # 看所有记录的目录及评分
```

数据库自动累积，越用越准，零维护。
