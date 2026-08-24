# helix 常见用法（hx：后现代终端编辑器，内置 LSP/Tree-sitter）

## 启动

```bash
hx file.txt            # 打开
hx .                   # 目录浏览（内置文件树）
hx --tutor             # 交互式教程（强烈推荐先跑一遍，20 分钟上手）
```

## 核心键位（modal，ESC 回 normal）

```bash
# normal 模式
x / v 选中 → d 删除 / y 复制 / C 复制到系统剪贴板
p / P  粘贴
/ 搜索，n/N 下一个/上一个；* 选词再按 n 找下一个
:sp / :vsp 分屏；:bd 关文件；:w 保存；:q 退出；:wq
gg/G 首尾；% 括号匹配；f<char> 跳字符；w/b 词导航
# 多光标：选中后 S 逐项选择性编辑，s 替换
```

## LSP（内置支持，自动起）

```bash
hx 打开 go/py/ts 文件即可有补全/跳转/hover
g d 跳定义；g r 找引用；space+k hover；space+a 代码操作（重命名等）
需要装对应 language server（如 go 用 gopls，python 用 pyright）
```

## 配置

- `~/.config/helix/config.toml`（主题/软换行/行号）
- `~/.config/helix/languages.toml`（LSP 配置）
- 配置文件改动即时生效（不用重启）

## 排查

- 没补全 → 缺 language server：`hx --health <lang>` 看缺什么
- 按键无反应 → 多半还停在 insert 模式，ESC 回 normal
