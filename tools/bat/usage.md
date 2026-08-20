# bat 常见用法

## 基本

```bash
bat config.yaml                # 替 cat 看文件（高亮+行号+git 标记）
bat --color=always file.go     # 管道里必须带色（喂 fzf 等下游）
bat --paging=always file.log   # 当 less 分页
bat -r 10:50 file.go           # 只看 10~50 行
echo '{"a":1}' | bat -l json   # 高亮任意 stdin（指定语言）
```

## 常用选项

```bash
-n          # 只行号，关高亮
-p          # 像 cat 一样干净（关行号和装饰）
-A          # 显示不可见字符（debug 用）
-l yaml     # 强制指定语言
--style=numbers,changes,header   # 装饰组合
```

## 配置

偏好写 `~/.config/bat/config`（主题用 `bat --list-themes` 挑）。接入 man 和 git：

```bash
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
git config --global core.pager 'bat --paging=never'
```
