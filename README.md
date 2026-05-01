# Brook

基于 [CloudWeGo Eino](https://github.com/cloudwego/eino) ADK 的可配置终端 Agent：用一份 `agent.yaml` 选择模型、工具与编排模式。**只有一个可执行文件 `brook`**。

---

## 一、安装

### 1. 从 GitHub Release 安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/scripts/install.sh | bash
```

- 将 **`brook`** 安装到 `~/.local/bin` 或 `/usr/local/bin`（视目录写权限而定）。
- **固定版本**：`VERSION=v0.0.3 curl -fsSL ... | bash`（`VERSION` 必须与 Release 上的 **Git 标签**一致，且该 Release 已上传对应平台的 `brook_<VERSION>_<os>_<arch>.tar.gz`）。
- 未指定 `VERSION` 时，脚本会请求 GitHub API 取 **latest**。网络受限时可配置 `HTTPS_PROXY` 等。

### 2. 使用 Go 安装

```bash
go install github.com/hippowc/brook/cmd/brook@latest
```

将 `$(go env GOPATH)/bin` 加入 `PATH`。

### 3. 从本仓库源码安装（开发）

在仓库根目录执行：

```bash
./scripts/install_local.sh
```

可用环境变量 `INSTALL_DIR` 指定安装目录；脚本会 `go build` 出单个 `brook`。

**构建本仓库所需 Go 版本**：与根目录 [`go.mod`](go.mod) 一致（当前为 **Go 1.25+**）。

---

## 二、命令行：有哪些功能、怎么用

所有能力都通过 **`brook`** 的子命令或默认行为进入；主配置均为 **`agent.yaml`**（默认 `~/.brook/agent.yaml`，也可用 `-config` 指定）。

### 1. 总览

| 命令 | 作用 |
|------|------|
| `brook` | **默认**：启动 **TUI**（交互对话） |
| `brook tui` | 显式启动 TUI（与上相同，便于写脚本） |
| `brook cli` 或 `brook run` | **单次查询**（非交互，跑完即退出） |
| `brook gateway` | **HTTP 网关**（需在 YAML 里 `gateway.enabled: true`） |
| `brook help` | 打印内置帮助 |

**兼容旧用法**：若命令行里出现 `-query` / `-a2ui` / `-checkpoint-id` / `-resume-input` 等（旧版独立 `brook` CLI 风格），会自动走 **单次查询**，无需先写 `brook cli`：

```bash
brook -query "你好"
# 等价于
brook cli -query "你好"
```

### 2. TUI 启动参数

```text
brook [tui 参数...]
brook tui [参数...]
```

| 参数 | 说明 |
|------|------|
| `-config` | `agent.yaml` 路径；默认 `~/.brook/agent.yaml`（不存在时会初始化目录与默认文件） |
| `-conversation` | 会话 UUID；默认读 `~/.brook/current_conversation`，无则新建 |
| `-new` | 忽略当前会话指针，强制新建 UUID |

示例：

```bash
brook -config /path/to/agent.yaml
brook tui -new
```

### 3. 单次查询（CLI）参数

```text
brook cli [参数...]
```

| 参数 | 说明 |
|------|------|
| `-config` | 同上 |
| `-query` | 用户输入；为空则用配置里的 `user_prompt`，再缺省为内置一句问候 |
| `-checkpoint-id` | 与中断恢复 / Resume 相关 |
| `-resume-input` | 与 `-checkpoint-id` 配合，写入 session 的 `resume_user` |
| `-a2ui` | 将事件以 A2UI JSON Lines 打到 stdout（或与 YAML 中 `a2ui.enabled` 联动） |

示例：

```bash
brook cli -query "总结当前目录下的 README"
```

### 4. 网关

```bash
brook gateway -config /path/to/agent.yaml
```

监听地址、鉴权、会话存储等均在 YAML 的 **`gateway`** 段配置；详见 [`config/docs/agent-configuration-guide.md`](config/docs/agent-configuration-guide.md) 中网关章节。

---

## 三、TUI：有哪些功能、怎么配、怎么用（含多种 Agent 模式与 **custom**）

### 1. 配置从哪来

- 主配置：**`agent.yaml`**（默认 `~/.brook/agent.yaml`）。
- 首次运行会自动准备 `~/.brook/` 下的默认文件；也可复制 [`config/agent.example.yaml`](config/agent.example.yaml) 后改路径与模型。
- 模型 API Key 等：在 YAML 的 `models.providers.*.api_key_env` 里配置环境变量名（如 `OPENAI_API_KEY`），在运行前 export 即可。

更全字段说明：[`config/docs/agent-configuration-guide.md`](config/docs/agent-configuration-guide.md)。

### 2. TUI 里能做什么（输入框命令）

在 TUI 底部输入框输入（详见 `/help` 或 [`internal/tui/helptext.go`](internal/tui/helptext.go)）：

| 输入 | 作用 |
|------|------|
| `/help` | 简短说明 |
| `/config` | 打开当前 `agent.yaml` 的编辑器视图 |
| `/session new` | 新会话（新 UUID，存档在 `~/.brook/conversations/`） |
| `/session list` | 列出最近会话（短 ID / 名称 / 预览） |
| `/session open <id|前缀>` | 打开历史会话 |
| `/session rename <名称>` | 重命名当前会话，便于标记 |
| `/agent mode <模式>` | 切换 `agent.mode`，并补齐该模式最小配置到 `modes.<mode>`；需要多角色时请在 `agents` 中定义后由模式引用 |
| `/custom build` | **仅**在 `agent.mode=custom` 时：进入「创建」模式，用 LLM 辅助写 **Starlark** / **`agents.yaml`** 并落盘 |
| `/custom run` | 回到按 `modes.custom.script` 编排的「使用」模式；会从磁盘重新加载配置 |

会话与当前会话指针由 Brook 管理；多轮内容会持久化到 `~/.brook/conversations/<uuid>.json`（具体见实现与文档）。

### 3. 多种 `agent.mode` 是什么、怎么切

在 TUI 里用 **`/agent mode <名称>`** 即可切换（会改 YAML 并 reload）。各模式一句话：

| 模式 | 含义（简述） |
|------|----------------|
| `react` | 单 Agent ReAct |
| `deep` | DeepAgents |
| `sequential` / `parallel` | 多子 Agent 顺序 / 并行 |
| `loop` | 循环子 Agent |
| `supervisor` | Supervisor 编排子 Agent |
| `plan_execute` | Planner / Executor / Replanner |
| **`custom`** | **Starlark 脚本**编排 + **`agents.yaml`** 定义子 Agent；由脚本里的 `call(agent_id, content)` 调用模型子 Agent |

切换时会补齐该模式最小模板到 `modes.*`，复杂编排请编辑 `agents` 与对应 `modes.<mode>`。

### 4. **`custom` 模式（重点）**

`custom` 用 **一份 Starlark（`.star`）** 做主编排，用 **`agents.yaml`** 声明若干子 Agent（由同一套主配置里的模型驱动）。适合「多轮、多角色、流程你自己写死」的场景。

#### 4.1 在 YAML 里怎么配

在 `agent` + `modes.custom` 下设置：

```yaml
agent:
  mode: custom

modes:
  custom:
    script: "@./custom/orchestrate.star"            # 相对路径相对 agent.yaml 所在目录
    agents_file: "@./custom/agents.yaml"            # 可省略：默认同目录 agents.yaml
```

脚本与 agents 的常见落盘位置：**`~/.brook/custom/`**（与 `@./custom/...` 引用一致）。路径展开规则见 [`pkg/agentconfig/atfile.go`](pkg/agentconfig/atfile.go) 中 `@` 引用说明。

#### 4.2 Starlark 脚本约定

- 必须提供顶层函数 **`run(user_text)`**，返回 **字符串**，作为对用户的主回复。
- 内置能力（在脚本中可用）：**`cfg`**（来自配置的 dict）、**`state`**（跨轮字典）、**`call(agent_id, content)`**（调用 `agents.yaml` 里某 id 的子 Agent）、**`read_text` / `load_yaml` / `rand_shuffle`** 等（见示例脚本注释）。

示例仓库内自带一套最小示例：

- [`config/examples/custom/README.md`](config/examples/custom/README.md)
- [`config/examples/custom/orchestrate.star`](config/examples/custom/orchestrate.star)
- [`config/examples/custom/agents.yaml`](config/examples/custom/agents.yaml)

#### 4.3 在 TUI 里怎么用 `custom`

1. 将 `agent.mode` 设为 **`custom`**（`/agent mode custom` 或手改 YAML）。
2. 若尚未配置可用的 `modes.custom.script`（或文件不存在），TUI 会自动进入「创建」模式，提示你用 `/custom build`。
3. `/custom build`：由内置 LLM 助手通过 `save_custom_file`、`activate_custom_bundle` 把 `orchestrate.star`、`agents.yaml` 写到 `~/.brook/custom/`，并更新主配置里的 `modes.custom.script / modes.custom.agents_file`。
4. 编排就绪后执行 **`/custom run`**：切回「使用」模式，并从磁盘 **重新加载** `agent.yaml`（使新路径生效）。

**注意（路径）**：`save_custom_file` 的相对路径是相对于 **`~/.brook/custom/`** 根目录的，应写 `orchestrate.star`、`agents.yaml` 等，**不要**再套一层 `custom/`，否则会落到 `~/.brook/custom/custom/...`，与主配置里的 `@./custom/orchestrate.star` 不一致。

#### 4.4 滚动、选区与复制 / 粘贴（TUI）

Brook 在主会话区启用**应用内拖选**（需终端向程序上报鼠标事件）。

- **滚动**：鼠标滚轮；以及键盘 `PgUp` / `PgDn`、`Ctrl+U` / `Ctrl+D`；输入框为空时 **`↑` / `↓`**、`Ctrl+P` / `Ctrl+N`。**生成中**仍可用上述键滚动。
- **选中**：在会话显示区内按住鼠标左键拖动；选中范围会以反色高亮。
- **复制选中内容**（无选中则不写入剪贴板）：
  - **macOS**：显示为 **`Cmd+C`**（程序侧接收 `Alt/Meta+C` 映射；是否可直接按 Cmd 取决于终端是否转发 Cmd 组合键）
  - **Linux / Windows**：**`Ctrl+Shift+C`**
- **粘贴到输入框**：
  - **macOS**：显示为 **`Cmd+V`**（程序侧接收 `Alt/Meta+V` 映射）
  - **Linux / Windows**：**`Ctrl+V`**

说明：终端是否把 **Cmd** 组合键发给 TUI 由终端设置决定；若未转发，可在终端里将 Cmd 映射为 Meta/Alt，或直接使用平台默认的 Ctrl 组合键。

---

## 附录

### 从源码构建单个二进制

```bash
git clone https://github.com/hippowc/brook.git
cd brook
go build -o brook ./cmd/brook
```

### 发布用交叉编译（维护者）

```bash
VERSION=v0.0.3 ./scripts/build_release.sh
```

产物在 **`dist/`**（目录被 `.gitignore` 忽略）：各平台 `brook_<VERSION>_<os>_<arch>.tar.gz` 与 `checksums.txt`。上传 GitHub Release 时，**文件名须与 `VERSION` / 标签一致**，否则 `install.sh` 会 404。

### 仓库布局（简要）

| 路径 | 说明 |
|------|------|
| `cmd/brook` | 唯一入口：TUI / `cli` / `gateway` |
| `internal/core/agent` | Agent 构建（含 `custom` Starlark） |
| `internal/tui` | TUI |
| `internal/gateway` | HTTP 网关 |
| `pkg/agentconfig` | YAML 模型与校验 |
