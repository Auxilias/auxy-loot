<p align="center">
  <img src="https://raw.githubusercontent.com/Auxilias/auxy-loot/main/media/logo.png" width="110" alt="Auxy Loot Logo">
</p>

<h1 align="center">Auxy Loot</h1>

<p align="center">
  Würfelfenster für Gruppen-Loot in <b>World of Warcraft: Forever</b><br>
  <i>Roll window for group loot in World of Warcraft: Forever – <a href="#english">English below</a></i>
</p>

<p align="center">
  <a href="https://github.com/Auxilias/auxy-loot/releases/latest"><img src="https://img.shields.io/github/v/release/Auxilias/auxy-loot?label=Version&color=ffd100" alt="Version"></a>
  <img src="https://img.shields.io/badge/WoW%20Forever-1.60.1-1eff00" alt="WoW Forever 1.60.1">
  <img src="https://img.shields.io/badge/Sprache-Deutsch%20%2F%20English-lightgrey" alt="Sprache: Deutsch / English">
  <a href="https://github.com/Auxilias/auxy-loot/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Auxilias/auxy-loot?color=blue" alt="Lizenz"></a>
</p>

Blizzards Würfelfenster ist groß und zeigt nicht, wer was gewählt hat. Auxy Loot ersetzt es durch eine schmale Leiste: Item, Restzeit und die vier Knöpfe. Darunter steht, was die anderen gewählt und gewürfelt haben, und am Ende, wer das Item bekommt.

## Funktionen

- **Geht von selbst auf**, sobald gewürfelt wird. Item-Symbol, Name in Qualitätsfarbe, Restzeit als Balken.
- **Bedarf, Gier, Entzaubern, Passen.** Was gerade nicht geht, ist ausgegraut, der Tooltip sagt warum.
- **Würfe der Gruppe:** Unter jedem Item steht, wer was gewählt und gewürfelt hat. Bedarf oben, höchster Wurf zuerst, der Gewinner wird markiert. Maus über die Zeile zeigt die ganze Liste.
- **Beute der Gruppe:** kleine Liste, wer die ausgewürfelten Items bekommen hat. Verschwindet nach ein paar Sekunden.
- **Lootfilter** pro Qualität: fragen, automatisch Gier oder automatisch passen. Bei gebundenen Items (BoP) wird immer gefragt. Ab Werk ist der Filter aus.
- **Beutefenster zu:** Liegen in der Leiche nur noch Items zum Würfeln, schließt Auxy Loot das Beutefenster. Sonst nimmt WoW keine Rechtsklicks in die Welt an. Das Würfeln läuft weiter.
- **Übersteht `/reload`:** laufende Würfe, die Wahl der anderen und die Beute-Liste sind danach wieder da.
- Größe, Breite und Richtung (wächst nach unten oder oben) lassen sich einstellen.

## Installation

**Mit Wago:** [addons.wago.io/addons/auxy-loot](https://addons.wago.io/addons/auxy-loot). Neue Versionen erscheinen dort automatisch.

**Von Hand:**

1. Unter [Releases](https://github.com/Auxilias/auxy-loot/releases/latest) die `AuxyLoot.zip` herunterladen.
2. Entpacken nach `World of Warcraft\_forever_\Interface\AddOns\`. Danach liegt dort der Ordner `AuxyLoot`.
3. WoW neu starten.

Für ein Update einfach den Ordner ersetzen, die Einstellungen bleiben erhalten.

## Bedienung

Zum Ausprobieren `/auxyloot test` eingeben. Das zeigt drei Beispiel-Würfe mit erfundenen Mitspielern, gewürfelt wird dabei nicht.

| Befehl | Was passiert |
|---|---|
| `/auxyloot test` | Beispiel-Würfe anzeigen |
| `/auxyloot menü` | Einstellungen öffnen |
| `/auxyloot oben` / `unten` | Fenster wächst nach oben oder unten |
| `/auxyloot groß 1.2` | Größe (0.6 bis 2) |
| `/auxyloot blizzard` | Blizzards Würfelfenster wieder ein- oder ausblenden |
| `/auxyloot reset` | Position zurücksetzen |

Verschieben über die goldene Titelzeile. Rechtsklick auf die Titelzeile oder eine Zeile öffnet die Einstellungen.

## Gut zu wissen

- Die Oberfläche ist **Deutsch bei deutschem Client, sonst Englisch**. Die Würfe der anderen liest Auxy Loot aus Blizzards Loot-Meldungen, das klappt in jeder Sprache.
- Die Befehle gibt es deutsch und englisch (`/auxyloot oben` = `up`, `groß 1.2` = `size 1.2`).
- Auxy Loot würfelt nur dann selbst, wenn du den Lootfilter dafür einstellst.
- Fehler oder Ideen gerne als [Issue](https://github.com/Auxilias/auxy-loot/issues). Bei Lua-Fehlern hilft der Text aus BugSack.

## Änderungen

Was in welcher Version neu ist, steht im [CHANGELOG](https://github.com/Auxilias/auxy-loot/blob/main/CHANGELOG.md).

## Wie es entstanden ist

Auxy Loot ist ein Hobbyprojekt für meine Gruppe in WoW Forever. Der Code ist größtenteils mit KI geschrieben (Claude von Anthropic). Ideen, Tests im Spiel und die Entscheidung, was rein kommt, kommen von mir.

## Lizenz

MIT, siehe [LICENSE](https://github.com/Auxilias/auxy-loot/blob/main/LICENSE).

---

## English

A compact roll window for group loot in **World of Warcraft: Forever**. Blizzard's roll frame is big and doesn't show who picked what. Auxy Loot replaces it with a slim bar: item, time left and the four buttons. Below it you see what everyone else picked and rolled, and at the end who gets the item.

### Features

- **Opens by itself** as soon as a roll starts. Item icon, name in quality colour, time left as a bar.
- **Need, Greed, Disenchant, Pass.** Whatever isn't possible right now is greyed out, the tooltip says why.
- **Group rolls:** under each item you see who picked what and rolled what. Need on top, highest roll first, the winner is marked. Hover the row for the full list.
- **Group loot:** a small list of who received the items that were rolled for. Disappears after a few seconds.
- **Loot filter** per quality: ask, auto Greed or auto Pass. Bind-on-pickup items always ask. Off by default.
- **Closes the loot window:** if only roll items are left in the corpse, Auxy Loot closes the loot window. Otherwise WoW ignores right-clicks into the world. Rolling continues.
- **Survives `/reload`:** running rolls, the others' choices and the loot list are back afterwards.
- Size, width and direction (grows down or up) are adjustable.

### Installation

**With Wago:** [addons.wago.io/addons/auxy-loot](https://addons.wago.io/addons/auxy-loot). New versions appear there automatically.

**Manually:**

1. Download `AuxyLoot.zip` from [Releases](https://github.com/Auxilias/auxy-loot/releases/latest).
2. Unpack it to `World of Warcraft\_forever_\Interface\AddOns\`. You then have a folder `AuxyLoot` there.
3. Restart WoW.

To update, just replace the folder; your settings are kept.

### Usage

Type `/auxyloot test` to try it. It shows three example rolls with made-up players; nothing is rolled.

| Command | What it does |
|---|---|
| `/auxyloot test` | show example rolls |
| `/auxyloot menu` | open settings |
| `/auxyloot up` / `down` | window grows up or down |
| `/auxyloot size 1.2` | size (0.6 to 2) |
| `/auxyloot blizzard` | show or hide Blizzard's roll window again |
| `/auxyloot reset` | reset position |

Move it by dragging the golden title bar. Right-click the title bar or a row to open the settings.

### Good to know

- The interface is **German on German clients and English on all others**. Auxy Loot reads the others' rolls from Blizzard's loot messages, which works in every language.
- All commands work in German and English (`/auxyloot oben` = `up`, `groß 1.2` = `size 1.2`, `menü` = `menu`).
- Auxy Loot only rolls by itself if you set up the loot filter for it.
- Bugs or ideas are welcome as an [issue](https://github.com/Auxilias/auxy-loot/issues). For Lua errors, the text from BugSack helps.

### Changes

What's new in which version is listed in the [CHANGELOG](https://github.com/Auxilias/auxy-loot/blob/main/CHANGELOG.md).

### How it was made

Auxy Loot is a hobby project for my group in WoW Forever. The code is largely written with AI (Claude by Anthropic). Ideas, in-game testing and deciding what goes in come from me.

### License

MIT, see [LICENSE](https://github.com/Auxilias/auxy-loot/blob/main/LICENSE).
