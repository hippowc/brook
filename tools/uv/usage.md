# uv 常见用法（Python 管理器：装 python / venv / 包，极快）

## 基本

```bash
uv python install 3.12          # 装指定版本 python（uv 自己管理运行时）
uv python list                  # 看已装/可装版本
uv venv --python 3.12 .venv     # 建虚拟环境
uv pip install requests         # 装包（进 .venv 后）
uv run python script.py         # 一行：自动建/复用 venv 并跑
```

## 进阶：依赖与项目

```bash
uv init demo && cd demo         # 初始化项目
uv add requests                 # 加依赖（写进 pyproject.toml）
uv sync                         # 按锁文件装齐
uv lock                         # 生成锁文件
uv run pytest                   # 项目里跑命令（自动带上依赖）
uv pip list                     # 看当前环境装了啥
```

## 工具模式（装 CLI 到 ~/.local/bin，顺带解决"python 工具怎么装"）

```bash
uv tool install aider           # 隔离环境装 CLI 工具，入口进 PATH
uv tool list                    # 已装的工具
uv tool upgrade --all
```

## 国内源（配合 brook）

```bash
brook mirror pypi apply         # 写 UV_DEFAULT_INDEX 到 rc（tsinghua 默认）
```

## 排查

- `uv python install` 慢 → 换源（上面 pypi mirror）或走代理
- 找不到全局 python → uv 没有 escrow 全局"python3"入口，用 `uv run python` 或自家 venv
