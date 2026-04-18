// Starlark 驱动的 custom agent：编排脚本 + agents.yaml 子 Agent。
package agent

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudwego/eino/adk"
	"github.com/cloudwego/eino/compose"
	einomodel "github.com/cloudwego/eino/components/model"
	"github.com/cloudwego/eino/schema"
	"go.starlark.net/starlark"

	"github.com/hippowc/brook/internal/adkutil"
	agentfs "github.com/hippowc/brook/internal/core/fs"
	"github.com/hippowc/brook/pkg/agentconfig"

	"gopkg.in/yaml.v3"
)

type agentsYAML struct {
	Agents []struct {
		ID          string `yaml:"id"`
		Name        string `yaml:"name"`
		Instruction string `yaml:"instruction"`
	} `yaml:"agents"`
}

func buildCustom(ctx context.Context, root *agentconfig.Root, cm einomodel.BaseChatModel, bundle *agentfs.BackendBundle, extra []adk.ChatModelAgentMiddleware) (adk.Agent, error) {
	script := strings.TrimSpace(root.Agent.CustomScript)
	if script == "" {
		return newPendingCustomAgent(root, "empty"), nil
	}
	if _, err := os.Stat(script); err != nil {
		if os.IsNotExist(err) {
			return newPendingCustomAgent(root, "missing"), nil
		}
		return nil, fmt.Errorf("agent: custom_script %q: %w", script, err)
	}
	bundleRoot := filepath.Dir(script)
	agentsPath := strings.TrimSpace(root.Agent.CustomAgentsFile)
	if agentsPath == "" {
		agentsPath = filepath.Join(bundleRoot, "agents.yaml")
	} else if !filepath.IsAbs(agentsPath) {
		agentsPath = filepath.Join(bundleRoot, agentsPath)
	}
	b, err := os.ReadFile(agentsPath)
	if err != nil {
		return nil, fmt.Errorf("agent: read custom agents file %q: %w", agentsPath, err)
	}
	var ay agentsYAML
	if err := yaml.Unmarshal(b, &ay); err != nil {
		return nil, fmt.Errorf("agent: parse agents yaml: %w", err)
	}
	if len(ay.Agents) == 0 {
		return nil, fmt.Errorf("agent: agents.yaml must define at least one agent under `agents`")
	}

	sub := make(map[string]adk.Agent)
	for _, def := range ay.Agents {
		id := strings.TrimSpace(def.ID)
		if id == "" {
			continue
		}
		name := strings.TrimSpace(def.Name)
		if name == "" {
			name = id
		}
		inst := strings.TrimSpace(def.Instruction)
		cfg := &adk.ChatModelAgentConfig{
			Name:            name,
			Description:     root.Agent.Description + " / " + id,
			Instruction:     inst,
			Model:           cm,
			MaxIterations:   root.Agent.MaxIterations,
			Handlers:        chatHandlers(bundle, extra),
			OutputKey:       root.Memory.OutputKey,
			ToolsConfig: adk.ToolsConfig{
				ToolsNodeConfig: compose.ToolsNodeConfig{},
				ReturnDirectly:  root.Agent.Tools.ReturnDirectly,
			},
		}
		a, err := adk.NewChatModelAgent(ctx, cfg)
		if err != nil {
			return nil, fmt.Errorf("agent: sub-agent %q: %w", id, err)
		}
		sub[id] = a
	}
	if len(sub) == 0 {
		return nil, fmt.Errorf("agent: no valid agent ids in agents.yaml")
	}

	seed := int64(1)
	if root.Agent.CustomParams != nil {
		if v, ok := root.Agent.CustomParams["random_seed"]; ok {
			switch t := v.(type) {
			case int:
				seed = int64(t)
			case int64:
				seed = t
			case float64:
				seed = int64(t)
			}
		}
	}
	host := &starlarkHost{
		scriptPath: script,
		bundleRoot: bundleRoot,
		subAgents:  sub,
		root:       root,
		rng:        rand.New(rand.NewSource(seed)),
	}
	return &starlarkAgent{
		name:        root.Agent.Name,
		description: root.Agent.Description,
		host:        host,
	}, nil
}

type starlarkHost struct {
	runCtx context.Context
	// emitSubEvents 在 Run 的 goroutine 内由 call() 写入子 Agent 的流式分片；nil 时退回 CollectAssistantText（不向 UI 透传）。
	emitSubEvents func(*adk.AgentEvent)
	scriptPath    string
	bundleRoot    string
	subAgents     map[string]adk.Agent
	root          *agentconfig.Root
	rng           *rand.Rand
}

type starlarkAgent struct {
	name        string
	description string
	host        *starlarkHost
}

func (a *starlarkAgent) Name(_ context.Context) string        { return a.name }
func (a *starlarkAgent) Description(_ context.Context) string { return a.description }

func (a *starlarkAgent) Run(ctx context.Context, input *adk.AgentInput, opts ...adk.AgentRunOption) *adk.AsyncIterator[*adk.AgentEvent] {
	iter, gen := adk.NewAsyncIteratorPair[*adk.AgentEvent]()
	// 与 launcher 一致：默认流式；关闭时子 Agent 也不向 UI 透传分片。
	forwardSub := input == nil || input.EnableStreaming
	go func() {
		defer gen.Close()
		if forwardSub {
			a.host.emitSubEvents = func(ev *adk.AgentEvent) { gen.Send(ev) }
		} else {
			a.host.emitSubEvents = nil
		}
		defer func() { a.host.emitSubEvents = nil }()

		a.host.runCtx = ctx
		defer func() { a.host.runCtx = nil }()

		var userText string
		if input != nil {
			userText = lastUserPlainText(input.Messages)
		}
		thread := &starlark.Thread{
			Name: "brook-custom",
			Print: func(_ *starlark.Thread, msg string) {
				_ = msg
			},
		}
		thread.SetMaxExecutionSteps(10_000_000)

		state := starlark.NewDict(8)
		pre := a.host.predeclared(state)
		globals, err := starlark.ExecFile(thread, a.host.scriptPath, nil, pre)
		if err != nil {
			gen.Send(&adk.AgentEvent{Err: err})
			return
		}
		runFn, ok := globals["run"].(*starlark.Function)
		if !ok || runFn == nil {
			gen.Send(&adk.AgentEvent{Err: fmt.Errorf("custom: script must define top-level function run(user_text)")})
			return
		}
		val, err := starlark.Call(thread, runFn, starlark.Tuple{starlark.String(userText)}, nil)
		if err != nil {
			gen.Send(&adk.AgentEvent{Err: err})
			return
		}
		out := starlarkValueString(val)

		if key := strings.TrimSpace(a.host.root.Memory.OutputKey); key != "" {
			if m := adk.GetSessionValues(ctx); m != nil {
				m[key] = out
			}
		}
		out = strings.TrimSpace(out)
		if out != "" {
			gen.Send(&adk.AgentEvent{
				AgentName: a.name,
				Output: &adk.AgentOutput{
					MessageOutput: &adk.MessageVariant{
						IsStreaming: false,
						Message:     schema.AssistantMessage(out, nil),
						Role:        schema.Assistant,
					},
				},
			})
		}
	}()
	return iter
}

func lastUserPlainText(msgs []adk.Message) string {
	for i := len(msgs) - 1; i >= 0; i-- {
		m := msgs[i]
		if m == nil {
			continue
		}
		if m.Role == schema.User && strings.TrimSpace(m.Content) != "" {
			return m.Content
		}
	}
	return ""
}

func (h *starlarkHost) predeclared(state *starlark.Dict) starlark.StringDict {
	cfgVal, _ := goToStarlarkValue(h.root.Agent.CustomParams)
	if cfgVal == nil {
		cfgVal = starlark.NewDict(0)
	}
	d := starlark.StringDict{
		"cfg":   cfgVal,
		"state": state,
		"call":  starlark.NewBuiltin("call", h.builtinCall),
		"read_text": starlark.NewBuiltin("read_text", h.builtinReadText),
		"load_yaml": starlark.NewBuiltin("load_yaml", h.builtinLoadYAML),
		"rand_shuffle": starlark.NewBuiltin("rand_shuffle", h.builtinRandShuffle),
	}
	return d
}

func (h *starlarkHost) builtinCall(thread *starlark.Thread, b *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	if args.Len() != 2 {
		return nil, fmt.Errorf("call: want (agent_id, content)")
	}
	aid, ok := args.Index(0).(starlark.String)
	if !ok {
		return nil, fmt.Errorf("call: agent_id must be string")
	}
	content, ok := args.Index(1).(starlark.String)
	if !ok {
		return nil, fmt.Errorf("call: content must be string")
	}
	id := string(aid)
	ag := h.subAgents[id]
	if ag == nil {
		return nil, fmt.Errorf("call: unknown agent id %q", id)
	}
	if h.runCtx == nil {
		return nil, fmt.Errorf("call: internal error (no context)")
	}
	stream := h.emitSubEvents != nil
	iter := ag.Run(h.runCtx, &adk.AgentInput{
		Messages:        []adk.Message{schema.UserMessage(string(content))},
		EnableStreaming: stream,
	})
	var text string
	var err error
	if stream {
		text, err = h.forwardSubAgentRuns(id, iter)
	} else {
		text, err = adkutil.CollectAssistantText(iter)
	}
	if err != nil {
		return nil, err
	}
	return starlark.String(text), nil
}

// forwardSubAgentRuns 将子 Agent 的流式输出拆成多条事件送入外层 iterator，TUI 即可逐字/逐段刷新；返回值（无 [id] 前缀）供 Starlark 继续编排。
func (h *starlarkHost) forwardSubAgentRuns(agentID string, iter *adk.AsyncIterator[*adk.AgentEvent]) (string, error) {
	emit := h.emitSubEvents
	if emit == nil {
		return adkutil.CollectAssistantText(iter)
	}
	var acc strings.Builder
	for {
		ev, ok := iter.Next()
		if !ok {
			break
		}
		if ev == nil {
			continue
		}
		if ev.Err != nil {
			return acc.String(), ev.Err
		}
		if ev.Output == nil || ev.Output.MessageOutput == nil {
			continue
		}
		mv := ev.Output.MessageOutput
		if mv.Role == schema.Tool {
			ev.AgentName = agentID
			emit(ev)
			continue
		}
		if mv.Role != schema.Assistant {
			continue
		}
		if mv.IsStreaming && mv.MessageStream != nil {
			firstContent := true
			for {
				msg, err := mv.MessageStream.Recv()
				if err == io.EOF {
					break
				}
				if err != nil {
					return acc.String(), err
				}
				if msg == nil {
					continue
				}
				if msg.ReasoningContent != "" {
					emit(&adk.AgentEvent{
						AgentName: agentID,
						Output: &adk.AgentOutput{
							MessageOutput: &adk.MessageVariant{
								IsStreaming: false,
								Message: &schema.Message{
									Role:             schema.Assistant,
									ReasoningContent: msg.ReasoningContent,
								},
								Role: schema.Assistant,
							},
						},
					})
				}
				if msg.Content != "" {
					acc.WriteString(msg.Content)
					chunk := msg.Content
					if firstContent {
						chunk = "[" + agentID + "] " + chunk
						firstContent = false
					}
					emit(customAssistantTextEvent(agentID, chunk))
				}
			}
			continue
		}
		msg, err := mv.GetMessage()
		if err != nil {
			return acc.String(), err
		}
		if msg == nil {
			continue
		}
		if msg.ReasoningContent != "" {
			emit(&adk.AgentEvent{
				AgentName: agentID,
				Output: &adk.AgentOutput{
					MessageOutput: &adk.MessageVariant{
						IsStreaming: false,
						Message: &schema.Message{
							Role:             schema.Assistant,
							ReasoningContent: msg.ReasoningContent,
						},
						Role: schema.Assistant,
					},
				},
			})
		}
		if msg.Content != "" {
			acc.WriteString(msg.Content)
			emit(customAssistantTextEvent(agentID, "["+agentID+"] "+msg.Content))
		}
	}
	return acc.String(), nil
}

func customAssistantTextEvent(agentID, text string) *adk.AgentEvent {
	return &adk.AgentEvent{
		AgentName: agentID,
		Output: &adk.AgentOutput{
			MessageOutput: &adk.MessageVariant{
				IsStreaming: false,
				Message:     schema.AssistantMessage(text, nil),
				Role:        schema.Assistant,
			},
		},
	}
}

func (h *starlarkHost) safePath(rel string) (string, error) {
	rel = filepath.Clean(rel)
	if rel == "." || rel == "" {
		return "", fmt.Errorf("path is empty")
	}
	if strings.Contains(rel, "..") {
		return "", fmt.Errorf("path must not contain ..")
	}
	full := filepath.Join(h.bundleRoot, rel)
	rootClean := filepath.Clean(h.bundleRoot)
	fullClean := filepath.Clean(full)
	rp, err := filepath.Rel(rootClean, fullClean)
	if err != nil || strings.HasPrefix(rp, "..") {
		return "", fmt.Errorf("path escapes bundle root")
	}
	return fullClean, nil
}

func (h *starlarkHost) builtinReadText(thread *starlark.Thread, b *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	if args.Len() != 1 {
		return nil, fmt.Errorf("read_text: want (path)")
	}
	p, ok := args.Index(0).(starlark.String)
	if !ok {
		return nil, fmt.Errorf("read_text: path must be string")
	}
	full, err := h.safePath(string(p))
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(full)
	if err != nil {
		return nil, err
	}
	return starlark.String(string(raw)), nil
}

func (h *starlarkHost) builtinLoadYAML(thread *starlark.Thread, b *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	if args.Len() != 1 {
		return nil, fmt.Errorf("load_yaml: want (path)")
	}
	p, ok := args.Index(0).(starlark.String)
	if !ok {
		return nil, fmt.Errorf("load_yaml: path must be string")
	}
	full, err := h.safePath(string(p))
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(full)
	if err != nil {
		return nil, err
	}
	var data any
	if err := yaml.Unmarshal(raw, &data); err != nil {
		return nil, err
	}
	return goToStarlarkValue(data)
}

func (h *starlarkHost) builtinRandShuffle(thread *starlark.Thread, b *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	if args.Len() != 1 {
		return nil, fmt.Errorf("rand_shuffle: want (list)")
	}
	list, ok := args.Index(0).(*starlark.List)
	if !ok {
		return nil, fmt.Errorf("rand_shuffle: need list")
	}
	n := list.Len()
	items := make([]starlark.Value, n)
	for i := 0; i < n; i++ {
		items[i] = list.Index(i)
	}
	h.rng.Shuffle(n, func(i, j int) { items[i], items[j] = items[j], items[i] })
	return starlark.NewList(items), nil
}

func goToStarlarkValue(v any) (starlark.Value, error) {
	switch t := v.(type) {
	case nil:
		return starlark.None, nil
	case bool:
		return starlark.Bool(t), nil
	case int:
		return starlark.MakeInt(t), nil
	case int64:
		return starlark.MakeInt64(t), nil
	case float64:
		return starlark.Float(t), nil
	case string:
		return starlark.String(t), nil
	case []any:
		elts := make([]starlark.Value, 0, len(t))
		for _, e := range t {
			sv, err := goToStarlarkValue(e)
			if err != nil {
				return nil, err
			}
			elts = append(elts, sv)
		}
		return starlark.NewList(elts), nil
	case map[string]any:
		d := starlark.NewDict(len(t))
		for k, val := range t {
			sv, err := goToStarlarkValue(val)
			if err != nil {
				return nil, err
			}
			if err := d.SetKey(starlark.String(k), sv); err != nil {
				return nil, err
			}
		}
		return d, nil
	default:
		return starlark.String(fmt.Sprint(t)), nil
	}
}

func starlarkValueString(v starlark.Value) string {
	if s, ok := v.(starlark.String); ok {
		return string(s)
	}
	return v.String()
}

// pendingCustomAgent：未配置 custom_script 或脚本文件不存在时的占位，保证 launcher.Load 成功。
type pendingCustomAgent struct {
	name string
	desc string
	body string
}

func newPendingCustomAgent(root *agentconfig.Root, reason string) adk.Agent {
	var body string
	switch reason {
	case "empty":
		body = "当前为 custom 模式，但尚未配置 agent.custom_script。\n请在 agent.yaml 中设置指向 .star 文件的路径，或在 Brook TUI 中使用「/custom build」进入创建模式。"
	case "missing":
		p := strings.TrimSpace(root.Agent.CustomScript)
		body = fmt.Sprintf("custom_script 配置的路径不存在：%s\n请修正路径或改用「/custom build」在 TUI 中生成编排。", p)
	default:
		body = reason
	}
	return &pendingCustomAgent{name: root.Agent.Name, desc: root.Agent.Description, body: body}
}

func (a *pendingCustomAgent) Name(_ context.Context) string { return a.name }

func (a *pendingCustomAgent) Description(_ context.Context) string { return a.desc }

func (a *pendingCustomAgent) Run(ctx context.Context, _ *adk.AgentInput, _ ...adk.AgentRunOption) *adk.AsyncIterator[*adk.AgentEvent] {
	_ = ctx
	iter, gen := adk.NewAsyncIteratorPair[*adk.AgentEvent]()
	go func() {
		defer gen.Close()
		gen.Send(&adk.AgentEvent{
			AgentName: a.name,
			Output: &adk.AgentOutput{
				MessageOutput: &adk.MessageVariant{
					IsStreaming: false,
					Message:     schema.AssistantMessage(a.body, nil),
					Role:        schema.Assistant,
				},
			},
		})
	}()
	return iter
}
