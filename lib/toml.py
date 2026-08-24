#!/usr/bin/env python3
"""TOML 合并式写入（stdlib only）——只改目标键与目标表，其余内容原样保留。

用法：
  python3 lib/toml.py set-top FILE key=value [key=value...]       # 顶层标量键
  python3 lib/toml.py set-table FILE 表名 key=value [key=value...] # 整表 upsert

特性：
- 顶层键：就地更新已有行；缺失时在第一个表头之前补齐（TOML 顶层键必须出现在所有表之前）。
- 表：按表名整块替换；不存在则追加到文件末尾。
- 其余行（注释、[projects.*] 等）逐字节保留。
"""
import pathlib
import re
import sys

HDR = re.compile(r'^\[[^\]]+\]\s*$')


def esc(s: str) -> str:
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def load_lines(path: str) -> list:
    p = pathlib.Path(path)
    if not p.exists():
        return []
    text = p.read_text(encoding='utf-8')
    return text.rstrip('\n').split('\n') if text.strip() else []


def save(path: str, lines: list) -> None:
    pathlib.Path(path).write_text('\n'.join(lines) + ('\n' if lines else ''), encoding='utf-8')


def parse_kv(args: list) -> list:
    out = []
    for a in args:
        if '=' not in a:
            sys.exit(f'参数应为 key=value: {a!r}')
        k, v = a.split('=', 1)
        out.append((k, v))
    return out


def set_top(path: str, kvs: list) -> None:
    lines = load_lines(path)
    first_table = next((i for i, ln in enumerate(lines) if HDR.match(ln.strip())), None)
    top_end = first_table if first_table is not None else len(lines)
    pats = {k: re.compile('^' + re.escape(k) + r'\s*=') for k, _ in kvs}
    val = dict(kvs)
    replaced = set()
    for i in range(top_end):
        s = lines[i].strip()
        for k, pat in pats.items():
            if k not in replaced and pat.match(s):
                lines[i] = f'{k} = {esc(val[k])}'
                replaced.add(k)
                break
    missing = [f'{k} = {esc(v)}' for k, v in kvs if k not in replaced]
    if missing:
        if first_table is None:
            if lines and lines[-1].strip() != '':
                lines.append('')
            lines.extend(missing)
        else:
            if first_table > 0 and lines[first_table - 1].strip() != '':
                lines.insert(first_table, '')
                first_table += 1
            lines[first_table:first_table] = missing
            lines.insert(first_table + len(missing), '')
    save(path, lines)


def set_table(path: str, name: str, kvs: list) -> None:
    lines = load_lines(path)
    hdr = re.compile('^\\[' + re.escape(name) + r'\]\s*$')
    start = next((i for i, ln in enumerate(lines) if hdr.match(ln.strip())), None)
    block = [f'[{name}]'] + [f'{k} = {esc(v)}' for k, v in kvs]
    if start is not None:
        end = next((j for j in range(start + 1, len(lines)) if HDR.match(lines[j].strip())), len(lines))
        tail = [''] if end < len(lines) else []
        lines[start:end] = block + tail
        if start > 0 and lines[start - 1].strip() != '':
            lines.insert(start, '')
    else:
        if lines and lines[-1].strip() != '':
            lines.append('')
        lines.extend(block)
    save(path, lines)


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    cmd, path, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
    if cmd == 'set-top':
        set_top(path, parse_kv(rest))
    elif cmd == 'set-table' and len(rest) >= 1:
        set_table(path, rest[0], parse_kv(rest[1:]))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
