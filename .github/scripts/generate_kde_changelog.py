#!/usr/bin/env python3
"""
Distill a CHANGELOG.md release section into a short, user-facing changelog
for the store.kde.org listing, using Gemini.

GitHub Release notes keep the full technical changelog (developer audience);
store.kde.org visitors just want "what changed for me", so this drops
internal refactoring/cleanup noise and keeps only user-visible changes.

temperature=0 for the most reproducible output the API allows (LLM APIs
don't guarantee byte-identical output even at temperature 0, but this is
the practical ceiling for "same input in, same output out").

Requires:
  GEMINI_API_KEY - Gemini API key

Usage:
  generate_kde_changelog.py --file release_notes.txt
  cat release_notes.txt | generate_kde_changelog.py
"""

import os
import sys
import argparse
import requests

MODEL = "gemini-2.5-flash"
API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

PROMPT = """You are writing the changelog entry for a KDE Plasma widget's page on store.kde.org. Your audience is end users deciding whether to update, not developers.

Rewrite the changelog below into a short, plain-language summary:
- Include only user-visible changes: new features, fixed bugs, visible behavior changes.
- Omit internal refactoring, code cleanup, dead code removal, and any other change with no direct user-facing effect.
- Group into "What's new" and "Fixed" sections as applicable (skip a section if it would be empty), each a short bullet list.
- One sentence per bullet, plain prose, no markdown headers, no backticks/code formatting, no issue/PR numbers.
- Keep contributor credits ("thanks to @X") if present, rewritten naturally into the sentence.
- Do not add anything not present in the source changelog below.
- Output only the resulting changelog text - no preamble, no explanation, no surrounding quotes.

Source changelog:
---
{changelog}
---
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--file', help="Path to the changelog section to summarize (default: stdin)")
    args = parser.parse_args()

    changelog = open(args.file, 'r', encoding='utf-8').read() if args.file else sys.stdin.read()
    if not changelog.strip():
        print("Error: empty changelog input.", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set.", file=sys.stderr)
        sys.exit(1)

    payload = {
        "contents": [{"parts": [{"text": PROMPT.format(changelog=changelog.strip())}]}],
        "generationConfig": {"temperature": 0, "topP": 1, "topK": 1},
    }
    res = requests.post(f"{API_URL}?key={api_key}", json=payload, timeout=60)
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
