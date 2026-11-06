# AZS - Guild Wars 2 UI

A Guild Wars 2 style interface for Azeroth Survivors (WoW 1.12 client, `## Interface: 11200`): health orb, skill bar,
square minimap, boss and guardian trackers, floating damage numbers, party frames, a hero panel and more.
All art is drawn from scratch (generated textures, see `tools/` in the GitHub repository); nothing is copied from
ArenaNet. It only reads what the Azeroth Survivors addon API gives it and never sends anything anywhere.

## Install

- Download `AZSGW2UI.zip` from the **Releases** page of the GitHub repository (or install it from SurvivorsForge).
  Do not use the green *Code -> Download ZIP* button or the "Source code" files on a release: their folder has the wrong name
  and the game will not load it. Only `AZSGW2UI.zip` has the addon folder named `AZSGW2UI`.
- Browser build: Options -> AddOns -> install `AZSGW2UI.zip`.
- Windows / Linux: unzip so you have `benilla-config/AddOns/AZSGW2UI/AZSGW2UI.toc`.

Restart the game once (new texture files are only read at start), then enter a world.
`/gw2 off` gives the game's own HUD back at any time, `/gw2 on` uses this UI again.

## What you get

| Part | Source |
|---|---|
| Health orb: only your HP number, centered; the barrier (absorb shield) is a gold layer | `AZS_RUN` hp / sh |
| Experience: two curved yellow arcs that follow the top of the orb (left arc fills first, then the right one: clockwise), level badge between them | `AZS_RUN` xp / xpn |
| Resource bar under the orb (rage, combo points, soul shards, Lightwell) | `AZS_RUN` |
| Skill bar: 3 big slots on each side of the orb on a soft dark smoke, the round chip at the bottom of a slot is the skill's rank (no flashing), the red-ringed one at the top says how many enemies the skill can hit at most, upgrades and cards included (only shown from 2 on; read from the skill's own tooltip, so it is there without any enemy near). The racial sits left of the left three, Talents and Character are two small buttons right of the right three | `AZS_SPELLS`, key bindings |
| Jewelry plate, buffs / debuffs above the right slots, summons / totems above the left ones | meter API loadout, `GetPlayerBuff*`, `AZS_Get*` |
| Square GW2 minimap: zone plate with local time, zoom buttons and mouse wheel, a golden arrow for you (it turns with the hero), pins for caches, guardian lairs (asleep / awake / empty) and downed friends; far pins stick to the edge | the game's Minimap frame, `AZS_CHESTS`, `AZS_GetLairs`, `AZS_GetPlayerPosition` |
| Guardian list under the minimap: a skull per guardian, a direction arrow for each and a big one in the header for the nearest | `AZS_GetLairs`, `AZS_GetPlayerPosition` |
| Boss and guardian bars like the GW2 objective tracker: a red skull, crown and name per enemy, framed debuff icons, a red HP bar with the percentage. With more than one enemy a slim title ("Bosses", "Guardians") sits above them | `AZS_GetBosses`, `AZS_GetGuardians` |
| Run bar with the difficulty: `NORMAL`, or `HEROIC I` to `HEROIC V` in orange, the affixes (Bolstering, Sanguine, Explosive) at the right end of the line under the bar | `AZS_ZONE` heroic / affixes |
| Kills / gold / cache strip with the kills per minute as `[18/m]` (tooltip: run average and last minute) | `AZS_RUN`, run clock |
| GW2 damage numbers: small white numbers with a thin dark outline, bigger ones with a red blot behind them for crits, smaller for damage-over-time ticks and pets, grey words for misses; they follow the enemy and shrink with distance. All numbers, only crits or none; ticks on or off | world-anchored combat text API |
| Target bar for what you target, built like Guild Wars 2's: a wide flat bar with a glossy fill and a dark frame, the name inside on the left, the health and the percent inside on the right, a round badge at the right end (a crown for elites, a small skull otherwise). Red for enemies, **orange** for elites and guardians, **green** for friends (class-coloured name, "Downed" when down); shows at once on the click, exact numbers follow | client target, `AZS_TARGET`, `AZS_UNITS` |
| Nameplates in the same style (off by default): a small glossy bar with the name below it, the health inside for your target, a white outline on the target's plate, orange bars for elites and guardians, a crown or skull mark for elites and bosses, the game's raid icons (skull, cross, ...) above the bar. Options: all enemies or only elites and guardians, friendly plates on or off (and not for pets and totems) | the game's own nameplates (skinned), `AZS_TARGET`, `AZS_UNITS`, `AZS_UnitKind` |
| Damage meter with the spell icon left of each name, Healing / Boss / Party tabs. On the Party tab the icon is each player's best spell. `10s DPS` is the damage of the last 10 seconds, pets, summons and totems included; the **Reset** button starts all four tabs from zero again | meter API (totals, spell icons) |
| Co-op party frames with portrait, HP, percent, buffs and the **barrier** (see below). Click a frame to target that friend (a white outline marks your target), right click for a small menu of ours: Inspect, Trade, Follow, Whisper (and Make leader / Remove for the party leader) | party units, `AZS_GetDownedPartyMembers` |
| Ally down alert in co-op: "NAME is down!  Revive them!" in a red banner, an arrow that points to the body, the distance, a marker over the body in the world and a short sound; it goes when they get up | `AZS_GetDownedPartyMembers`, world anchors |
| Hero panel (replaces the character window): every piece of gear in a column beside the character model, name and "Level N Race Class", an **Attributes** panel with every stat grouped under Offense / Defense / Utility (icon, name, value; green when gear adds to it; the tooltip shows the raw value), accessories (neck, rings, trinkets) and the weapons you hold | `AZS_STATS`, `AZS_ZONE`, `AZS_RUN`, the inventory functions |
| Round icon on the minimap: click = settings window | |

**Barrier on the party frames.** The API gives the shield amount for your own hero only (`AZS_RUN.sh`). For friends it is
read from what the client reports: health above the maximum is drawn as a gold layer **on top of** the health bar with a
bright top edge and its amount (`+300`), and a shield buff on a friend (Power Word: Shield, Ice Barrier, Mana Shield, the
wards, Sacrifice) puts a fainter gold layer over the health when no amount is known. The percent text stays above the layer.
`/gw2 party` shows what the client says about each friend.

**Meter reset.** The game's counters cannot be cleared from an addon, so Reset remembers every line's amount at that moment and
shows the difference from then on (the game's own meter window keeps its numbers). It ends by itself when a new run starts or a
counter goes down (a new boss fight). The 10 second rate comes from the meter API (one small question a second, counted from the reset point). If the game cannot
answer, the addon works it out from the totals it sees; a line that drops out of the list (a pet that dies, a summon that
ends) no longer starts that count over.

**Attribute formats.** Chances and shares are fractions in the API (0.4 = 40%) and are shown as percent, multipliers as
`x3.04` (= 304% of the normal value, the tooltip says so), regeneration as `/s`. Cooldowns are shown as the reduction:
the API gives a multiplier (0.62), the panel shows `CDR 38%` (the tooltip says "Cooldown Reduction" and "Cooldowns take 62% as long").

Hidden while this UI is on: the game's clock, boss bars, tally, spells and jewelry rows, meter, Level Up! button, banners,
minimap flag and local clock (`AZS_SetHudShown`, asserted again every half second), the stock player / party / target
frames, buff frames, the stock minimap decorations and every piece of the stock action bar, the game's own
damage numbers (`CombatDamage`), the boss loot notice and the centre-screen messages. If a popup the game draws itself
survives anyway, the addon looks for the frame that shows the same text as each banner that comes, hides it and says so in
the chat ("hid the game's own popup (name)"). That search is small on purpose: only frames that are on screen at that moment
(at most 900), twice per banner, and it stops itself for the session after two banners in a row where it found nothing
(`/gw2 hunt on` starts it again, `/gw2 hunt off` stops it). `/gw2 off` gives all of it back.

## Settings and moving things

Click the round icon at the minimap (or `/gw2 config`): switches for every part, size, "Unlock layout", "Reset positions".
Unlocked, every frame gets a gold box with its name and size: drag it to move it, drag its corner (or use the mouse wheel) to make just that part bigger or smaller, right click puts its size back. A bar at the top of the screen locks the layout again. "Size" in the settings is still the size of everything at once; the single sizes are on top of it. Parts that belong together (the orb and its skill bar, for example) resize together.

## Commands

    /gw2 config                       settings window
    /gw2 unlock | lock                move frames freely / lock them
    /gw2 off | on                     game HUD back / this UI
    /gw2 scale 0.6-1.6                size of everything
    /gw2 reset                        forget moved frames (reloads)
    /gw2 mapyards <number|off>        yards across the minimap, if the pins are off from the map
    /gw2 plates on | off              the GW2 style nameplates (off by default)
    /gw2 plates elite on | off        only elites and guardians
    /gw2 plates friends on | off      friendly nameplates
    /gw2 plates pets on | off         on: no friendly plates for pets, summons and totems (default)
    /gw2 marks on | off               mark bosses (skull) and guardians (cross) you target with the game's icons (default on)
    /gw2 plates debug                 what the nameplate frames look like, if no plate is recognised
    /gw2 messages on | off            the game's own centre-screen messages (off by default)
    /gw2 art custom | stock           generated textures / plain colours (reloads)
    /gw2 hide <FrameName>             keep one more of the game's frames hidden
    /gw2 unhide <FrameName>
    /gw2 find <text>                  list frames showing that text, to find a name for /gw2 hide
    /gw2 hunt on | off                the search for the game's own popups (stops by itself when it finds none)
    /gw2 dmg all | crits | off        damage numbers: everything / critical hits only / none
    /gw2 dmg ticks on | ticks off     damage over time ticks in the numbers
    /gw2 char [on | off]              open the hero panel / use it instead of the game's character window
    /gw2 stats                        every value of AZS_STATS, to check what the Attributes show
    /gw2 party                        health and buffs of each friend as the client reports them
    /gw2 bind <character|talents> <BINDING>
    /gw2 bindings [text]              list key binding names
    /gw2 debug                        HUD part states, hidden frames, bindings, minimap and damage number status

## Safety, memory and performance

- No network, chat or addon messages are sent; no code is loaded from text (`loadstring`, `RunScript` and the like are not
  used). What it changes in the game: `ToggleCharacter` is wrapped (everything but the paper doll tab passes through) and
  `CharacterFrame` gets an OnShow hook, one small menu frame (`AZSGW2PartyMenu`, plain buttons, no drop-down template) is made for the party menu; its entries only call the game's own Inspect, Trade, Follow and Whisper functions, `RaidNotice_AddMessage` and `UIErrorsFrame.AddMessage` are silenced, the frames it
  hides get an OnShow script that hides them again, and the settings of the game's own damage numbers and HUD parts are
  switched (the old values are saved). `/gw2 off` gives all of that back.
- Text that comes from outside (hero and friend names, banners) is cleaned of `|` colour / link codes before it is drawn.
- The saved variables are checked at every start: wrong types, invalid anchors, impossible numbers and unsafe frame names
  are dropped. `/gw2 hide` only accepts plain frame names and refuses the world, `UIParent`, chat, dialogs,
  the map and this addon's own frames; the popup hunter never hides those either, and remembers at most 60 frames.
- Every cache has a limit (damage labels 60, banners 4, meter names 400, shield icons 300, hidden frames 60); frames are
  created once and reused. In the test harness (`tools/`), a simulated 24 minute run with damage, banners, downed friends,
  target changes, stat changes and windows opening and closing kept the memory and the number of frames flat.
- An error in one part is printed once and that part tries again after 10 seconds; after five errors close together it
  stops, the rest of the UI goes on.
- Work per frame is small and throttled: the minimap pins, meter, loadout and API reads run 5 to 20 times a second at most,
  nameplates and minimap zoom are only touched when the game changed them, the popup search is bounded (above). The orb,
  skill bar, health bars, party frames, minimap pins and damage numbers remember what they last drew and only send a change
  to the game (in the test harness an idle frame went from 91 to 36 widget calls and from about 23 KB to 11 KB of garbage).

## If something is still wrong

- Minimap pins sit in the wrong place: `/gw2 debug` shows the zoom and the yards it assumes; set it with
  `/gw2 mapyards <number>` (try 200 to 470) until a cache you stand next to sits under your arrow.
- The minimap is empty or broken: switch "GW2 minimap" off in the settings (the game's own comes back).
- Two sets of pins on the minimap: the game draws its own cache / guardian blips on its minimap; switch ours off in the settings.
- Native damage numbers still show next to ours: `/gw2 debug` says whether the combat text API was found.
- A piece of the old UI is still on screen: `/gw2 find <text on it>`, then `/gw2 hide <name>`.
- An Attribute shows a wrong number: hover it (it shows the raw value) or use `/gw2 stats`; a stat the list does not know is
  shown under "Other".
- The game's own character window comes up instead of the hero panel: `/gw2 char on`. Outside a run the game's window is used
  on purpose; `/gw2 char` opens the panel directly.
- Right click on a party frame shows no menu or Inspect does nothing: the chat says why ("too far away to inspect (about 28 yards)", "Inspect is not available in this game version", or "party menu failed" with the reason).
- No barrier on a friend: `/gw2 party` shows their health and buffs; a shield the client does not report cannot be drawn.
- The Talents or Character button opens the wrong thing: `/gw2 bindings`, then `/gw2 bind talents <BINDING>`.
- Nameplates look like the game's old ones: the skin needs the game's plate frames to look the way they do in the standard
  1.12 client. If they do not, nothing is hidden and the game's plates show as before; `/gw2 plates debug` prints what it finds,
  please send that. Plain enemies show no number, elites show their percent, your target shows the exact health (the AZS API gives
  exact health for the target and for special enemies only). Only the target can be told apart from guardians, other
  guardians look like elites.
- Nameplates and the V key: the game's key now works as usual; our options decide what the plates look like. `/gw2 plates off`
  gives the game's own plates back.
- The number on top of a skill is the most enemies it can hit, read from the skill's own tooltip ("Strikes the 5 nearest
  enemies ..."): it follows upgrades and cards within a few seconds. A skill whose tooltip has no number shows nothing. Switch it
  off with "Max targets, on the skills" in the settings.
- Marks: the game's skull goes on a boss and a cross on a guardian when you target them (a boss also when you point at it).
  Only a unit you target or point at can be marked, and a guardian is only known as one once targeted. An existing mark is never
  changed; one you remove stays removed until you target that enemy again. `/gw2 marks off` stops it. Whether a mark can be set
  depends on the game (in a party, perhaps only the leader); `/gw2 plates debug` says whether the functions exist.
- Two health bars on a nameplate: the game's own bar became visible again next to ours (most likely when it gives a plate to a
  new enemy). The addon now looks at every plate again and hides it whenever it comes back; if it still happens,
  `/gw2 plates debug` lists the parts of two plates with their alpha, please send that.
- A freeze or a black screen: try `/gw2 hunt off` and `/gw2 off` to see whether the addon is involved at all, and report what
  it happened next to together with `/gw2 debug`.

## Fonts, licences and credits

`Fonts/azs_numbers.ttf` is a Latin / Cyrillic subset of Carlito, renamed as the SIL Open Font License requires; the licence is
in `Fonts/OFL.txt`. It draws the damage numbers on every client and the names and numbers of the boss and guardian lists on
clients whose own font is the Latin one (Chinese / Japanese / Korean clients keep their own font there). If the client cannot
load it, the game's own font is used.

This is a fan made interface for Azeroth Survivors. It is not affiliated with or endorsed by ArenaNet, NCSOFT or Blizzard;
"Guild Wars" is a trademark of ArenaNet / NCSOFT. The layout is inspired by Guild Wars 2's interface; all textures, icons and
code here are original.

## Changes in 1.8.1

- The minimap icon only opens the settings window (right click removed: it left you in the unlocked layout).
- Talent procs above the left skills are gone (they showed empty icons).
- Every part can be resized on its own in the unlocked layout (corner, mouse wheel, right click to reset); a lock bar sits at the top.
- Nameplates in the Guild Wars 2 style, with options for all enemies / only elites and guardians / friendly plates. The game's V key no longer gets undone half a second later.
- A new target bar in the style of Guild Wars 2.
- A small number on top of each skill shows how many enemies it can hit at most (from its tooltip).
- Nameplates: the game's own bar no longer shows next to ours (it came back when a plate was reused); elites and guardians are orange; bosses and guardians you target get the game's skull / cross (option); friendly plates can leave out pets and totems.
- The 10 second DPS no longer stops after a few seconds on pet builds.

## Changes in 1.8.0

- Party right click opens our own small menu (Inspect, Trade, Follow, Whisper, leader actions) instead of the game's drop-down; Inspect tells you in the chat when it cannot work (too far away, not available).
- Friendly targets get a health bar on the target bar: the same bar as for enemies, in green, with a class-coloured name.
- The yellow timer bar under boss and guardian rows is gone; the rows are shorter.
- Meter, Party tab: each player's best spell icon sits left of the name, like on the other tabs.
- Party barrier is a real overlay on the health bar (gold layer with a bright top edge); the percent text stays above it.
- Performance: the orb, skill bar, health bars, party frames, minimap pins and damage numbers only send changes to the game; the 10 second DPS no longer asks the game for a window every time; damage numbers reuse their work lists.

## Changes in 1.7.0

- Heroic affixes moved to the right end of the line under the run bar (they overlapped the run timer); the next boss is at the left end of that line while affixes show.
- Skill bar tooltips: hovering a skill shows the game's own spell tooltip (description, cost, range) when the spell is in your
  spellbook, with the cooldown left added; otherwise name, rank and cooldown. A tooltip that fails is caught and reported once.
- Party frames: left click targets the friend (a pending spell or an item on the cursor goes to them), right click opens the
  game's party menu with Inspect, Trade, Follow, Whisper and so on. The target gets a white outline.
- Hero panel opens at the left edge of the screen by default (drag it anywhere).
- Damage meter: **Reset** button (all four tabs); `10s DPS` / `10s HPS` is the rate of the last 10 seconds.
- The red blot behind a critical hit grows with the number: a 1000 or a 98765 now sits on a blot that fits.
- Cooldowns read as `CDR 38%` instead of `x0.62`.

## Changes in 1.6.0

- Party frames show the barrier (gold segment with the amount, or a gold line for a shield buff).
- The boss / guardian list has no repeated skull and crown: one enemy has no title, several get a slim one.
- Damage numbers are bigger (hits +7%, crits +17%, whole font sizes).
- Hero panel: all gear in the left column, only accessories on the right, weapons only when held, helm / cloak switches
  removed; luck and all chance stats read as percent, multiplier tooltips show the percent.
- Release hardening: saved variables checks, protected frames, text cleaning, bounded caches, error recovery, a 24 minute soak test.
- Earlier in 1.5: difficulty on the run bar, ally-down alert with arrow, minimap arrow for you, damage number options.
