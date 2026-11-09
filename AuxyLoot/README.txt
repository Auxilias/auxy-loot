Auxy Loot - roll window for group loot in WoW Forever
(Deutsch: siehe LIESMICH.txt)

Install
  Copy the folder "AuxyLoot" (from the zip) to
  World of Warcraft\_forever_\Interface\AddOns\
  then restart WoW.
  Or via Wago: https://addons.wago.io/addons/auxy-loot

What it does
  As soon as a roll starts, a slim window opens: item icon, name,
  time left and the buttons Need, Greed, Disenchant, Pass. Whatever is
  not possible right now is greyed out.
  Under each item you see what the others picked and rolled
  (Need on top, highest roll first). The winner is marked at the end.
  Hover the row to see the whole list.
  "Group loot" briefly shows who received the items that were rolled for.
  If only roll items are left in the corpse, the loot window closes.
  Otherwise WoW ignores right-clicks into the world.
  After /reload everything is back.

Settings (right-click the title bar or /auxyloot menu)
  - direction (grows down or up), width, size
  - hide a row after your choice, how long the winner stays visible
  - other players' rolls on/off and how many rows
  - close the loot window automatically
  - group loot: on/off, rolled items only, your own loot,
    minimum quality, display time
  - loot filter per quality: ask, auto Greed or auto Pass.
    Bind-on-pickup items always ask. Off by default.

Language
  The interface is German on German clients and English on all others.
  Commands work in both languages.

Commands
  /auxyloot test       three example rolls (nothing is rolled)
  /auxyloot menu       settings
  /auxyloot up|down    direction
  /auxyloot size 1.2   size (0.6 to 2)
  /auxyloot blizzard   show/hide Blizzard's roll window again
  /auxyloot reset      reset position
  Move: drag the golden title bar.

Bugs and ideas: https://github.com/Auxilias/auxy-loot/issues
The code is largely written with AI (Claude by Anthropic) and tested
in game. License: MIT, see LICENSE.
