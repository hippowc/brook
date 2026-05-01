// Package agentconfig 定义与 github.com/cloudwego/eino / ADK 概念对齐的可加载配置结构。
package agentconfig

// Root 为单文件根配置。
type Root struct {
	Version string `yaml:"version" json:"version"`

	Agent AgentSpec `yaml:"agent" json:"agent"`
	// Agents 为可复用子 Agent 注册表：各模式通过 id 引用。
	Agents map[string]SubAgentSpec `yaml:"agents,omitempty" json:"agents,omitempty"`
	// Modes 为各模式专属配置，agent.mode 仅做 selector。
	Modes ModesSpec `yaml:"modes,omitempty" json:"modes,omitempty"`

	Models        ModelsSpec        `yaml:"models" json:"models"`
	Memory        MemorySpec        `yaml:"memory,omitempty" json:"memory,omitempty"`
	Observability ObservabilitySpec `yaml:"observability,omitempty" json:"observability,omitempty"`
	Interrupt     InterruptSpec     `yaml:"interrupt,omitempty" json:"interrupt,omitempty"`
	A2UI          A2UISpec          `yaml:"a2ui,omitempty" json:"a2ui,omitempty"`
	Gateway       GatewaySpec       `yaml:"gateway,omitempty" json:"gateway,omitempty"`
}

// CurrentMode 返回当前激活模式配置。
func (r *Root) CurrentMode() AgentModeConfig {
	switch r.Agent.Mode {
	case ModeDeep:
		return r.Modes.Deep
	case ModeSequential:
		return r.Modes.Sequential
	case ModeParallel:
		return r.Modes.Parallel
	case ModeLoop:
		return r.Modes.Loop
	case ModeSupervisor:
		return r.Modes.Supervisor
	case ModePlanExecute:
		return r.Modes.PlanExecute
	case ModeCustom:
		return r.Modes.Custom
	default:
		return nil
	}
}

func (r *Root) CustomMode() *CustomModeConfig { return r.Modes.Custom }

// GatewaySpec 控制 `brook gateway`。
type GatewaySpec struct {
	Enabled bool   `yaml:"enabled" json:"enabled"`
	Listen  string `yaml:"listen,omitempty" json:"listen,omitempty"`

	ReadHeaderTimeoutSeconds int `yaml:"read_header_timeout_seconds,omitempty" json:"read_header_timeout_seconds,omitempty"`
	ReadTimeoutSeconds       int `yaml:"read_timeout_seconds,omitempty" json:"read_timeout_seconds,omitempty"`
	WriteTimeoutSeconds      int `yaml:"write_timeout_seconds,omitempty" json:"write_timeout_seconds,omitempty"`
	ShutdownTimeoutSeconds   int `yaml:"shutdown_timeout_seconds,omitempty" json:"shutdown_timeout_seconds,omitempty"`
	MaxRequestBodyBytes      int `yaml:"max_request_body_bytes,omitempty" json:"max_request_body_bytes,omitempty"`
	QueryTimeoutSeconds      int `yaml:"query_timeout_seconds,omitempty" json:"query_timeout_seconds,omitempty"`

	Auth      GatewayAuthSpec       `yaml:"auth,omitempty" json:"auth,omitempty"`
	RateLimit *GatewayRateLimitSpec `yaml:"rate_limit,omitempty" json:"rate_limit,omitempty"`
	Session   GatewaySessionSpec    `yaml:"session,omitempty" json:"session,omitempty"`
}

type GatewayAuthSpec struct {
	Mode               string `yaml:"mode,omitempty" json:"mode,omitempty"`
	BearerTokenEnv     string `yaml:"bearer_token_env,omitempty" json:"bearer_token_env,omitempty"`
	HMACSecretEnv      string `yaml:"hmac_secret_env,omitempty" json:"hmac_secret_env,omitempty"`
	HMACMaxSkewSeconds int    `yaml:"hmac_max_skew_seconds,omitempty" json:"hmac_max_skew_seconds,omitempty"`
}

type GatewayRateLimitSpec struct {
	Enabled           bool `yaml:"enabled" json:"enabled"`
	RequestsPerMinute int  `yaml:"requests_per_minute,omitempty" json:"requests_per_minute,omitempty"`
	Burst             int  `yaml:"burst,omitempty" json:"burst,omitempty"`
}

type GatewaySessionSpec struct {
	Store   string `yaml:"store,omitempty" json:"store,omitempty"`
	FileDir string `yaml:"file_dir,omitempty" json:"file_dir,omitempty"`
}

type A2UISpec struct {
	Enabled bool   `yaml:"enabled" json:"enabled"`
	Version string `yaml:"version,omitempty" json:"version,omitempty"`
}

type AgentSpec struct {
	Mode AgentMode `yaml:"mode" json:"mode"`

	Name             string `yaml:"name" json:"name"`
	Description      string `yaml:"description,omitempty" json:"description,omitempty"`
	Instruction      string `yaml:"instruction" json:"instruction"`
	UserPrompt       string `yaml:"user_prompt,omitempty" json:"user_prompt,omitempty"`
	MaxIterations    int    `yaml:"max_iterations,omitempty" json:"max_iterations,omitempty"`
	WorkingDirectory string `yaml:"working_directory,omitempty" json:"working_directory,omitempty"`

	Tools       ToolsSpec       `yaml:"tools,omitempty" json:"tools,omitempty"`
	Middlewares []MiddlewareRef `yaml:"middlewares,omitempty" json:"middlewares,omitempty"`
}

type AgentMode string

const (
	ModeReAct       AgentMode = "react"
	ModeDeep        AgentMode = "deep"
	ModeSequential  AgentMode = "sequential"
	ModeParallel    AgentMode = "parallel"
	ModeLoop        AgentMode = "loop"
	ModeSupervisor  AgentMode = "supervisor"
	ModePlanExecute AgentMode = "plan_execute"
	ModeCustom      AgentMode = "custom"
)

type SubAgentSpec struct {
	Name        string `yaml:"name,omitempty" json:"name,omitempty"`
	Description string `yaml:"description,omitempty" json:"description,omitempty"`
	Instruction string `yaml:"instruction,omitempty" json:"instruction,omitempty"`
	Model       string `yaml:"model,omitempty" json:"model,omitempty"`
}

type AgentModeConfig interface{ isModeConfig() }

type ModesSpec struct {
	Deep        *DeepModeConfig        `yaml:"deep,omitempty" json:"deep,omitempty"`
	Sequential  *SequentialModeConfig  `yaml:"sequential,omitempty" json:"sequential,omitempty"`
	Parallel    *ParallelModeConfig    `yaml:"parallel,omitempty" json:"parallel,omitempty"`
	Loop        *LoopModeConfig        `yaml:"loop,omitempty" json:"loop,omitempty"`
	Supervisor  *SupervisorModeConfig  `yaml:"supervisor,omitempty" json:"supervisor,omitempty"`
	PlanExecute *PlanExecuteModeConfig `yaml:"plan_execute,omitempty" json:"plan_execute,omitempty"`
	Custom      *CustomModeConfig      `yaml:"custom,omitempty" json:"custom,omitempty"`
}

type DeepModeConfig struct {
	AgentIDs               []string `yaml:"agent_ids,omitempty" json:"agent_ids,omitempty"`
	WithoutWriteTodos      bool     `yaml:"without_write_todos,omitempty" json:"without_write_todos,omitempty"`
	WithoutGeneralSubAgent bool     `yaml:"without_general_sub_agent,omitempty" json:"without_general_sub_agent,omitempty"`
	MaxIteration           int      `yaml:"max_iteration,omitempty" json:"max_iteration,omitempty"`
}

func (*DeepModeConfig) isModeConfig() {}

type SequentialModeConfig struct {
	AgentIDs []string `yaml:"agent_ids" json:"agent_ids"`
}

func (*SequentialModeConfig) isModeConfig() {}

type ParallelModeConfig struct {
	AgentIDs []string `yaml:"agent_ids" json:"agent_ids"`
}

func (*ParallelModeConfig) isModeConfig() {}

type LoopModeConfig struct {
	AgentIDs      []string `yaml:"agent_ids" json:"agent_ids"`
	MaxIterations int      `yaml:"max_iterations,omitempty" json:"max_iterations,omitempty"`
}

func (*LoopModeConfig) isModeConfig() {}

type SupervisorModeConfig struct {
	SupervisorID string   `yaml:"supervisor_id" json:"supervisor_id"`
	WorkerIDs    []string `yaml:"worker_ids" json:"worker_ids"`
}

func (*SupervisorModeConfig) isModeConfig() {}

type PlanExecuteModeConfig struct {
	PlannerID   string `yaml:"planner_id" json:"planner_id"`
	ExecutorID  string `yaml:"executor_id" json:"executor_id"`
	ReplannerID string `yaml:"replanner_id,omitempty" json:"replanner_id,omitempty"`
}

func (*PlanExecuteModeConfig) isModeConfig() {}

type CustomModeConfig struct {
	Script     string         `yaml:"script,omitempty" json:"script,omitempty"`
	AgentsFile string         `yaml:"agents_file,omitempty" json:"agents_file,omitempty"`
	Params     map[string]any `yaml:"params,omitempty" json:"params,omitempty"`
}

func (*CustomModeConfig) isModeConfig() {}

type ToolsSpec struct {
	Filesystem     *FilesystemToolsSpec `yaml:"filesystem,omitempty" json:"filesystem,omitempty"`
	ReturnDirectly map[string]bool      `yaml:"return_directly,omitempty" json:"return_directly,omitempty"`
}

type FilesystemToolsSpec struct {
	Enabled        bool                `yaml:"enabled" json:"enabled"`
	Backend        string              `yaml:"backend" json:"backend"`
	Shell          bool                `yaml:"shell,omitempty" json:"shell,omitempty"`
	StreamingShell bool                `yaml:"streaming_shell,omitempty" json:"streaming_shell,omitempty"`
	Local          *LocalBackendConfig `yaml:"local,omitempty" json:"local,omitempty"`
}

type LocalBackendConfig struct {
	StrictCommands bool `yaml:"strict_commands,omitempty" json:"strict_commands,omitempty"`
}

type MiddlewareRef struct {
	Name string         `yaml:"name" json:"name"`
	With map[string]any `yaml:"with,omitempty" json:"with,omitempty"`
}

type ModelsSpec struct {
	Providers map[string]ProviderConfig `yaml:"providers" json:"providers"`
	Active    ModelRef                  `yaml:"active" json:"active"`
}

type ModelRef struct {
	Provider string `yaml:"provider" json:"provider"`
	Model    string `yaml:"model" json:"model"`
}

type ProviderConfig struct {
	Driver    string         `yaml:"driver" json:"driver"`
	APIKeyEnv string         `yaml:"api_key_env,omitempty" json:"api_key_env,omitempty"`
	BaseURL   string         `yaml:"base_url,omitempty" json:"base_url,omitempty"`
	Extra     map[string]any `yaml:"extra,omitempty" json:"extra,omitempty"`
}

type MemorySpec struct {
	SessionStore       string `yaml:"session_store,omitempty" json:"session_store,omitempty"`
	SessionFilePath    string `yaml:"session_file_path,omitempty" json:"session_file_path,omitempty"`
	MaxContextMessages int    `yaml:"max_context_messages,omitempty" json:"max_context_messages,omitempty"`
	OutputKey          string `yaml:"output_key,omitempty" json:"output_key,omitempty"`
}

type ObservabilitySpec struct {
	GlobalHandlers []string `yaml:"global_handlers,omitempty" json:"global_handlers,omitempty"`
	LogLevel       string   `yaml:"log_level,omitempty" json:"log_level,omitempty"`
}

type InterruptSpec struct {
	Enabled            bool   `yaml:"enabled" json:"enabled"`
	CheckpointBackend  string `yaml:"checkpoint_backend,omitempty" json:"checkpoint_backend,omitempty"`
	CheckpointFilePath string `yaml:"checkpoint_file_path,omitempty" json:"checkpoint_file_path,omitempty"`
}
