# neovim 常见用法

## 基本

```bash
nvim file.txt        # 打开文件
nvim -c "正常模式命令" # 打开后执行命令
```

模式：`i` 插入 / `Esc` 回正常 / `:` 命令行。最小生存：`:w` 保存、`:q` 退出、`:wq`、`:q!` 不保存退。

## 高频操作（正常模式）

```bash
/关键词 n N      # 搜索（下一个/上一个）
gg G 0 $        # 文首/文末/行首/行尾
dd yy p         # 删行/复制行/粘贴
u Ctrl-r        # 撤销/重做
:sp / :vsp      # 水平/垂直分屏，Ctrl-w 切换
:b 文件名        # 切 buffer
```

## 配置

配置在 `~/.config/nvim/init.lua`（或 init.vim）。插件生态推荐 lazy.nvim 起步；
想要开箱即用的现代体验也可以试 helix（brook helix install）。
