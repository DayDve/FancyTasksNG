#!/usr/bin/env python3
# Regenerates cfg_*Default values in package/contents/config/ConfigPage.qml
# from the KConfigXT schema in package/contents/config/main.xml.
#
# The *Default properties drive KCM dirty-tracking; when they drift from the
# schema, pages report wrong save-needed state (and can silently rewrite user
# config on first Apply). Run this after changing any <default> in main.xml.
#
# Usage: python3 tools/sync_defaults.py [--check]
#   --check  exit 1 if out of sync, print report only

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "package" / "contents" / "config" / "main.xml"
PAGE = ROOT / "package" / "contents" / "config" / "ConfigPage.qml"

DEFAULT_LINE = re.compile(
    r"^(?P<prefix>\s*property\s+\w+\s+)(?P<name>cfg_\w+)Default(?P<mid>\s*:\s*)(?P<value>.*?)(?P<suffix>\s*)$"
)

STRINGY_TYPES = {"String", "Font", "Color", "Path", "Password"}


def unescape(text: str) -> str:
    return (
        text.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
        .replace("&apos;", "'")
        .replace("&amp;", "&")
    )


NS = "http://www.kde.org/standards/kcfg/1.0"


def schema_defaults() -> dict:
    tree = ET.parse(SCHEMA)
    result = {}
    for entry in tree.getroot().iter(f"{{{NS}}}entry"):
        name = entry.get("name")
        etype = entry.get("type")
        default_el = entry.find(f"{{{NS}}}default")
        default_text = unescape((default_el.text or "").strip()) if default_el is not None else ""
        result[name] = (etype, default_text)
    return result


def qml_literal(etype: str, text: str):
    if etype in ("Bool",):
        if text.lower() in ("true", "false"):
            return text.lower()
        return None
    if etype in ("Int", "Double", "Enum"):
        if text == "":
            return "0"
        try:
            float(text)
            return text
        except ValueError:
            return None
    if etype == "StringList":
        # Empty list is the only shape ConfigPage.qml uses today
        return "[]" if text == "" else None
    if etype in STRINGY_TYPES:
        return json.dumps(text)  # double-quoted, escaped
    return None


def main() -> int:
    check_only = "--check" in sys.argv[1:]
    schema = schema_defaults()

    lines = PAGE.read_text().splitlines(keepends=True)
    out = []
    changes = []
    seen_keys = set()

    for line in lines:
        m = DEFAULT_LINE.match(line.rstrip("\n"))
        if not m:
            out.append(line)
            continue
        key = m.group("name")[4:]  # strip cfg_ prefix
        seen_keys.add(key)
        info = schema.get(key)
        if info is None:
            out.append(line)
            continue
        etype, text = info
        literal = qml_literal(etype, text)
        old = m.group("value")
        if literal is None or literal == old:
            if literal is None:
                print(f"WARN unsupported default for {key} (type {etype}, value {text!r}), left as-is")
            out.append(line)
            continue
        if literal != old:
            changes.append((key, old, literal))
            new_line = f"{m.group('prefix')}{m.group('name')}Default{m.group('mid')}{literal}{m.group('suffix')}\n"
            out.append(new_line)
        else:
            out.append(line)

    # cfg_*Default without a schema entry (kept, reported only)
    phantom_report = sorted(k for k in seen_keys if k not in schema)

    orphan_report = sorted(set(schema) - seen_keys)

    if changes:
        print(f"{len(changes)} default(s) out of sync:")
        for key, old, new in changes:
            print(f"  {key}: {old} -> {new}")
    else:
        print("All cfg_*Default values match main.xml")

    if phantom_report:
        print(f"\ncfg_*Default without schema entry (not touched): {', '.join(phantom_report)}")
    if orphan_report:
        print(f"\nschema entries without cfg_*Default pair (info): {', '.join(orphan_report)}")

    if check_only:
        return 1 if changes else 0

    if changes:
        PAGE.write_text("".join(out))
        print(f"\nWritten: {PAGE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
