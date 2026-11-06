# AZS GW2 UI: Changelog

## 1.9.1

**Changed**
- **Friendly nameplates: "hide totems"** replaces "show totems" (settings, and `/gw2 plates hidetotems on | off`). It is the same setting as before, so an earlier choice carries over. Totems are now recognised more reliably: a rank after the name, any capital letters, other languages, and the names in the API's list of your totems. `/gw2 plates debug` lists what each plate is taken for (enemy, neutral, hero, totem or pet) and whether it is drawn, so a plate that is taken for the wrong thing can be reported.

**Fixed**
- **No tooltip on pet abilities** (Kill Command, Demonic Empowerment). They are now looked up in the pet's own spellbook too, and by their name when the loadout does not give one. If the game has no text for a spell, the skill shows its own tooltip (name, rank, cooldown) instead of nothing.
- **The "Ready in" time on a skill's tooltip did not move** while you hovered the skill. It counts down now, and the line goes when the skill is ready.
- **`/gw2 off` hid your abilities.** The game's own HUD parts were given back but the settings behind them (the ones this UI forces to "hidden") were not, so the spells row stayed off. They are all given back now and watched for a few seconds, and the game's own action bar comes back even when it was not up the moment this UI first took it.
- **Skills flashed when they were ready but could not be used** (nothing in range). The game puts a moment of cooldown on a skill each time it tries and fails; a very short cooldown on a skill that was ready is now taken for a failed try and not drawn, and a cooldown with less than 0.3 seconds left is not drawn at all. A real cooldown still shows the moment the skill goes off.
- **No tooltip on Rockbiter Weapon** (a skill whose key is a shortened spell name: `rockbiter`). The spellbook lookup took only exact names; it now also takes a name that is the first words of a spell's name, in your spellbook and your pet's, so the game's own tooltip with the description shows. `/gw2 focus` on a skill says where its spell was found, or which spells look like it.
- **New: `/gw2 version`** says which version is installed.
- **A buff without a tooltip** (a buff with no text of its own) now shows its name, the time left and the stacks when the game has no text for it. The name comes from the loadout (by the icon) or from the icon's file name. Every tooltip of ours that would come out empty gets such a fallback, and `/gw2 focus` (point at the thing, then type it) says what is under the mouse and whether it is ours, for a thing that still has none.
- **The game's own skill bars were empty after `/gw2 off` in a run** (only skills gained later showed). The bars are now switched off and on again once more half a second and two and a half seconds after `/gw2 off`, as the checkbox in the game's options does. If they are still empty, `/reload` makes the game draw them, and `/gw2 rows` shows whether the game has drawn any skill icons.
- **Lower cost** (frame rate): the skills' tooltips were read again about 4 times a second for as long as you were casting (every cooldown change counted as an upgrade); now only when the skills, their ranks or your stats change, and as a safety net every 10 seconds. The boss and guardian bars, the run bar, the buff row and the summon row only touch the game's widgets when what they show has changed (boss bars: about 5 times fewer calls). A tooltip that counts down no longer searches the spellbook each time it is drawn.
- **Health bars of guardians and bosses stayed up in the next run** when a run ended while they were alive. The game keeps its last list until new data arrives; lists older than the current run are not shown now (also for the nameplates' elite filter and the target bar).

## 1.9.0

**New**
- **Nameplates in the Guild Wars 2 style.** A small glossy red bar (no name: that is on the target bar), the health inside for your target, a white outline on the target's plate, a crown (elite) or skull (boss) mark. Settings: *Enable nameplates*, *only elites and guardians*, *Enable friendly nameplates* (also `/gw2 plates ...`). They are off by default. The game's own V key for nameplates now works as usual: it used to be undone after about half a second.
- **New target bar** in the style of Guild Wars 2: a wide flat bar, glossy fill, dark frame, name left and health with percent right, a round badge at the right end (crown for elites, small skull otherwise). Orange for elites and guardians, green for friends.
- **Max targets:** a small round number on top of a skill says how many enemies it can hit at most, with the +targets from upgrades and cards in it (Multi-Shot: 5). It is read from the game's tooltip of the skill (shown for a moment without being drawn, only while no other tooltip is up, and read again whenever you point at the skill, which is exact), so you do not need enemies near. More wordings are understood ("Targets: 5", "5 nearest enemies", "your target and 2 other enemies", numbers written out), and "+N target" bonus lines are never counted twice. It follows a card within a few seconds (Aimed Shot 4 -> 6). It shows from 2 on. *Max targets, on the skills* turns it off; `/gw2 targets` shows what was read.
- **Marks:** when you target a boss, it gets the game's skull; a guardian gets the cross. A boss you point at is marked too. A mark that is already there is not changed. *Mark bosses and guardians* (or `/gw2 marks on | off`). The marks show above the bar on the nameplates.
- **Friendly nameplates: pets and totems are your choice.** *show pets and summons* and *show totems* (both on by default; `/gw2 plates pets on | off`, `/gw2 plates totems on | off`). Heroes always show.
- **Resize every part on its own** in the unlocked layout: drag the corner of a gold box or use the mouse wheel; right click puts the size back. The box shows its size. A bar at the top of the screen locks the layout again. "Size" in the settings still changes everything at once.

**Changed**
- Elites and guardians have an orange bar (nameplates and target bar), so they stand out from the red enemies.
- Parts that belong together (the orb and the skill bar around it, for example) resize together so they keep fitting.

**Removed**
- The right click on the minimap icon. It left you in the unlocked layout with no clear way out. Left click opens the settings, "Unlock layout" is in there.
- The talent proc / "recharging" icons above the left skills: they showed empty icons (and nothing for Hot Streak).

**Fixed**
- **"Only elites and guardians" did not work.** It now goes by the API's list of special enemies (elites, guardians, bosses) instead of the game's plate icon, so guardians and bosses are found and ordinary enemies are not mistaken for them.
- **Two health bars on a nameplate** (the game's own bar showed next to ours after a while). The addon now looks at every plate again and hides the game's bar whenever it comes back, and the cast bar the game adds later. If it still happens, `/gw2 plates debug` lists the parts of two plates.
- **The 10 second DPS stopped after about 20 seconds on pet builds** and only came back after a reset. It now asks the game's meter API for the recent rate (pets, summons and totems included) and, if the game cannot answer, works it out itself without starting over when a line drops out of the list.

**Notes**
- The nameplate skin depends on the game's plate frames looking like those of the standard 1.12 client. If they do not, nothing is hidden and the game's plates show as before; `/gw2 plates debug` prints what the addon finds.

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
