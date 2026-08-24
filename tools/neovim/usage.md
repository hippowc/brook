# neovim 常见用法（nvim：现代 Vim，内置 LSP / Lua 配置）

## 启动

```bash
nvim file.txt          # 打开
nvim .                 # 文件树（依赖插件配置）
```

## 核心键位（modal）

```bash
# normal 模式
i 插入；v 选中；ESC 回 normal
:w 保存；:q 退出；:wq 保存退出；:q! 不保存退出
dd 删行；yy 复制；p 粘贴；/ 搜索（n/N 下一个）
gg/G 首尾；:e file 打开；:bnext/:bprev 切 buffer
:set nu              # 行号
```

## 现代 nvim（0.10+ 内置 LSP）

```bash
vim.lsp 默认配置后：gd 跳定义 / K hover / <C-]> 引用
:nvim-tree 或 neo-tree 插件做文件树；telescope 做模糊查找（Ctrl+P 体验）
:Lazy 插件管理（如用 Lazy.nvim）
```

## Lean 起步建议

- 新手别直接抄大配置：先用 `nvim --clean` 体验原始，再按需加
- 想快上手的发行版：LazyVim / LunarVim（自带 LSP+树+查找，改键即可用）

## 与 brook

- nvim 生态靠插件，brook 只负责把 nvim 二进制装好；配置由你/发行版管理
- 终端补全/高亮可与 rg/fd/fzf 组合在 nvim 内使用

## 排查

- 启动报插件加载错 → `nvim --clean file` 排除配置问题；或 `:Lazy health`
- 粘贴缩进乱 → 终端粘贴建议 `:set paste` 或直接用系统剪贴板寄存器 `"+p`
