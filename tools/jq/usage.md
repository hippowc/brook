# jq 常见用法

命令行 JSON 处理器：读 JSON → 过滤/变换 → 输出。

## 基本

```bash
echo '{"a":{"b":1}}' | jq '.a.b'        # 取字段 → 1
jq '.[0]' arr.json                       # 数组第 0 个
jq '.[] | .name' arr.json                # 遍历数组取字段
jq 'select(.age > 18)' arr.json          # 过滤
jq length arr.json                       # 数组长度/对象键数
```

## 常用选项

```bash
-r          # raw 输出（字符串不带引号，脚本里必加）
-c          # 紧凑单行输出
-s          # slurp：整个输入当一个数组
--arg k v   # 传变量进表达式：jq --arg name x '.[] | select(.n==$name)'
-e          # 按结果真假设置退出码（if 判断用）
```

## 实战：配 curl 解析 API

```bash
curl -s https://api.github.com/repos/openai/codex/releases/latest \
  | jq -r '.tag_name'
```
