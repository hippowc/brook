# brew 常见用法

brook 装不了的工具（eza、mpv、ffmpeg…）基本都靠它。

## 基本

```bash
brew install <名字>            # 安装（eza / mpv / ffmpeg / wget ...）
brew search <关键词>           # 搜包
brew uninstall <名字>          # 卸载
brew update                    # 更新包索引
brew upgrade                   # 升级所有已装包（或指定名字）
brew list                      # 已装清单
```

## 常用

```bash
brew info <名字>               # 看版本/依赖/说明
brew doctor                    # 环境体检
brew services list             # 管理后台服务（start/stop/restart）
brew install --cask <名字>     # 装 GUI 应用（macfuse 等）
```

## 注意

- Apple Silicon 上 brew 装在 /opt/homebrew，装完按提示把 eval 行加进 shell rc
- 国内网络慢可换源（清华/中科大镜像），搜"homebrew 镜像"按步骤执行
