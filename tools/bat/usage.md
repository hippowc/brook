# bat 常见用法

现代 cat：语法高亮 + 行号 + Git 标记。装完直接替代 cat/less 的角色。

## 基本

```bash
bat config.yaml                # 替 cat 看文件（高亮+行号+git 标记）
bat --color=always file.go     # 管道里必须带色（喂 fzf/file 等下游）
bat --paging=always file.log   # 当 less 分页
bat -r 10:50 file.go           # 只看 10~50 行
echo '{"a":1}' | bat -l json   # 高亮任意 stdin（指定语言）
bat -A file.conf               # 显示不可见字符（debug 制表符/换行）
```

## 常用选项

```bash
-n          # 只行号，关高亮
-p          # 像 cat 一样干净（关行号和装饰）
--style=numbers,changes,header   # 装饰组合
--theme=Dracula               # 换主题（bat --list-themes 挑）
```

## 进阶：接入系统（装完建议做）

```bash
export MANPAGER="sh -c 'col -bx | bat -l man -p'"   # man 高亮
git config --global core.pager 'bat --paging=never' # git diff 高亮
```

偏好落 `~/.config/bat/config`（如 `--theme="Dracula"`）。
与 fzf 组合：`fzf --preview 'bat --color=always {}'`——文件选择即预览。

## 排查

- 管道里输出没颜色 → 忘加 `--color=always`（bat 检测到非 tty 自动关色）
- 中文乱码花屏 → 终端字体没装 Nerd Font 时换普通主题，或 `--italic-text=always` 关
