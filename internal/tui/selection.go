package tui

import (
	"strings"

	"github.com/atotto/clipboard"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

const (
	selRevStart = "\x1b[7m"
	selRevEnd   = "\x1b[27m"
)

func (m *Model) resetViewportSelection() {
	m.selMouseDown = false
	m.selDragging = false
	m.selARow = -1
	m.selACol = 0
	m.selBRow = -1
	m.selBCol = 0
}

// viewportOrigin 返回主会话区左上角在终端中的行列（0-based），需与 View() 拼接顺序一致。
func (m *Model) viewportOrigin() (top, left int) {
	top = lipgloss.Height(m.renderHeader())
	left = 1 // styleApp 水平 Padding(0,1)：内容相对终端左缘偏移一列
	return top, left
}

func (m *Model) viewportContentWidth() int {
	w := m.vp.Width - m.vp.Style.GetHorizontalFrameSize()
	if w < 1 {
		w = 1
	}
	return w
}

func (m *Model) viewportContentHeight() int {
	h := m.vp.Height - m.vp.Style.GetVerticalFrameSize()
	if h < 1 {
		h = 1
	}
	return h
}

func mouseInViewport(m *Model, my, mx int) bool {
	top, left := m.viewportOrigin()
	w := m.viewportContentWidth()
	h := m.viewportContentHeight()
	return my >= top && my < top+h && mx >= left && mx < left+w
}

func (m *Model) mouseToDocCell(my, mx int) (docRow, visCol int) {
	top, left := m.viewportOrigin()
	docRow = m.vp.YOffset + (my - top)
	visCol = mx - left
	lines := m.viewportLines()
	n := len(lines)
	if n == 0 {
		return 0, 0
	}
	docRow = clampInt(docRow, 0, n-1)
	w := ansi.StringWidth(lines[docRow])
	if w < 1 {
		w = 1
	}
	visCol = clampInt(visCol, 0, w-1)
	return docRow, visCol
}

func (m *Model) viewportLines() []string {
	if strings.TrimSpace(m.vpContentRaw) == "" {
		return nil
	}
	return strings.Split(m.vpContentRaw, "\n")
}

func (m *Model) handleViewportMouse(msg tea.MouseMsg) bool {
	ev := tea.MouseEvent(msg)
	if ev.IsWheel() {
		return false
	}
	if m.busy || m.editingConfig {
		return false
	}

	switch msg.Action {
	case tea.MouseActionPress:
		if msg.Button != tea.MouseButtonLeft {
			return false
		}
		if !mouseInViewport(m, msg.Y, msg.X) {
			return false
		}
		m.selMouseDown = true
		m.selDragging = true
		r, c := m.mouseToDocCell(msg.Y, msg.X)
		m.selARow, m.selACol = r, c
		m.selBRow, m.selBCol = r, c
		m.repaintViewportPreserve()
		return true

	case tea.MouseActionMotion:
		if !m.selMouseDown || !m.selDragging {
			return false
		}
		r, c := m.mouseToDocCell(msg.Y, msg.X)
		m.selBRow, m.selBCol = r, c
		m.repaintViewportPreserve()
		return true

	case tea.MouseActionRelease:
		if msg.Button != tea.MouseButtonLeft || !m.selMouseDown {
			return false
		}
		m.selMouseDown = false
		m.selDragging = false
		r, c := m.mouseToDocCell(msg.Y, msg.X)
		m.selBRow, m.selBCol = r, c
		if m.selARow == m.selBRow && m.selACol == m.selBCol {
			m.resetViewportSelection()
		}
		m.repaintViewportPreserve()
		return true
	default:
		return false
	}
}

func (m *Model) repaintViewportPreserve() {
	if strings.TrimSpace(m.vpContentRaw) == "" {
		return
	}
	off := m.vp.YOffset
	m.syncViewportLayout()
	m.vp.SetContent(m.applySelectionHighlight(m.vpContentRaw))
	m.vp.SetYOffset(off)
}

func (m *Model) selNormalizedInclusive() (r1, c1, r2, c2 int) {
	lines := m.viewportLines()
	n := len(lines)
	if n == 0 || m.selARow < 0 {
		return 0, 0, 0, 0
	}
	r1, c1 = m.selARow, m.selACol
	r2, c2 = m.selBRow, m.selBCol
	if r1 > r2 || (r1 == r2 && c1 > c2) {
		r1, r2 = r2, r1
		c1, c2 = c2, c1
	}
	r1 = clampInt(r1, 0, n-1)
	r2 = clampInt(r2, 0, n-1)
	w1 := lineVisualWidth(lines[r1])
	w2 := lineVisualWidth(lines[r2])
	c1 = clampInt(c1, 0, max(0, w1-1))
	c2 = clampInt(c2, 0, max(0, w2-1))
	return r1, c1, r2, c2
}

func lineVisualWidth(line string) int {
	w := ansi.StringWidth(line)
	if w < 1 {
		return 1
	}
	return w
}

func (m *Model) selNonEmpty() bool {
	if m.selARow < 0 {
		return false
	}
	r1, c1, r2, c2 := m.selNormalizedInclusive()
	return !(r1 == r2 && c1 == c2)
}

func (m *Model) applySelectionHighlight(content string) string {
	if content == "" || m.selARow < 0 || !m.selNonEmpty() {
		return content
	}
	r1, c1, r2, c2 := m.selNormalizedInclusive()
	lines := strings.Split(content, "\n")
	if len(lines) == 0 {
		return content
	}
	for ri := r1; ri <= r2; ri++ {
		if ri < 0 || ri >= len(lines) {
			continue
		}
		line := lines[ri]
		lw := ansi.StringWidth(line)
		if lw == 0 {
			continue
		}
		lc1 := 0
		lc2 := lw - 1
		if ri == r1 {
			lc1 = c1
		}
		if ri == r2 {
			lc2 = c2
		}
		lc1 = clampInt(lc1, 0, lw-1)
		lc2 = clampInt(lc2, 0, lw-1)
		if lc2 < lc1 {
			continue
		}
		lines[ri] = highlightVisualRange(line, lc1, lc2)
	}
	return strings.Join(lines, "\n")
}

func highlightVisualRange(line string, c1, c2Inclusive int) string {
	w := ansi.StringWidth(line)
	if w == 0 {
		return line
	}
	c1 = clampInt(c1, 0, w-1)
	c2Inclusive = clampInt(c2Inclusive, 0, w-1)
	if c2Inclusive < c1 {
		return line
	}
	rightEx := c2Inclusive + 1
	head := ansi.Cut(line, 0, c1)
	mid := ansi.Cut(line, c1, rightEx)
	tail := ansi.Cut(line, rightEx, w)
	return head + selRevStart + mid + selRevEnd + tail
}

func (m *Model) selectedPlainText() string {
	if !m.selNonEmpty() {
		return ""
	}
	r1, c1, r2, c2 := m.selNormalizedInclusive()
	lines := m.viewportLines()
	var b strings.Builder
	for ri := r1; ri <= r2; ri++ {
		pl := ansi.Strip(lines[ri])
		lw := ansi.StringWidth(pl)
		if lw == 0 {
			continue
		}
		lc1 := 0
		lc2 := lw - 1
		if ri == r1 {
			lc1 = c1
		}
		if ri == r2 {
			lc2 = c2
		}
		lc1 = clampInt(lc1, 0, lw-1)
		lc2 = clampInt(lc2, 0, lw-1)
		if lc2 < lc1 {
			continue
		}
		seg := ansi.Cut(pl, lc1, lc2+1)
		b.WriteString(seg)
		if ri < r2 {
			b.WriteByte('\n')
		}
	}
	return b.String()
}

func (m *Model) tryPasteChord(msg tea.KeyMsg) bool {
	if !m.isDarwin() {
		return false
	}
	s := msg.String()
	if s == "alt+v" {
		return true
	}
	if msg.Type == tea.KeyRunes && msg.Alt && len(msg.Runes) == 1 && msg.Runes[0] == 'v' {
		return true
	}
	return false
}

func (m *Model) tryCopySelectionChord(msg tea.KeyMsg) bool {
	if !copyChordMatched(msg) {
		return false
	}
	txt := m.selectedPlainText()
	if txt != "" {
		_ = clipboard.WriteAll(txt)
	}
	return true
}

func copyChordMatched(msg tea.KeyMsg) bool {
	if msg.String() == "ctrl+shift+c" {
		return true
	}
	if msg.String() == "alt+c" {
		return true
	}
	if msg.Type == tea.KeyRunes && msg.Alt && len(msg.Runes) == 1 && msg.Runes[0] == 'c' {
		return true
	}
	return false
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
