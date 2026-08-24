# uv 常见用法

Python 管理器：一个工具覆盖 python 版本、虚拟环境、包管理，比 pip 快 10-100 倍。

## Python 版本

```bash
uv python install 3.12       # 装 python（预编译官方构建，无需编译）
uv python list               # 可用/已装版本
uv python pin 3.12           # 项目固定版本（写 .python-version）
```

## 日常

```bash
uv venv                      # 建 .venv
uv pip install requests      # 装包（兼容 pip 语法，快得多）
uv run script.py             # 自动建环境并运行（推荐姿势）
uv add requests              # 项目模式：加依赖到 pyproject.toml
```

## 装 CLI 工具

```bash
uv tool install yt-dlp       # 装到独立环境并进 PATH
uvx ruff check .             # 临时运行，不安装
```

## 说明

- 无需 shell 初始化，装完即用
- 国内镜像：brook config uv pypi-mirror
