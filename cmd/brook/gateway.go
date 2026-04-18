package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/hippowc/brook/internal/brookdir"
	"github.com/hippowc/brook/internal/gateway"
	"github.com/hippowc/brook/internal/launcher"
)

// runGateway 启动 HTTP 网关。
func runGateway(args []string) error {
	fs := flag.NewFlagSet("brook gateway", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	cfgPath := fs.String("config", "", "agent 配置文件路径，默认 ~/.brook/agent.yaml")
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
			return err
		}
	}

	rt, err := launcher.Load(ctx, path)
	if err != nil {
		slog.Error("load", "err", err)
		return err
	}
	if !rt.Root.Gateway.Enabled {
		slog.Error("gateway disabled: set gateway.enabled: true in agent config")
		return errors.New("gateway disabled")
	}

	store, err := gateway.NewSessionStore(&rt.Root.Gateway)
	if err != nil {
		slog.Error("session store", "err", err)
		return err
	}

	logPath, err := brookdir.LogFile()
	if err != nil {
		slog.Error("log path", "err", err)
		return err
	}
	if err := launcher.ApplyObservability(rt.Root, logPath, false); err != nil {
		slog.Error("logging", "err", err)
		return err
	}

	runCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := gateway.Run(runCtx, rt, store); err != nil {
		if errors.Is(err, context.Canceled) {
			return nil
		}
		slog.Error("gateway", "err", err)
		return err
	}
	return nil
}
