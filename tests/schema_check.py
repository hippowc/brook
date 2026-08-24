#!/usr/bin/env python3
"""brook L2 静态校验：工具/官方/镜像/代理/模型目录的结构与字段完整性。

用法：python3 tests/schema_check.py
违规项 → 打印并 exit 1；只有 warn 级 → exit 0。
原则：字段是"机制"的契约，契约错了不用等真机跑就能发现。
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors: list[str] = []
warns: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warns.append(msg)


# 提取 bash 脚本里的 KEY="value" / KEY='value' / KEY=value
_KV = re.compile('^([A-Za-z][A-Za-z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\'|(\\S+))\\s*$')


def kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = _KV.match(line)
        if m:
            out[m.group(1)] = m.group(2) if m.group(2) is not None else (m.group(3) if m.group(3) is not None else m.group(4))
    return out


def check_tools() -> None:
    for conf in sorted((ROOT / "tools").glob("*/tool.conf")):
        tool = conf.parent.name
        t = kv(conf.read_text(encoding="utf-8"))
        tag = f"tools/{tool}/tool.conf"
        # EXTERNAL_INSTALL=1：系统级工具（如 git），brook 只做配置不代装，字段要求放宽
        external = t.get("EXTERNAL_INSTALL") == "1"
        if external:
            for key in ("DESC", "BINARIES"):
                if not t.get(key):
                    err(f"{tag}: 缺必需字段 {key}")
        else:
            for key in ("DESC", "REPO", "ASSET", "BINARIES", "ARCHIVE"):
                if not t.get(key):
                    err(f"{tag}: 缺必需字段 {key}")
            if t.get("CATEGORY") not in ("binary", "language"):
                err(f"{tag}: CATEGORY 应为 binary|language（实际 {t.get('CATEGORY')!r}）")
            if t.get("REPO") and not re.match(r'^[^/\s]+/[^/\s]+$', t["REPO"]):
                err(f"{tag}: REPO 应为 owner/repo（实际 {t['REPO']!r}）")
            asset = t.get("ASSET", "")
            if asset and "{{" not in asset:
                err(f"{tag}: ASSET 应含 {{TAG}}/{{TARGET}} 占位符（实际 {asset!r}）")
            if t.get("ARCHIVE") not in ("tar.gz", "tar.xz", "zip", "zst", "raw"):
                err(f"{tag}: ARCHIVE 不在支持集合（实际 {t.get('ARCHIVE')!r}）")
            if t.get("CHECKSUM") not in ("none", "sha256-sidecar"):
                err(f"{tag}: CHECKSUM 应为 none|sha256-sidecar（实际 {t.get('CHECKSUM')!r}）")
            targets = [k for k in t if k.startswith("TARGET_")]
            if not targets:
                err(f"{tag}: 至少需要 1 个 TARGET_<os>_<arch> 映射")
            for k in targets:
                if not re.match(r'^[A-Za-z0-9_.-]+$', t[k]):
                    err(f"{tag}: {k} 值可疑（实际 {t[k]!r}）")
        if not (conf.parent / "usage.md").exists():
            err(f"tools/{tool}: 缺 usage.md（brook usage {tool} 依赖它）")
        cfgdir = conf.parent / "config"
        if cfgdir.is_dir():
            for cf in sorted(cfgdir.glob("*.sh")):
                body = cf.read_text(encoding="utf-8")
                if not body.strip():
                    err(f"{cf}: 配置实践为空文件")
                elif "config_" not in body:
                    err(f"{cf}: 至少应定义 config_run/config_desc/config_status 之一")


def check_codex_catalog() -> None:
    p = ROOT / "tools" / "codex" / "catalog.json"
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        err(f"tools/codex/catalog.json: JSON 解析失败（{e}）")
        return
    if not isinstance(data.get("models"), list) or not data["models"]:
        err("tools/codex/catalog.json: models 应为非空数组")
        return
    for m in data["models"]:
        slug = m.get("slug", "?")
        tag = f"catalog[{slug}]"
        for key in ("slug", "display_name", "description"):
            if not m.get(key):
                err(f"{tag}: 缺 {key}")
        if not isinstance(m.get("context_window"), int) or m["context_window"] <= 0:
            err(f"{tag}: context_window 应为正整数（实际 {m.get('context_window')!r}）")
        pct = m.get("effective_context_window_percent")
        if not isinstance(pct, (int, float)) or not (0 < pct <= 100):
            err(f"{tag}: effective_context_window_percent 应在 (0,100]（实际 {pct!r}）")
        for key in ("supports_parallel_tool_calls", "supports_reasoning_summaries"):
            if not isinstance(m.get(key), bool):
                err(f"{tag}: {key} 应为布尔（实际 {m.get(key)!r}）")
        if not isinstance(m.get("input_modalities"), list) or not m["input_modalities"]:
            err(f"{tag}: input_modalities 应为非空数组")
        if m.get("visibility") not in ("list", "hidden"):
            err(f"{tag}: visibility 应为 list|hidden（实际 {m.get('visibility')!r}）")
        tp = m.get("truncation_policy")
        if not isinstance(tp, dict) or not tp.get("mode") or not isinstance(tp.get("limit"), int):
            err(f"{tag}: truncation_policy 应含 mode+limit")


def check_official() -> None:
    for conf in sorted((ROOT / "official").glob("*.conf")):
        name = conf.stem
        o = kv(conf.read_text(encoding="utf-8"))
        tag = f"official/{name}.conf"
        for key in ("DESC", "CATEGORY", "SCRIPT_URL"):
            if not o.get(key):
                err(f"{tag}: 缺必需字段 {key}")
        if o.get("SCRIPT_URL") and not re.match(r'^https?://', o["SCRIPT_URL"]):
            err(f"{tag}: SCRIPT_URL 应为 http(s) URL")
        if not (o.get("BINARIES") or o.get("CHECK_FILES")):
            err(f"{tag}: 需提供 BINARIES 或 CHECK_FILES（判定安装状态用）")
        if not conf.with_name(name + ".usage.md").exists():
            err(f"official/{name}: 缺 usage.md")


def check_mirrors() -> None:
    for sh in sorted((ROOT / "mirrors").glob("*.sh")):
        body = sh.read_text(encoding="utf-8")
        tag = f"mirrors/{sh.name}"
        if "MIRROR_PROVIDERS" not in body:
            err(f"{tag}: 缺 MIRROR_PROVIDERS")
        if "mirror_desc" not in body:
            err(f"{tag}: 缺 mirror_desc")
        if not any(fn in body for fn in ("mirror_apply", "mirror_detect", "mirror_status")):
            err(f"{tag}: 至少实现 mirror_apply/mirror_detect/mirror_status 之一")


def check_proxies() -> None:
    p = ROOT / "proxies.conf"
    for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) not in (3, 4) or parts[1] not in ("prefix", "replace"):
            err(f"proxies.conf:{i}: 格式应为 名字|prefix|URL 或 名字|replace|从|到（实际 {line!r}）")


def check_basics() -> None:
    for lib in ("core.sh", "registry.sh", "official.sh", "mirror.sh", "proxy.sh"):
        if not (ROOT / "lib" / lib).exists():
            err(f"lib/{lib} 缺失")
    if not (ROOT / "lib" / "toml.py").exists():
        err("lib/toml.py 缺失（合并式写入 config.toml 依赖）")
    if not (ROOT / "brook").exists():
        err("brook 入口缺失")
    elif not (ROOT / "brook").stat().st_mode & 0o111:
        err("brook 入口不可执行（缺 +x）")



_BASH32_PAT = re.compile(r'\$([A-Za-z_][A-Za-z0-9_]*)([^\x00-\x7f])')


def _inside_single_quote(line: str, pos: int) -> bool:
    in_dq = in_sq = esc = False
    for i, c in enumerate(line):
        if i == pos:
            return in_sq
        if in_sq:
            if c == "'":
                in_sq = False
        elif in_dq:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_dq = False
        else:
            if c == "'":
                in_sq = True
            elif c == '"':
                in_dq = True
    return False


def check_bash32_compat() -> None:
    """bash 3.2（macOS）：`$VAR` 后紧跟非 ASCII 字符会把多字节首字节并进变量名
    → 必须写成 `${VAR}`。防止这类兼容 bug 回归。"""
    files = [ROOT / "brook"]
    files += sorted((ROOT / "lib").glob("*.sh"))
    files += sorted((ROOT / "mirrors").glob("*.sh"))
    files += sorted((ROOT / "official").glob("*.sh"))
    files += sorted((ROOT / "tools").glob("*/config/*.sh"))
    files += sorted((ROOT / "tools").glob("*/shell-init.sh"))
    files += sorted((ROOT / "tests").rglob("*.sh"))
    files += sorted((ROOT / "tests").rglob("*.bats"))
    # 无后缀 bash 脚本（如 fixtures/bin/curl、fixtures/bin/uname）也不能漏
    for f in (ROOT / "tests" / "fixtures" / "bin").glob("*"):
        if f.is_file():
            files.append(f)
    for f in files:
        if not f.exists():
            continue
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for m in _BASH32_PAT.finditer(line):
                if not _inside_single_quote(line, m.start()):
                    err(f"{f}:{i}: `$` 后变量名紧跟非 ASCII 字符（{m.group(2)}），"
                        f"bash 3.2 会解析异常，请用 ${{{m.group(1)}}}")


def check_bats_test_names() -> None:
    """bats 测试名必须纯 ASCII：macOS bash 3.2 无法解析含多字节字符的 @test 名
    （会把 UTF-8 首字节并进内部函数名 → 'unknown test name'）。"""
    for f in sorted((ROOT / "tests").glob("*.bats")):
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            st = line.strip()
            if not st.startswith("@test "):
                continue
            if any(ord(c) > 127 for c in st):
                err(f"{f}:{i}: @test 名含非 ASCII 字符（macOS bash 3.2 无法解析），请改为英文：{st!r}")

def main() -> int:
    check_basics()
    check_bats_test_names()
    check_bash32_compat()
    check_tools()
    check_codex_catalog()
    check_official()
    check_mirrors()
    check_proxies()
    for w in warns:
        print(f"[warn] {w}")
    for e in errors:
        print(f"[error] {e}")
    print(f"L2 静态校验：{len(errors)} 错误 / {len(warns)} 警告")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
