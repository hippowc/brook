# fd 常见用法

找**文件名**（rg 搜内容、fd 找名字）。默认跳过 .gitignore 和隐藏文件、智能大小写、递归。

## 基本

```bash
fd config                # 名字含 config
fd '\.md$'               # 正则：以 .md 结尾
fd -e md                 # 按扩展名（最常用）
fd -e py -e go           # 多种扩展名
fd -t f -e md            # 只要文件（-t d 目录 / -t l 链接）
fd -e md -x wc -l        # 对每个结果执行命令（替 find -exec）
fd --changed-within 7d   # 最近 7 天改过的
```

## 常用选项

```bash
-H / --hidden        # 也搜隐藏文件
-I / --no-ignore     # 不跳 .gitignore
-g '*.md'            # glob 精确匹配（不走正则）
-d 2                 # 限制递归深度
-x CMD / -X CMD      # 每项执行一次 / 全部一次性传入
```
