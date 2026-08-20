# rg 常见用法

搜文件**内容**。默认跳过 .gitignore 和隐藏文件、智能大小写、多线程。

## 基本

```bash
rg sing-box              # 当前目录递归搜
rg 'config' -t yaml      # 只在 yaml 文件里搜
rg 'TODO' -T markdown    # 排除某类文件
rg -C 3 'listen'         # 前后各 3 行上下文（-A 后 / -B 前）
rg -l 'sing-box'         # 只输出匹配的文件名
rg --type-list           # 列出支持的文件类型
```

## 常用选项

```bash
-i              # 忽略大小写
--hidden        # 也搜隐藏文件
--no-ignore     # 不跳 .gitignore
-g '!*.log'     # glob 过滤（排除 .log）
--no-heading    # 不按文件分组（喂 fzf 常用）
--vimgrep       # file:line:col:text 格式（编辑器跳转）
```

## 配置

偏好写 `~/.config/ripgrep/config`，并设 `export RIPGREP_CONFIG_PATH=~/.config/ripgrep/config`。
