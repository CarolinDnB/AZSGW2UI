# AZS GW2 UI: Changelog

## 1.8.0

**New**
- **Party menu:** right click a party frame for a small menu: Inspect, Trade, Follow, Whisper (the party leader also gets Make leader / Remove). If something can't work, the chat says why (for example "too far away to inspect").
- **Friendly targets have a health bar.** It is the same bar as for enemies, in green, with a class-coloured name ("Downed" when down).
- **Party tab on the damage meter** shows each player's best spell as an icon, left of the name, like the other tabs.

**Changed**
- The yellow timer bar under boss and guardian rows is gone. The rows are shorter.
- The party barrier (shield) is now a real overlay on top of the health bar, with a bright top edge. The percent text stays above it.

**Fixed**
- Inspect did not work. The game's drop-down menu is no longer used; the new menu calls Inspect directly.

**Performance** (for the FPS reports)
- The health orb, skill bar, health bars, party frames, minimap pins and damage numbers now only update what actually changed. In the test setup an idle frame went from 91 to 36 game calls, and from about 23 KB to 11 KB of garbage.
- The 10 second DPS is worked out inside the addon, so the meter no longer asks the game for it all the time.

## 1.7.0

**New**
- **Reset button** on the damage meter. It restarts all four tabs from zero.
- **10s DPS / 10s HPS:** the meter now shows the last 10 seconds instead of the whole run.
- **Click a party frame to target that friend.** A white outline marks your target. A waiting spell or an item on your cursor goes to the friend.
- **Skill bar tooltips:** hover a skill to see the game's own spell tooltip, with the cooldown left.
- **CDR** (cooldown reduction) is shown as a percent, like `CDR 38%`.

**Changed**
- The hero panel opens at the left edge of the screen. You can still drag it anywhere.
- Heroic affixes sit at the right end of the line under the run bar.

**Fixed**
- The red blot behind a critical hit now grows with the number, so 1000 or 98765 fits as well as 10 does.
- Affixes overlapped the run timer.
- Cooldown reduction showed as `x0.62` instead of a percent.

## 1.6.0 and earlier

- Barrier on party frames, guardian list, bigger damage numbers, luck and crit stats as percent, hero panel with all gear, difficulty and affixes on the run bar, ally-down alert, damage number options, release hardening (safe saved variables, bounded memory, error recovery).

## Good to know

- The game only reports the shield amount for your own hero. For friends the barrier is read from their health above the maximum, or from a shield buff on them. `/gw2 party` shows what the game tells the addon.
- All of this was tested in a simulated game client, not in the real game. If something looks wrong in game, `/gw2 debug` and a screenshot help most.
