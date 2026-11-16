#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

"""Turns a `make diag` report into the setup of the nested test session
(make test-panel / test-desktop CONFIG=<report>), so a reporter's setup can be
reproduced without running anything on their machine.

Writes to OUT_DIR:
  setup.js    plasmashell script: the widget's settings and, in a panel, the
              panel's location, thickness, length, alignment and floating
  screen.txt  WIDTHxHEIGHT for SCREEN: the reporter's screen (logical pixels)
              under the panel, scaled down to fit this monitor if needed

Notes go to stderr. Values diag.sh masked ($USER, ...UUID..., ...) are left
out: the widget keeps its default for them.

Usage: diag_setup.py REPORT OUT_DIR [--instance N] [--monitor WxH]
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

MASKS = ("$USER", "$HOSTNAME", "...UUID...", "...MAC...")
INSTANCE_RE = re.compile(r"^== Instance: Containment #(\d+), Applet #(\d+)")
GROUP_RE = re.compile(r"^\[.*\]$")


def note(text):
    print(f"   {text}", file=sys.stderr)


def unescape(value):
    """KConfig value escapes: \\s \\t \\n \\r \\\\ and \\xNN."""
    out, i = [], 0
    while i < len(value):
        c = value[i]
        if c == "\\" and i + 1 < len(value):
            n = value[i + 1]
            if n in "stnr\\":
                out.append({"s": " ", "t": "\t", "n": "\n", "r": "\r", "\\": "\\"}[n])
                i += 2
                continue
            if n == "x" and i + 3 < len(value):
                out.append(chr(int(value[i + 2:i + 4], 16)))
                i += 4
                continue
        out.append(c)
        i += 1
    return "".join(out)


def sections(text):
    """Report sections by their '### ' title."""
    result, current = {}, None
    for line in text.splitlines():
        if line.startswith("### "):
            current = line[4:].strip()
            result[current] = []
        elif current is not None:
            result[current].append(line)
    return result


def parse_instances(lines):
    """[(containment, applet, {group: {key: value}})]; the containment's own
    lines go under the group "containment"."""
    instances = []
    groups = group = None
    for line in lines:
        m = INSTANCE_RE.match(line)
        if m:
            groups = {}
            instances.append((m.group(1), m.group(2), groups))
            group = None
            continue
        if groups is None:
            continue
        text = line.strip()
        if text == "Panel containment:":
            group = groups.setdefault("containment", {})
        elif text.endswith(":") and "=" not in text:
            group = None
        elif GROUP_RE.match(text):
            group = groups.setdefault(text, {})
        elif "=" in text and group is not None:
            key, value = text.split("=", 1)
            group[re.sub(r"\[\$.*\]$", "", key)] = value
    return instances


def parse_outputs(lines):
    """[{name, enabled, priority, width, height, scale}] from the Displays section."""
    outputs = []
    for line in lines:
        text = line.strip()
        if line.startswith("Output:"):
            parts = text.split()
            outputs.append({"name": parts[2] if len(parts) > 2 else "?", "enabled": False,
                            "priority": 0, "width": 0, "height": 0, "scale": "1"})
        elif outputs:
            out = outputs[-1]
            if text == "enabled":
                out["enabled"] = True
            elif text.startswith("priority "):
                out["priority"] = int(text.split()[1])
            elif text.startswith("Geometry:"):
                m = re.search(r"(\d+)x(\d+)", text)
                if m:
                    out["width"], out["height"] = int(m.group(1)), int(m.group(2))
            elif text.startswith("Scale:"):
                out["scale"] = text.split(":", 1)[1].strip()
    return [o for o in outputs if o["enabled"] and o["width"] > 0]


def local_monitor():
    """This session's main monitor (priority 1) in logical pixels, or None."""
    try:
        text = subprocess.run(["kscreen-doctor", "--outputs"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    outputs = parse_outputs(re.sub(r"\x1b\[[0-9;]*m", "", text).splitlines())
    outputs.sort(key=lambda o: o["priority"] or 99)
    return (outputs[0]["width"], outputs[0]["height"]) if outputs else None


def fit_screen(width, height, monitor):
    """The reporter's screen as it is when it fits this monitor (with room for
    the window frame), otherwise scaled down to the same proportions."""
    if not monitor:
        return width, height
    limit_w, limit_h = monitor[0] * 0.95, monitor[1] * 0.9
    factor = min(1.0, limit_w / width, limit_h / height)
    return round(width * factor), round(height * factor)


def js_string(value):
    return json.dumps(value, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("report")
    parser.add_argument("out_dir")
    parser.add_argument("--instance", type=int, default=0, help="1-based; the first one when not given")
    parser.add_argument("--monitor", help="WxH of this monitor; asked from kscreen-doctor when not given")
    args = parser.parse_args()

    report = sections(Path(args.report).read_text(encoding="utf-8", errors="replace"))
    instances = parse_instances(report.get("Fancy Tasks NG instances", []))
    if not instances:
        sys.exit("No Fancy Tasks NG instance in the report.")
    if args.instance > len(instances) or args.instance < 0:
        sys.exit(f"INSTANCE={args.instance}, but the report has {len(instances)} instance(s).")
    if len(instances) > 1:
        listing = ", ".join(f"{i + 1}: containment #{c}" for i, (c, _, _) in enumerate(instances))
        note(f"The report has {len(instances)} instances ({listing}); "
             f"using {args.instance or 1}. INSTANCE=N picks another.")
    containment, applet, groups = instances[(args.instance or 1) - 1]

    js = ['var w = panels().concat(desktops()).map(function (c) {',
          '    return c.widgets("io.github.daydve.fancytasksng")[0];',
          '}).filter(Boolean)[0];']
    prefix = f"[Containments][{containment}][Applets][{applet}][Configuration]"
    written, skipped = 0, []
    for group, entries in groups.items():
        if not group.startswith(prefix) or group == prefix + "[ConfigDialog]":
            continue
        path = re.findall(r"\[([^\]]*)\]", group[len(prefix):])
        if not path:
            continue
        js.append(f"w.currentConfigGroup = {json.dumps(path)};")
        for key, value in entries.items():
            if any(mask in value for mask in MASKS):
                skipped.append(key)
                continue
            js.append(f"w.writeConfig({js_string(key)}, {js_string(unescape(value))});")
            written += 1
    note(f"Widget settings: {written} written" + (f", left at their default (masked in the report): {', '.join(skipped)}" if skipped else ""))

    # The panel: its containment and its view in plasmashellrc.
    cont = groups.get("containment", {})
    view = groups.get(f"[PlasmaViews][Panel {containment}]", {})
    defaults = groups.get(f"[PlasmaViews][Panel {containment}][Defaults]", {})
    locations = {"3": "top", "4": "bottom", "5": "left", "6": "right"}
    panel = []
    if cont.get("plugin") != "org.kde.panel":
        note(f"The widget is in {cont.get('plugin', 'an unknown containment')}, not a panel.")
    if cont.get("location") in locations:
        panel.append(f"p.location = {js_string(locations[cont['location']])};")
    if defaults.get("thickness", "").isdigit():
        panel.append(f"p.height = {defaults['thickness']};")
    if view.get("panelLengthMode") in ("0", "1", "2"):
        panel.append(f"p.lengthMode = {js_string(['fill', 'fit', 'custom'][int(view['panelLengthMode'])])};")
    alignments = {"1": "left", "2": "right", "4": "center", "132": "center"}
    if view.get("alignment") in alignments:
        panel.append(f"p.alignment = {js_string(alignments[view['alignment']])};")
    if view.get("floating") in ("0", "1"):
        panel.append(f"p.floating = {'true' if view['floating'] == '1' else 'false'};")
    if panel:
        js.append("var p = panels()[0];")
        js.append("if (p.widgets(\"io.github.daydve.fancytasksng\").length > 0) {")
        js.extend("    " + line for line in panel)
        js.append("}")

    out_dir = Path(args.out_dir)
    (out_dir / "setup.js").write_text("\n".join(js) + "\n", encoding="utf-8")

    # The screen under the panel: Plasma numbers screens by output priority.
    outputs = sorted(parse_outputs(report.get("Displays", [])), key=lambda o: o["priority"] or 99)
    screen = ""
    if outputs:
        index = int(cont["lastScreen"]) if cont.get("lastScreen", "").isdigit() else 0
        if not any(o["priority"] for o in outputs):
            note("The report doesn't list output priorities; taking the first output.")
            index = 0
        out = outputs[min(index, len(outputs) - 1)]
        monitor = None
        if args.monitor and re.fullmatch(r"\d+x\d+", args.monitor):
            monitor = tuple(int(v) for v in args.monitor.split("x"))
        else:
            monitor = local_monitor()
        w, h = fit_screen(out["width"], out["height"], monitor)
        screen = f"{w}x{h}"
        scaled = "" if (w, h) == (out["width"], out["height"]) else f", scaled down to {screen} to fit this monitor"
        note(f"Screen: {out['name']}, {out['width']}x{out['height']} logical (scale {out['scale']}){scaled}")
    else:
        note("No displays in the report; the screen size stays as given.")
    (out_dir / "screen.txt").write_text(screen + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
