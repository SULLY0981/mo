"""Checks locale/<code>.json files against locale/_template.json.

Run from the repo root:  python tools/i18n/validate.py
Reports missing keys, extra keys, and placeholders (%d %s %.2f %%) that differ in count or ORDER
(GDScript's % operator is positional, so translations must keep the same sequence).
Exit code 1 if anything is wrong.
"""
import json, re, sys, pathlib
sys.stdout.reconfigure(encoding="utf-8")  # Windows consoles default to cp1252

ROOT = pathlib.Path(__file__).resolve().parents[2]
PH = re.compile(r"%(?:\.\d+)?[dsf%]")
tpl = json.loads((ROOT / "locale" / "_template.json").read_text(encoding="utf-8"))
bad = 0
for f in sorted((ROOT / "locale").glob("*.json")):
    if f.name.startswith("_"):
        continue
    try:
        d = json.loads(f.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"{f.name}: INVALID JSON: {e}")
        bad += 1
        continue
    missing = [k for k in tpl if not d.get(k)]
    extra = [k for k in d if k not in tpl and not k.startswith("_")]
    ph = [k for k in tpl if d.get(k) and PH.findall(k) != PH.findall(d[k])]
    status = "ok" if not (missing or extra or ph) else "PROBLEMS"
    print(f"{f.name}: {len(d)} entries, {len(missing)} missing, {len(extra)} extra, {len(ph)} placeholder mismatches -> {status}")
    for k in ph[:10]:
        print(f"   placeholder: {k!r} -> {d[k]!r}")
    for k in missing[:5]:
        print(f"   missing: {k!r}")
    for k in extra[:5]:
        print(f"   extra: {k!r}")
    bad += bool(missing or extra or ph)
sys.exit(1 if bad else 0)
