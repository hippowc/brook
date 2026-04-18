package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/cloudwego/eino/adk"

	"github.com/hippowc/brook/internal/brookdir"
	"github.com/hippowc/brook/internal/launcher"
	"github.com/hippowc/brook/pkg/a2ui"
)

// runCLI 非交互单次查询（旧版独立 brook 二进制行为）。
func runCLI(args []string) error {
	fs := flag.NewFlagSet("brook cli", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	cfgPath := fs.String("config", "", "agent 配置文件路径，默认 ~/.brook/agent.yaml")
	query := fs.String("query", "", "用户输入（非空则非交互运行一次）")
	cpID := fs.String("checkpoint-id", "", "中断恢复用的 checkpoint id")
	resumeInput := fs.String("resume-input", "", "Resume 时写入 session 的 resume_user 字段")
	a2uiOut := fs.Bool("a2ui", false, "将事件以 A2UI JSON Lines 输出到 stdout")
	if err := fs.Parse(args); err != nil {
		return err
	}

	ctx := context.Background()
	path := *cfgPath
	if path == "" {
		var err error
		path, err = brookdir.Ensure()
		if err != nil {
			slog.Error("brookdir", "err", err)
			return fmt.Errorf("brookdir: %w", err)
		}
	}
	rt, err := launcher.Load(ctx, path)
	if err != nil {
		slog.Error("load", "err", err)
		return fmt.Errorf("load: %w", err)
	}
	logPath, err := brookdir.LogFile()
	if err != nil {
		slog.Error("log path", "err", err)
		return fmt.Errorf("log path: %w", err)
	}
	if err := launcher.ApplyObservability(rt.Root, logPath, false); err != nil {
		slog.Error("logging", "err", err)
		return fmt.Errorf("logging: %w", err)
	}
	root := rt.Root
	r := rt.Runner
	sessKV := rt.Session

	userText := strings.TrimSpace(*query)
	if userText == "" {
		userText = strings.TrimSpace(root.Agent.UserPrompt)
	}
	if userText == "" {
		userText = "你好，简单介绍一下你能做什么。"
	}

	var iter *adk.AsyncIterator[*adk.AgentEvent]
	var snapSession func() map[string]any
	if *cpID != "" && *resumeInput != "" {
		sessKV["resume_user"] = *resumeInput
		cb, snap := launcher.SessionValuesSyncHandler()
		snapSession = snap
		iter, err = r.Resume(ctx, *cpID, adk.WithSessionValues(sessKV), adk.WithCallbacks(cb))
		if err != nil {
			slog.Error("resume", "err", err)
			return fmt.Errorf("resume: %w", err)
		}
	} else {
		cb, snap := launcher.SessionValuesSyncHandler()
		snapSession = snap
		opts := []adk.AgentRunOption{adk.WithSessionValues(sessKV), adk.WithCallbacks(cb)}
		if *cpID != "" {
			opts = append(opts, adk.WithCheckPointID(*cpID))
		}
		iter = r.Query(ctx, userText, opts...)
	}

	if *a2uiOut || root.A2UI.Enabled {
		ver := root.A2UI.Version
		if ver == "" {
			ver = "0.8"
		}
		if err := a2ui.WriteAgentEvents(os.Stdout, iter, ver); err != nil {
			slog.Error("a2ui", "err", err)
			return fmt.Errorf("a2ui: %w", err)
		}
	} else {
		for {
			ev, ok := iter.Next()
			if !ok {
				break
			}
			if ev == nil {
				continue
			}
			if ev.Err != nil {
				slog.Error("agent event error", "err", ev.Err)
				continue
			}
			if ev.Output != nil && ev.Output.MessageOutput != nil {
				printMessage(ev.Output.MessageOutput)
			}
			if ev.Action != nil && ev.Action.Interrupted != nil {
				fmt.Fprintf(os.Stderr, "[interrupt] %#v\n", ev.Action.Interrupted.Data)
			}
		}
	}

	if snapSession != nil {
		launcher.MergeSessionValues(sessKV, snapSession())
	}
	if err := rt.SaveSession(); err != nil {
		slog.Error("save session", "err", err)
		return fmt.Errorf("save session: %w", err)
	}
	return nil
}

func printMessage(mv *adk.MessageVariant) {
	if mv == nil {
		return
	}
	if mv.IsStreaming && mv.MessageStream != nil {
		for {
			msg, err := mv.MessageStream.Recv()
			if err != nil {
				break
			}
			fmt.Print(msg.Content)
		}
		fmt.Println()
		return
	}
	if mv.Message != nil {
		fmt.Println(mv.Message.Content)
	}
}
