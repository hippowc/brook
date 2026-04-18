package gateway

import (
	"github.com/cloudwego/eino/adk"

	"github.com/hippowc/brook/internal/adkutil"
)

// CollectAssistantText 从 Agent 事件流中拼接 assistant 角色的文本（含流式分片）。
func CollectAssistantText(iter *adk.AsyncIterator[*adk.AgentEvent]) (string, error) {
	return adkutil.CollectAssistantText(iter)
}
