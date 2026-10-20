#!/usr/bin/env python3
"""Fills translations in locale/strings.csv from a JSON file of
{"<Portuguese key>": ["<English>", "<Spanish>"]} (helper for translators):

    python3 scripts/i18n_fill.py novas.json
"""
import csv
import json
import sys
from pathlib import Path

CSV = Path(__file__).resolve().parent.parent / "locale" / "strings.csv"


def main() -> None:
    new = json.loads(Path(sys.argv[1]).read_text())
    rows = list(csv.DictReader(open(CSV, newline="")))
    known = {r["keys"] for r in rows}
    for k in new:
        if k not in known:
            print("chave inexistente (rode i18n_extract.py antes):", k[:70])
    for r in rows:
        if r["keys"] in new:
            r["en"], r["es"] = new[r["keys"]]
    with open(CSV, "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["keys", "en", "es"])
        for r in rows:
            w.writerow([r["keys"], r["en"], r["es"]])
    print("faltando:", sum(1 for r in rows if not r["en"] or not r["es"]))


if __name__ == "__main__":
    main()
