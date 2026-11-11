#!/usr/bin/env python3
"""Clean-room check for behaviour specs (spec side only; see docs/REWRITE_PLAN.md).

Flags anything in the specs that comes from DynamicNotch:
  * identifiers declared in its Swift sources (camelCase / PascalCase names),
  * dotted string literals such as preference keys,
  * English UI strings of four or more words from its string catalog or Swift literals,
  * Swift-looking code lines.

Usage:
  git -C <upstream clone> archive HEAD DynamicNotch | tar -x -C <dir>
  python3 -I scripts/spec-leak-check.py <dir> docs/specs
Exit status 1 when anything is flagged.
"""
import json
import os
import re
import sys

DECL = re.compile(r"\b(?:class|struct|enum|protocol|actor|extension|func|var|let|case|typealias)\s+"
                  r"([A-Za-z_][A-Za-z0-9_]*)")
CASE_LIST = re.compile(r"\bcase\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)+)")
DOTTED = re.compile(r'"([A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+)"')
HUMP = re.compile(r"[a-z0-9][A-Z]")
CODE = re.compile(r"^\s*(?:func |let |var |guard |if let |import |@objc|@State|@Published|\}\s*$|.*\)\s*\{\s*$)")
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def upstream_vocabulary(root):
    names, keys, phrases = set(), set(), set()
    for folder, _, files in os.walk(root):
        for name in files:
            path = os.path.join(folder, name)
            if name.endswith(".swift"):
                text = open(path, encoding="utf-8", errors="ignore").read()
                found = DECL.findall(text)
                for group in CASE_LIST.findall(text):
                    found += [part.strip() for part in group.split(",")]
                names.update(n for n in found if HUMP.search(n) and len(n) >= 5)
                names.add(name[:-6])
                keys.update(k for k in DOTTED.findall(text) if not k.startswith(("com.apple", "NS")))
                phrases.update(s.strip().lower() for s in STRING.findall(text)
                               if len(s.split()) >= 4 and "\\(" not in s)
            elif name == "Localizable.xcstrings":
                catalog = json.load(open(path, encoding="utf-8"))
                for key, entry in catalog.get("strings", {}).items():
                    value = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", key)
                    for candidate in (key, value):
                        if len(candidate.split()) >= 4:
                            phrases.add(candidate.strip().lower())
    return names, keys, phrases


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    names, keys, phrases = upstream_vocabulary(sys.argv[1])
    flagged = 0
    for folder, _, files in os.walk(sys.argv[2]):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(folder, name)
            lines = open(path, encoding="utf-8").read().splitlines()
            for number, line in enumerate(lines, 1):
                hits = sorted({w for w in WORD.findall(line) if w in names})
                hits += [k for k in keys if k in line]
                lowered = line.lower()
                hits += [f'"{p}"' for p in phrases if p in lowered]
                if CODE.match(line):
                    hits.append("<code-like line>")
                if hits:
                    flagged += 1
                    print(f"{path}:{number}: {', '.join(hits)}")
    print(f"{flagged} flagged line(s); vocabulary: {len(names)} names, {len(keys)} keys, {len(phrases)} phrases")
    sys.exit(1 if flagged else 0)


if __name__ == "__main__":
    main()
