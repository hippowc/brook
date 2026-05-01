package tui

import (
	"github.com/atotto/clipboard"
	tea "github.com/charmbracelet/bubbletea"
)

func (m *Model) copyConfigEditorToClipboard() (tea.Model, tea.Cmd) {
	s := m.cfgTA.Value()
	if s == "" {
		return m, nil
	}
	if err := clipboard.WriteAll(s); err != nil {
		return m, nil
	}
	return m, nil
}
