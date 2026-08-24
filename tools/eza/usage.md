# eza 常见用法（ls 的现代替代，仅 Linux 官方包；macOS 用 brew install eza）

## 基本

```bash
eza -la --icons        # 常用形态：长列表+隐藏+图标
eza -T                  # 目录树
eza -l --git            # 显示 git 状态列（±✓）
eza -l --time-style=long-iso   # 可读时间
eza -s size -r          # 按大小倒序（最大的在前）
```

## 进阶组合

```bash
eza -la --group-directories-first --git --icons   # 默认别名推荐落这
alias ls='eza -la --group-directories-first --icons'
alias ll='eza -l --icons'
alias lt='eza -T'
# 配合 fd：大小排序不看权限
eza -l --no-permissions --size=bytes -s size
```

## 与 brook

macOS 官方不出 macOS 二进制，直接 `brew install eza`（brook 的 NOTE 已提示）。

## 排查

- 图标显示成方块 → 终端需要 Nerd Font 图标字体
- 中文文件名排序怪 → `--sort=name` 默认按字节，换 `LC_COLLATE=C.UTF-8`
