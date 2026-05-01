package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/google/uuid"

	"github.com/hippowc/brook/internal/brookdir"
	"github.com/hippowc/brook/internal/business/conversation"
	"github.com/hippowc/brook/internal/launcher"
	"github.com/hippowc/brook/internal/tui"
)

// runTUI 启动 Bubble Tea 交互界面（默认子命令）。
func runTUI(args []string) {
	fs := flag.NewFlagSet("brook tui", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	cfg := fs.String("config", "", "agent 配置文件路径，默认 ~/.brook/agent.yaml")
	convFlag := fs.String("conversation", "", "会话 UUID；默认读取 ~/.brook/current_conversation，若无则新建")
	newConv := fs.Bool("new", false, "忽略 current_conversation，强制新建会话 UUID")
	if args == nil {
		args = []string{}
	}
	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(os.Stderr, "brook tui: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()
	cfgPath := *cfg
	if cfgPath == "" {
		var err error
		cfgPath, err = brookdir.Ensure()
		if err != nil {
			fmt.Fprintf(os.Stderr, "brookdir: %v\n", err)
			os.Exit(1)
		}
	}

	rt, err := launcher.Load(ctx, cfgPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "load: %v\n", err)
		os.Exit(1)
	}

	logPath, _ := brookdir.LogFile()
	if err := launcher.ApplyObservability(rt.Root, logPath, true); err != nil {
		fmt.Fprintf(os.Stderr, "logging: %v\n", err)
		os.Exit(1)
	}

	convID, err := resolveConversationID(*newConv, strings.TrimSpace(*convFlag))
	if err != nil {
		fmt.Fprintf(os.Stderr, "conversation: %v\n", err)
		os.Exit(1)
	}

	m := tui.New(rt, cfgPath, convID)
	// 启用鼠标单元格事件：用于在主会话区拖动选区（配合 Ctrl+Shift+C / Alt+C 复制）。
	p := tea.NewProgram(m, tea.WithAltScreen(), tea.WithMouseCellMotion())
	final, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "tui: %v\n", err)
		os.Exit(1)
	}

	tm, ok := final.(*tui.Model)
	if !ok || tm == nil {
		return
	}
	if err := tm.SaveConversation(); err != nil {
		fmt.Fprintf(os.Stderr, "save conversation: %v\n", err)
		os.Exit(1)
	}
	if err := tm.Runtime().SaveSession(); err != nil {
		fmt.Fprintf(os.Stderr, "save session: %v\n", err)
		os.Exit(1)
	}
}

func resolveConversationID(forceNew bool, explicit string) (string, error) {
	if forceNew {
		return uuid.New().String(), nil
	}
	if explicit != "" {
		if err := conversation.ValidateID(explicit); err != nil {
			return "", err
		}
		return explicit, nil
	}
	cur, err := brookdir.ReadCurrentConversationID()
	if err != nil {
		return "", err
	}
	if cur != "" {
		if err := conversation.ValidateID(cur); err != nil {
			return uuid.New().String(), nil
		}
		return cur, nil
	}
	return uuid.New().String(), nil
}
