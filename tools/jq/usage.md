# jq 常见用法（JSON 处理器）

## 基本

```bash
curl -s https://api.github.com/repos/hippowc/brook | jq '.stargazers_count'
echo '{"a":{"b":1}}' | jq '.a.b'
jq '.[]' file.json           # 数组每项
jq '.[0:3]' file.json        # 前 3 项
jq '.items[] | {name, id}'   # 选取字段成新对象
```

## 进阶

```bash
jq -r '.tag_name'              # -r 输出裸字符串（去引号，适合脚本）
jq '[.[] | select(.name|contains("linux"))]'   # 过滤
jq 'group_by(.type) | map({key: .[0].type, value: length})'  # 分组计数
jq -s 'add'                    # -s 把整个流当数组（多文档合并）
jq '. | keys'                  # 看有哪些字段
jq 'map(. + {ok:true})'        # 批量加字段
jq --arg v "$x" '.name=$v'     # 注入 shell 变量
```

## 典型场景：接 GitHub API

```bash
# 列出某 release 的资产名
curl -s https://api.github.com/repos/openai/codex/releases/latest | jq -r '.assets[].name'
# 与 brook 的 version 解析思路同源
```

## 排查

- 报错 `jq: error (at <stdin>:1): Cannot iterate over null` → 字段不存在，先 `. | keys` 看结构
- 管道里乱码 → 结尾加 `-r` 或用 `@tsv`（`jq -r '.[] | [.name,.size] | @tsv'`）
