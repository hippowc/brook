# g 常见用法

Go 版本管理器：安装/切换官方预编译工具链（相当于 Go 世界的 fnm）。

## 装完三步（顺序不能乱）

```bash
brook config g shell-init        # 1. 写 ~/.g/env 并挂进 rc（含国内下载镜像）
source ~/.bashrc                 # 2. 生效（zsh 改 ~/.zshrc）
g install 1.24 && g use 1.24     # 3. 装工具链并切换
```

## 常用

```bash
g ls-remote stable     # 可装的稳定版本
g ls                   # 已装版本（* 为当前）
g install 1.23.5       # 装指定版本
g use 1.23.5           # 切换
g uninstall 1.23.5     # 卸载某版本
g update               # g 自更新
```

## 说明

- 工具链装在 ~/.g，GOROOT/GOPATH 由 ~/.g/env 管理
- 下载走 golang.google.cn 官方镜像（~/.g/env 里的 G_MIRROR），国内无需代理
- 模块代理另配：brook mirror goproxy apply
