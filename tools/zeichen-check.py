#!/usr/bin/env python3
# Prüft angezeigte Texte (Strings außerhalb von Kommentaren und Protokollzeilen) auf Zeichen,
# die die Spielschrift nicht hat (Kästchen im Spiel, z. B. „→“). Erlaubt: ASCII, Windows-1252
# (– … · » „ “ ± × é ä …) und das Minus „−“ (im Spiel geprüft, 07.11.).
import glob, re, sys
ok_extra = {"−"}
bad = []
for f in sorted(glob.glob(sys.argv[1] + "/*.lua")):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        if re.search(r"\b(ns\.Log|WLog|Log)\s*\(", line):
            continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', line):
            if "--" in line[:m.start()]:
                break  # Rest der Zeile ist Kommentar
            for ch in (m.group(1) or m.group(2) or ""):
                if ord(ch) > 127 and ch not in ok_extra:
                    try:
                        ch.encode("cp1252")
                    except UnicodeEncodeError:
                        bad.append(f"{f}:{n}: „{ch}“ (U+{ord(ch):04X})")
if bad:
    print("Zeichen, die die Spielschrift nicht kennt (» statt →):")
    print("\n".join(bad))
    sys.exit(1)
