# _template.sh —— 新增 agent 适配器的模板（下划线开头的文件不会被加载）
#
# 用法：复制为 adapters/<agent>.sh，实现三件套（必须）：
#
#   <agent>_install     安装（幂等：用户级安装已存在则跳过）。
#                       用 os()/arch() 映射发行包 target，支持 Linux/macOS。
#                       尽量用户级安装（~/.local/bin、npm -g 等），避免依赖 root。
#                       大下载前用 confirm 确认。
#   <agent>_configure   读 PROVIDER_* 变量，翻译成该 agent 的配置格式。
#                       关键事实：bailian 是 OpenAI 兼容端点，多数开源 agent
#                       （aider/opencode/goose/...）可直接用 base_url + key 接入。
#   <agent>_verify      冒烟测试（--version 或最小调用）
#
# 可选函数（交互式向导用）：
#   <agent>_desc        一句话描述（菜单展示）
#   <agent>_status      当前状态（✓/△/✗ 开头的一行）
#   <agent>_options     运行前的定制提问（版本、下载源等，用 ask 读取）
#
# 注意：适配器只负责把 agent 装好配好；之后怎么用（主 agent / 子 agent /
# API 调用、接什么知识库）由用户决定，不属于适配器的职责。
#
# 可用共享工具（lib/common.sh）：
#   log / warn / die / have / ask / confirm / is_interactive
#   os（linux/macos）/ arch（x86_64/arm64）
#   rc_file / append_rc / ensure_user_bin_path
#   PROVIDER_NAME / PROVIDER_BASE_URL / PROVIDER_MODEL / PROVIDER_KEY_ENV / PROVIDER_WIRE_API
#   BROOK_ROOT（仓库根）
#
# 示例骨架（claude code）：
#   claude_desc()      { echo "安装 claude code"; }
#   claude_status()    { have claude && echo "✓ 已安装" || echo "✗ 未安装"; }
#   claude_install()   { have claude || npm install -g @anthropic-ai/claude-code; }
#   claude_configure() { ... 通过 env/配置指向 OpenAI 兼容端点 ... }
#   claude_verify()    { claude --version; }
