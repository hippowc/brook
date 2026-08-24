# g 常见用法（Go 版本管理器 voidint/g：装/切换官方工具链）

## 装完必做（brook config g shell-init）

```bash
brook config g shell-init       # 把 g 的初始化写进 rc（g 用 eval $(g shell-init)）
g ls-remote                     # 看远端版本
g install 1.24                  # 装某个 go 版本
g ls                            # 已装
g use 1.24                      # 切换当前目录
g set 1.24                      # 设默认
```

## 基本流程

```bash
g install 1.24 && g use 1.24    # 一次到位
go version                      # 验证
go env GOROOT GOCACHE           # 看工具链/缓存位置
g uninstall 1.24                # 卸某个版本
```

## 进阶

```bash
g self update                   # 更新 g 自身
g doctor                        # 自检
# 项目固定版本：目录放 .go-version；或配合 g use 手动切
# 多个版本切换后注意 GOPATH 缓存按版本隔离，不冲突
```

## 排查

- `go: command not found` → g 的 PATH 注入没生效（重跑 config + source）
- 下载慢 → go 官方源在国内慢，配合 goproxy 镜像：`brook mirror goproxy apply`
