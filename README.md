# Brook

基于 [CloudWeGo Eino](https://github.com/cloudwego/eino) ADK 的可配置终端 Agent：通过 YAML 选择模型、工具、编排模式（ReAct、Deep、串行/并行/循环、Supervisor、Plan-Execute 等）。**可执行文件仅 `brook` 一个**，通过子命令区分功能：**默认启动交互式 TUI**；`brook cli` 为单次查询；`brook gateway` 为可选 HTTP 接入。

## 功能概览

- **配置驱动**：`~/.brook/agent.yaml`（首次运行自动生成），亦可指定 `--config` 指向任意路径。
- **多模式 Agent**：`react`、`deep`、`sequential`、`parallel`、`loop`、`supervisor`、`plan_execute`（说明见 [`doc/agent-configuration-guide.md`](doc/agent-configuration-guide.md)）。
- **工具**：本地文件系统（`read_file` / `glob` / `execute` 等，取决于配置）、可扩展中间件。
- **TUI**：多轮对话、`/help`、`/config`、`/agent mode`、`/new`、Tab 补全；会话存档于 `~/.brook/conversations/`。
- **Gateway（可选）**：同一套 `agent.yaml` 下将 `gateway.enabled: true` 后，运行 `brook gateway` 监听 HTTP；`POST /v1/chat` 接入外部用户（按 `user_id` + `conversation_id` 隔离 SessionValues，默认落盘 `~/.brook/gateway/sessions/`）。详见 [`doc/agent-configuration-guide.md`](doc/agent-configuration-guide.md) 网关小节。
- **工程细节**：工具调用失败时通过中间件转为模型可见的 observation（避免整轮 `NodeRunError` 直接中断）。

**要求**：Go **1.24+**（若从源码构建）；运行期需按配置提供 OpenAI 兼容 API、Ollama 等模型端点。

## 命令速览

| 命令 | 说明 |
|------|------|
| `brook` | 启动 TUI（默认） |
| `brook tui` | 显式启动 TUI（与上同），支持 `-config`、`-conversation`、`-new` |
| `brook cli` 或 `brook run` | 单次查询（非交互），即原独立 `brook` CLI |
| `brook -query "…"` | 与 `brook cli -query "…"` 等价（兼容旧脚本） |
| `brook gateway` | HTTP 网关（需配置中启用 gateway） |
| `brook help` | 打印用法 |

## 一键安装

### 从 GitHub Release 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hippowc/brook/main/scripts/install.sh | bash
```

- 默认将 **`brook`** 安装到 `~/.local/bin` 或 `/usr/local/bin`（视权限而定）。Release 中每个平台一个压缩包，内含 **`brook` 单一二进制**（`curl` **进度条**输出到终端）。
- 指定版本：`VERSION=v0.1.0 curl -fsSL ... | bash`（须与 GitHub Release 标签一致，且该版本已上传对应平台的 `brook_<VERSION>_<os>_<arch>.tar.gz`）

安装脚本**仅支持**从 **GitHub Release 下载预编译包**（不使用 `go install`）。会先请求 **GitHub API** 解析 `latest`（若未设置 `VERSION`）。访问较慢时可配置代理，例如：`export HTTPS_PROXY=http://127.0.0.1:7890`（按你的环境修改）。

### 使用 Go 安装（需已配置 `GOPATH/bin` 到 PATH）

```bash
go install github.com/hippowc/brook/cmd/brook@latest
```

## 从源码构建

```bash
git clone https://github.com/hippowc/brook.git
cd brook
go build -o brook ./cmd/brook
```

### 发布用交叉编译（macOS / Linux）

```bash
# 与 GitHub Release 标签一致，否则一键安装会 404（见下表）
VERSION=v0.0.1 ./scripts/build_release.sh
```

产物在 `dist/`：每个平台一个包，例如 `brook_<VERSION>_<os>_<arch>.tar.gz`，以及 `checksums.txt`。

**发布 Release 时附件名必须与标签一致。** 一键安装会请求 `brook_${tag}_${plat}.tar.gz`，例如：

| Release 标签 | 需上传的附件名（每平台一条，共 4 个 tar.gz：darwin/amd64、darwin/arm64、linux/amd64、linux/arm64） |
|--------------|------------------------|
| `v0.0.1` | `brook_v0.0.1_darwin_amd64.tar.gz`、`brook_v0.0.1_darwin_arm64.tar.gz`、`brook_v0.0.1_linux_amd64.tar.gz`、`brook_v0.0.1_linux_arm64.tar.gz` |

若只运行 `./scripts/build_release.sh` 且未设 `VERSION`，会得到 `brook_4c53307_...` 这类名字，**与 `v0.0.1` Release 不匹配**，安装脚本会 404。请用上述带 `VERSION=...` 的命令重新打包并上传，或在 GitHub 网页上把附件**重命名**为表中形式。

## 快速使用

1. **首次配置**  
   运行任意命令会自动生成 `~/.brook/agent.yaml`。也可复制 [`config/agent.example.yaml`](config/agent.example.yaml) 后修改路径与 API。

2. **环境变量**  
   在 YAML 的 `models.providers.*.api_key_env` 中配置（如 `OPENAI_API_KEY`）。

3. **TUI（默认）**

   ```bash
   brook
   ```

4. **CLI 单次查询**

   ```bash
   brook cli -query "你好"
   # 或兼容旧版：
   brook -query "你好"
   ```

5. **Gateway（可选）**  
   在 `agent.yaml` 中设置 `gateway.enabled: true` 并配置监听与鉴权后：

   ```bash
   brook gateway
   ```

6. **系统提示词**  
   支持多行 YAML（`|`）；或使用 `instruction: "@相对或绝对路径.md"` 引用 Markdown 文件（相对路径相对于 `agent.yaml` 所在目录）。

更完整的字段说明见 [`doc/agent-configuration-guide.md`](doc/agent-configuration-guide.md)。

## 仓库布局（简要）

| 路径 | 说明 |
|------|------|
| `cmd/brook` | 唯一可执行入口：TUI / `cli` / `gateway` 子命令 |
| `internal/gateway` | 网关 HTTP、鉴权、限流、会话隔离 |
| `pkg/agentconfig` | YAML 模型与校验 |
| `internal/core/agent` | Agent 构建与工具错误中间件 |
| `config/agent.example.yaml` | 示例配置 |
