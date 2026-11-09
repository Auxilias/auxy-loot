#!/usr/bin/env bash
# Auxy Loot veröffentlichen (GitHub-Release; Wago holt es selbst, CurseForge über die Action).
#   ./publish.sh              nur Tests + Zip bauen (nichts wird veröffentlicht)
#   ./publish.sh 1.4 "Text"   Version in der TOC setzen, CHANGELOG, committen, pushen, Release mit Zip
set -e
cd "$(dirname "$0")"
VER="$1"; NOTES="${2:-Neue Version.}"
if [ -n "$VER" ]; then sed -i "s/^## Version: .*/## Version: $VER/" AuxyLoot/AuxyLoot.toc; fi
./test.sh
ZIP="$(mktemp -d)/AuxyLoot.zip"; trap 'rm -rf "$(dirname "$ZIP")"' EXIT
bsdtar --format zip -cf "$ZIP" --exclude '*.bak' AuxyLoot
[ -z "$VER" ] && { echo "Zip gebaut und Tests grün (nicht veröffentlicht). Mit Version aufrufen, um zu veröffentlichen."; exit 0; }
python3 -I - "$VER" "$NOTES" <<'PY'
import sys
ver, notes = sys.argv[1], sys.argv[2]
p = "CHANGELOG.md"; s = open(p, encoding="utf-8").read()
if f"## {ver}\n" not in s:
    s = s.replace("# Änderungen\n\n", f"# Änderungen\n\n## {ver}\n- {notes}\n\n", 1)
    open(p, "w", encoding="utf-8").write(s)
PY
git add -A
git commit -q -m "Auxy Loot $VER

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -c credential.helper= -c credential.helper='!gh auth git-credential' push -q
gh release create "v$VER" "$ZIP" --repo Auxilias/auxy-loot --title "Auxy Loot $VER" --notes "$NOTES"
echo "Veröffentlicht: https://github.com/Auxilias/auxy-loot/releases/tag/v$VER"
