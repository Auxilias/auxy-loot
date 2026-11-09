#!/usr/bin/env bash
# Kopiert Auxy Loot ins Spiel (nur bei geschlossenem WoW). Vorher laufen die Tests.
set -e
cd "$(dirname "$0")"
ZIEL="$HOME/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AuxyLoot"
if pgrep -f "[W]ow\.exe" >/dev/null; then echo "WoW läuft noch – bitte erst beenden (oder Dateien von Hand kopieren)."; exit 1; fi
./test.sh
mkdir -p "$ZIEL"
cp AuxyLoot/AuxyLoot.lua AuxyLoot/AuxyLoot.toc AuxyLoot/LIESMICH.txt AuxyLoot/LICENSE "$ZIEL/"
echo "Installiert nach: $ZIEL"
