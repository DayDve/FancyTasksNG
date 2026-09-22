#!/usr/bin/env python3
"""
Distill a CHANGELOG.md release section into a short, user-facing changelog
for the store.kde.org listing, using Gemini.

GitHub Release notes keep the full technical changelog (developer audience);
store.kde.org visitors just want "what changed for me", so this drops
internal refactoring/cleanup noise and keeps only user-visible changes.
Gemini is given the whole CHANGELOG.md plus the target version and finds the
right section itself - no separate section-extraction step needed.

temperature=0 for the most reproducible output the API allows (LLM APIs
don't guarantee byte-identical output even at temperature 0, but this is
the practical ceiling for "same input in, same output out").

Requires:
  GEMINI_API_KEY - Gemini API key

Usage:
  generate_kde_changelog.py --changelog-file CHANGELOG.md --version 2.1.0
"""

import os
import sys
import time
import argparse
import requests

MODEL = "gemini-2.5-flash"
API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

PROMPT = """You are writing the changelog entry for a KDE Plasma widget's page on store.kde.org. Your audience is end users deciding whether to update, not developers. The changelog editor supports Markdown (headings, bold, italic, lists, links, inline code).

Below is the project's full CHANGELOG.md (Keep a Changelog format). Find the section for version {version} (heading "## [{version}]") and rewrite ONLY that section into a short, plain-language summary:
- Include only user-visible changes: new features, fixed bugs, visible behavior changes.
- Omit internal refactoring, code cleanup, dead code removal, and any other change with no direct user-facing effect.
- Format as Markdown: a "### What's new" and/or "### Fixed" heading as applicable (skip a section if it would be empty), each followed by a "-" bullet list.
- One sentence per bullet, plain prose. Bold or inline code are fine when naming a specific setting/button, but don't overuse them.
- Drop issue/PR numbers.
- Keep contributor credits ("thanks to @X") if present, rewritten naturally into the sentence.
- Do not add anything not present in that section, and do not summarize any other version's section.
- Output only the resulting changelog text - no preamble, no explanation, no surrounding quotes.

CHANGELOG.md:
---
{changelog}
---
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--changelog-file', required=True, help="Path to CHANGELOG.md")
    parser.add_argument('--version', required=True, help="Version to summarize, e.g. 2.1.0")
    args = parser.parse_args()

    changelog = open(args.changelog_file, 'r', encoding='utf-8').read()
    if not changelog.strip():
        print("Error: empty changelog file.", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set.", file=sys.stderr)
        sys.exit(1)

    payload = {
        "contents": [{"parts": [{"text": PROMPT.format(version=args.version, changelog=changelog.strip())}]}],
        "generationConfig": {"temperature": 0, "topP": 1, "topK": 1},
    }

    # Gemini 3.x is prone to transient 503 UNAVAILABLE under high demand;
    # retry with backoff, as Google's own client libraries do by default.
    max_attempts = 4
    delay = 1
    for attempt in range(1, max_attempts + 1):
        res = requests.post(f"{API_URL}?key={api_key}", json=payload, timeout=60)
        if res.status_code != 503 or attempt == max_attempts:
            break
        print(f"Gemini returned 503 (attempt {attempt}/{max_attempts}), retrying in {delay}s...", file=sys.stderr)
        time.sleep(delay)
        delay *= 2
    res.raise_for_status()
    data = res.json()

    try:
        text = data['candidates'][0]['content']['parts'][0]['text']
    except (KeyError, IndexError):
        print(f"Error: unexpected Gemini response: {data}", file=sys.stderr)
        sys.exit(1)

    print(text.strip())


if __name__ == '__main__':
    main()
