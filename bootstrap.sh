#!/usr/bin/env bash
# brook —— agent 环境配置器（向导入口）
#
# 用法：
#   ./bootstrap.sh                 交互式向导（菜单）
#   ./bootstrap.sh <条目>...       直接执行（agents/tasks，--list 查看）
#   ./bootstrap.sh --list | --help
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BROOK_ROOT="$ROOT"
source "$ROOT/bootstrap/lib/common.sh"
brook_main "$@"
