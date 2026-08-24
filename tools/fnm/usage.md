# fnm 常见用法

Node 版本管理器：安装/切换官方 node 构建。

## 装完三步

```bash
brook config fnm shell-init    # 1. 挂进 rc
source ~/.bashrc               # 2. 生效
fnm install 22 && fnm use 22   # 3. 装 node 并切换
```

## 常用

```bash
fnm ls-remote            # 可装版本
fnm ls                   # 已装（* 为当前）
fnm install --lts        # 装最新 LTS
fnm default 22           # 设默认版本
fnm use 20               # 切换
```

## 说明

- 进入含 .node-version / .nvmrc 的目录自动切版本（--use-on-cd 已启用）
- linux 仅支持 x86_64（上游不发 arm64 包）
- npm 国内镜像：brook mirror npm apply
