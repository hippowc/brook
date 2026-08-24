# Homebrew 常见用法（macOS/Linux 包管理器）

## 国内安装加速（先做）

```bash
brook mirror homebrew apply    # 写 HOMEBREW_API/BOTTLE/BREW_GIT 环境变量（tuna 默认）
# 新终端生效；之后 brew 安装/瓶子都走国内镜像
```

## 基本

```bash
brew list                  # 已装
brew install <包>           # 装
brew search <关键词>
brew info <包>             # 依赖/版本/路径
brew upgrade               # 升级所有；brew upgrade <包>
brew update                # 更 formulas 仓库
```

## 进阶

```bash
brew install --cask <app>  # 装 GUI 应用（如 Docker Desktop、iTerm2）
brew services list         # 服务管理（如 mysql/postgres 常驻）
brew services start mysql
brew cleanup               # 清旧版本残留
brew autoremove            # 清孤儿依赖
brew doctor                # 自检（装完/遇到问题先跑这个）
```

## 排查

- 换镜像后第一次还慢 → 退出重开终端（环境变量生效），或 `brew update` 先拉通
- `command not found: brew` → 装完要新开终端；检查 /opt/homebrew/bin 在 PATH
- brew doctor 报 warning 照提示修，多数是 PATH 顺序
