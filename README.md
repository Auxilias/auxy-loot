# Auxy Loot

Kleines, dezentes Würfelfenster für **WoW Forever** (Gruppen-Loot).

- Öffnet sich von selbst, sobald ein Item zum Würfeln auftaucht – Symbol, Name in Qualitätsfarbe, Restzeit als feiner Balken
- Knöpfe **Bedarf / Gier / Entzaubern / Passen**; was nicht geht, ist gedimmt (Grund im Tooltip)
- Zeigt, was die anderen wählen und würfeln (B/G/E/P + Zahl), am Ende den **Gewinner**; Maus über die Zeile = komplette Liste
- Blizzards eigenes Würfelfenster wird ausgeblendet (abschaltbar)
- **Lootfilter:** je Qualität fragen, automatisch Gier oder automatisch passen – gebundene Items (BoP) fragt es immer
- Wächst nach unten oder oben, Breite und Größe einstellbar, Zeile nach der Wahl optional ausblenden

## Installieren

1. Unter [Releases](../../releases) die neueste `AuxyLoot.zip` herunterladen.
2. Den Ordner `AuxyLoot` nach `World of Warcraft\_forever_\Interface\AddOns\` entpacken.
3. WoW neu starten.

## Bedienen

| Befehl | |
|---|---|
| `/auxyloot` oder `/auxyloot test` | drei Beispiel-Würfe mit Beispiel-Mitspielern (würfelt nicht wirklich) |
| `/auxyloot menü` | Einstellungen (auch: Rechtsklick auf die goldene Titelzeile) |
| `/auxyloot oben` / `unten` | Wachstumsrichtung |
| `/auxyloot groß 1.2` | Größe (0.6–2) |
| `/auxyloot blizzard` | Blizzards Würfelfenster wieder an/aus |
| `/auxyloot reset` | Position zurücksetzen |

Verschieben: goldene Titelzeile ziehen.

## Hinweise

- Kostenlos, Code offen und lesbar, keine Werbung (Blizzards Addon-Regeln). Automatisch würfelt nur der Lootfilter, wenn du ihn einstellst.
- Die Würfe der anderen liest Auxy Loot aus Blizzards Loot-Meldungen im Chat (jede Sprache).
- Auxy Loot ist auch Teil der privaten „Auxy UI Suite“; ist beides installiert, arbeitet nur dieses Addon.

## Lizenz

MIT – siehe [LICENSE](LICENSE). Eigener Code, keine fremden Teile.

---

*English:* A small group-loot roll window for WoW: Forever. Opens automatically on a roll, shows Need/Greed/Disenchant/Pass buttons, the other players' choices and rolls, and the winner. Optional loot filter per quality (never for bind-on-pickup items). Commands: `/auxyloot`. UI texts are German. MIT license.
