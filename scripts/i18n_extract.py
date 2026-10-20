#!/usr/bin/env python3
"""Collects every translatable text and updates locale/strings.csv.

Keys are the Portuguese source texts: I18n.t("...") calls in src/, the help text,
key-binding labels, direction and status names, and the name/desc/text/title
fields of data/*.json. Existing translations are kept; new keys get empty
columns and are listed so they can be translated. Run after changing texts:

    python3 scripts/i18n_extract.py
"""
import csv
import glob
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV = ROOT / "locale" / "strings.csv"
LANGS = ["en", "es"]
FIELDS = ["name", "short", "desc", "text", "title"]


def unescape(s: str) -> str:
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(m.group(1), m.group(0)), s)


def code_keys() -> list:
    keys = []
    call = re.compile(r'I18n\.t\("((?:[^"\\]|\\.)*)"\)')
    for f in sorted(glob.glob(str(ROOT / "src" / "**" / "*.gd"), recursive=True)):
        src = Path(f).read_text()
        keys += [unescape(k) for k in call.findall(src)]
        m = re.search(r'const HELP_TEXT := """(.*?)"""', src, re.S)
        if m:
            keys.append(m.group(1))
        m = re.search(r'const LANGS := \[\["", "([^"]+)"\]', src)
        if m:
            keys.append(m.group(1))
        m = re.search(r'const ACTIONS := \[(.*?)\n\]', src, re.S)
        if m:
            keys += re.findall(r'\["\w+", "([^"]+)"', m.group(1))
        m = re.search(r'const DIR_NAMES := \[(.*?)\]', src)
        if m:
            keys += re.findall(r'"([^"]+)"', m.group(1))
        # Status values shown in the HUD (assigned in the simulation).
        for line in src.splitlines():
            if re.search(r'\bstatus\s*=', line):
                keys += re.findall(r'(?:status\s*=|else)\s*"([^"]+)"(?!\))', line)
                keys += re.findall(r'=\s*"([^"]+)"\s+if\b', line)
        m = re.search(r'STATUS_LEVEL := \{(.*?)\}', src, re.S)
        if m:
            keys += re.findall(r'"([^"]+)"\s*:', m.group(1))
    return keys


def data_keys() -> list:
    keys = []

    def walk(v):
        if isinstance(v, dict):
            for k, x in v.items():
                if k in FIELDS and isinstance(x, str):
                    keys.append(x)
                else:
                    walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    for f in sorted(glob.glob(str(ROOT / "data" / "*.json"))):
        walk(json.loads(Path(f).read_text()))
    return keys


def main() -> None:
    old = {}
    if CSV.exists():
        with open(CSV, newline="") as fh:
            for row in csv.DictReader(fh):
                old[row["keys"]] = row
    keys = []
    for k in code_keys() + data_keys():
        if k and k not in keys:
            keys.append(k)
    CSV.parent.mkdir(exist_ok=True)
    missing = 0
    with open(CSV, "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["keys"] + LANGS)
        for k in keys:
            row = old.get(k, {})
            vals = [row.get(lang, "") for lang in LANGS]
            missing += sum(1 for v in vals if not v)
            w.writerow([k] + vals)
    print("%d textos, %d traduções faltando -> %s" % (len(keys), missing, CSV.relative_to(ROOT)))


if __name__ == "__main__":
    main()
