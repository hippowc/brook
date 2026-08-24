# ripgrep（rg）常见用法

极速文本搜索，默认尊重 .gitignore、只搜文本文件、输出带行号。

## 基本

```bash
rg  "pattern"                # 当前目录递归
rg  "TODO|FIXME" src/        # 指定目录
rg  -i "pattern"             # 忽略大小写
rg  -l "pattern"             # 只列文件名
rg  -n --color=always        # 管道给 less/fzf 时带色
rg  -C 3 "pattern"           # 上下文各 3 行
rg  "v\d+\.\d+"              # 正则（rg 用 Rust regex，语法与 PCRE 略不同）
```

## 进阶

```bash
rg '^def ' -g '*.py'         # 按 glob 过滤文件类型
rg -t py 'import'            # 爬常见语言类型（--type-list 看全部）
rg --hidden --glob '!.git'   # 含隐藏但排除 .git
rg -c "pattern" | sort -t: -k2 -rn   # 按命中数排序
rg -l "secret" | xargs sed -i 's/secret/xxx/g'   # 查找并批量替换（慎）
```

## 组合

- `rg -l "redis" | xargs vim`  打开所有命中文件
- `fzf --bind 'ctrl-r:reload(rg -l {q})'` 实时过滤文件列表

## 排查

- 搜不出中文 → 确认文件编码是 UTF-8（rg 默认按 UTF-8）
- 大小写不敏感用 `-i`；要 PCRE（回溯）用 `-P`
