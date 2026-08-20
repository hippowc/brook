# helix 常见用法

后现代编辑器：内置 LSP/Tree-sitter/多光标，零配置即可用。

## 基本

```bash
hx file.txt       # 打开文件
```

模式：正常（默认）/ `i` 插入 / `v` 选择 / `:` 命令 / `space` 菜单。
`:w` 保存、`:q` 退出、`:wq`、`:q!` 强退。

## 核心手感（先选后动，和 vim 相反）

```bash
w b e        # 按词移动    f/t + 字符   # 行内跳转
m            # 匹配括号    x            # 选整行（连按扩选）
d / y / c    # 删/复制/改当前选区    p 粘贴
u / U        # 撤销/重做
/ n N        # 搜索
space f      # 文件 picker（模糊找文件）    space b  # buffer 列表
K            # 看文档（LSP）    gd  # 跳定义
```

## 配置

`~/.config/helix/config.toml`（主题 `theme = "catppuccin_mocha"` 等，`hx --tutor` 有交互教程）。
