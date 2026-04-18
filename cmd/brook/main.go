// Brook：统一入口。无子命令且非「CLI 单次运行」启发式时，默认启动 TUI。
package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		runTUI(nil)
		return
	}
	switch args[0] {
	case "help", "-h", "--help":
		printUsage(os.Stdout)
		return
	case "cli", "run":
		if err := runCLI(args[1:]); err != nil {
			fmt.Fprintf(os.Stderr, "%v\n", err)
			os.Exit(1)
		}
		return
	case "gateway":
		if err := runGateway(args[1:]); err != nil {
			fmt.Fprintf(os.Stderr, "%v\n", err)
			os.Exit(1)
		}
		return
	case "tui":
		runTUI(args[1:])
		return
	}
	// 与旧版 brook CLI 兼容：带 -query / checkpoint / a2ui 等时走非交互 CLI
	if wantsLegacyCLI(args) {
		if err := runCLI(args); err != nil {
			fmt.Fprintf(os.Stderr, "%v\n", err)
			os.Exit(1)
		}
		return
	}
	if strings.HasPrefix(args[0], "-") {
		runTUI(args)
		return
	}
	fmt.Fprintf(os.Stderr, "未知子命令 %q\n\n", args[0])
	printUsage(os.Stderr)
	os.Exit(1)
}

// wantsLegacyCLI 判断是否应按旧版「brook」单次查询方式解析（无需显式子命令 cli）。
func wantsLegacyCLI(args []string) bool {
	for _, a := range args {
		switch {
		case a == "-query" || a == "--query":
			return true
		case strings.HasPrefix(a, "-query=") || strings.HasPrefix(a, "--query="):
			return true
		case a == "-a2ui" || a == "--a2ui":
			return true
		case a == "-checkpoint-id" || strings.HasPrefix(a, "-checkpoint-id="):
			return true
		case a == "-resume-input" || strings.HasPrefix(a, "-resume-input=") || strings.HasPrefix(a, "--resume-input="):
			return true
		}
	}
	return false
}

func printUsage(w *os.File) {
	fmt.Fprintf(w, `Brook — Eino ADK 可配置 Agent

用法:
  brook                    启动交互式 TUI（默认）
  brook [tui 选项...]      同上，例如 -config、-conversation、-new
  brook cli [选项...]      单次查询（非交互），同旧版 brook 命令行
  brook gateway [选项...]  HTTP 网关（需 agent.yaml 中 gateway.enabled: true）

与旧版兼容:
  brook -query "你好"      等价于 brook cli -query "你好"

子命令:
  tui       显式启动 TUI
  cli, run  单次查询
  gateway   HTTP 网关
  help      显示本说明

`)
}
