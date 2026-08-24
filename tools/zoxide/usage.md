# zoxide 常见用法（z 跳转：按"频率+最近度"记目录）

## 必做：初始化（否则 z 命令不存在）

```bash
echo 'eval "$(zoxide init bash)"' >> ~/.bashrc && source ~/.bashrc
# zsh 用：zoxide init zsh；bash 下若想 z 接管 cd：zoxide init bash --cmd cd
```

## 基本

```bash
z notes                  # 跳到最匹配的目录
z foo bar                # 多关键词按路径片段匹配
z -                      # 回退到上一个目录
zi                       # 交互式选择（需 fzf）
zoxide query --list      # 全量列表+评分
```

## 进阶

```bash
z ~/project && ls        # 惯用法：跳过去顺手 ls（配合 eza 别名更爽）
alias cd='z'             # 直接接管 cd（不再记忆路径）
zoxide query -l xyz      # 列出所有含 xyz 的候选以确认
# 忘记某个目录名？z 支持模糊，多打一个字符没关系
```

## 与 brook

装完记得 `brook config` 把初始化写进 rc 即时生效；目录记录存在
`~/.local/share/zoxide/db.zo`，换机器不迁移（不需要）。

## 排查

- `z` 命令不存在 → 初始化没执行；确认 rc 里有 `eval "$(zoxide init bash)"`
- 跳错目录 → 用 `zoxide remove <路径>` 清除某条记录
