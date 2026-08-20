# fzf 常见用法

通用模糊过滤器：从 stdin 读行 → 模糊筛选 → 输出选中行。威力全在管道组合。

## 必做：接管快捷键

```bash
echo 'eval "$(fzf --bash)"' >> ~/.bashrc && source ~/.bashrc
# 之后：Ctrl-R 搜历史、Ctrl-T 补全文件名、Alt-C 跳目录
```

## 常用选项

```bash
-m / --multi              # 多选（tab 切换）
--exact                   # 精确匹配，关模糊
--height=40% --reverse    # 内嵌终端下方，输入框在顶
--preview 'bat --color=always {}'   # 预览窗（{} = 选中项）
--query='STR'             # 启动预填搜索词
```

## 两大经典场景（函数写进 ~/.bashrc）

```bash
ff() {  # 按文件名找
  fd --type f | fzf --preview 'bat --color=always {}' --query="$*" | xargs -r bat
}
fw() {  # 按内容找
  rg -l "$*" | fzf --preview "rg --color=always -n -C 3 -F '$*' {}" --query="$*" | xargs -r bat
}
```

## 全局默认

```bash
export FZF_DEFAULT_OPTS='--height=40% --reverse --info=inline --border'
```
