# _template.sh —— 新增初始化任务的模板（下划线开头的文件不会被加载）
#
# 用法：复制为 tasks/<名字>.sh，定义函数 <名字连字符转下划线>_run，例如
# git-key.sh → git_key_run()。之后 `./bootstrap.sh <名字>` 即可调用。
#
# 任务约定：
#   - 幂等：重复执行不出错（已装跳过、已有配置跳过）
#   - 允许交互提示（ask/confirm/read），但每项给默认值或明确说明
#   - 机密不进仓库：配置只写 $HOME 下（~/.config、~/.ssh 等）
#   - 尽量用户级安装（~/.local/bin），不依赖 root
#   - 跨平台：用 os()/arch() 判断，别写死 Linux 假设
#   - 大下载前用 confirm 确认
#
# 可选函数（交互式向导用）：
#   <名字>_desc        一句话描述（菜单展示）
#   <名字>_status      当前状态（✓/△/✗ 开头的一行）
#   <名字>_options     运行前的定制提问（版本等，用 ask 读取）
#
# 可用共享工具（lib/common.sh）：
#   log / warn / die / have / ask / confirm / is_interactive
#   os（linux/macos）/ arch（x86_64/arm64）
#   rc_file / append_rc / ensure_user_bin_path
#   BROOK_ROOT（仓库根）
#
# 示例：
#   foo_desc()   { echo "安装 foo"; }
#   foo_status() { have foo && echo "✓ 已安装" || echo "✗ 未安装"; }
#   foo_run()    { have foo && { log "已安装（跳过）"; return 0; }; ...; }
