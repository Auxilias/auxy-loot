#!/usr/bin/env python3
# Findet Funktionen, die als globaler Name aufgerufen werden, obwohl die Datei sie erst später als
# „local“ definiert (dann ist der Name beim Aufruf nil – z. B. Auxy Loot 1.2: ShortName im Tooltip).
import re, subprocess, sys, glob
bad = []
for f in sorted(glob.glob(sys.argv[1] + "/*.lua")):
    src = open(f, encoding="utf-8").read()
    locals_ = set(re.findall(r"^\s*local\s+function\s+(\w+)", src, re.M))
    for m in re.finditer(r"^\s*local\s+([\w\s,]+?)\s*(?:=|$|--)", src, re.M):
        for n in m.group(1).split(","):
            n = n.strip()
            if re.fullmatch(r"\w+", n): locals_.add(n)
    out = subprocess.run(["luajit", "-bl", f], capture_output=True).stdout.decode("utf-8", "replace")
    # gewolltes Muster „local X = (C_….X) or X“: globales X absichtlich gelesen
    shadow = set(m.group(1) for m in re.finditer(r"^\s*local\s+(\w+)\s*=.*\b\1\b", src, re.M))
    shadow |= set(n for m in re.finditer(r"^\s*local\s+([\w\s,]+?)\s*=\s*([^\n]+)", src, re.M)
                  for n in [x.strip() for x in m.group(1).split(",")] if re.search(r"\b" + n + r"\b", m.group(2)))
    gets = set(re.findall(r'GGET.*; "(\w+)"', out))
    for n in sorted((gets & locals_) - shadow):
        bad.append(f"{f}: „{n}“ wird global benutzt, ist aber als local definiert (vor der Definition benutzt?)")
if bad:
    print("\n".join(bad)); sys.exit(1)
