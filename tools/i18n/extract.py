"""Collects every player-facing English string into locale/_template.json.

Run from the repo root:  python tools/i18n/extract.py
Sources: tr("...") literals in scripts/*.gd, content text in scripts/data.gd, and EXTRA
(strings that reach tr() through a variable). Translators fill locale/<code>.json with the same keys.
"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
EXTRA = [
    "The Dawn Remembers You", "You Retreat Into the Dark", "Your Light Fades",
    "Survived", "Enemies", "Level", "Embers", "Resume", "Settings", "Abandon Run",
    "General", "Audio", "Video", "Controls", "Low", "Medium", "High", "Auto",
    "The Long Night", "Dawn", "Dawn Breaks",
    "Move Up", "Move Down", "Move Left", "Move Right", "Dash", "Pause", "Reroll",
    "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right",
]
STR = r'"((?:[^"\\]|\\.)*)"'


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


keys = set(EXTRA)
for f in (ROOT / "scripts").glob("*.gd"):
    src = f.read_text(encoding="utf-8")
    for m in re.finditer(r'\btr\(' + STR + r'\)', src):
        keys.add(unescape(m.group(1)))
data = (ROOT / "scripts" / "data.gd").read_text(encoding="utf-8")
for m in re.finditer(STR, data):
    s = unescape(m.group(1))
    if len(s) < 3 or s.startswith("ACH_") or re.fullmatch(r"[0-9a-fA-F]{6}", s):
        continue
    if re.fullmatch(r"[a-z_0-9]+", s):  # ids and dictionary keys
        continue
    keys.add(s)
out = {k: "" for k in sorted(keys)}
path = ROOT / "locale" / "_template.json"
path.parent.mkdir(exist_ok=True)
path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(len(out), "strings ->", path)
