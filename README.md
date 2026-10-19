# Atlas Plus

**Instance maps with every boss and its loot.** For World of Warcraft 3.3.5a (Wrath of the Lich King).

Version 1.10.3 · by Saranwrap · made for ChromieCraft (AzerothCore)

Atlas Plus puts the world map, the map of every dungeon and raid, their bosses and everything they drop in one clean window, and opens on the right map by itself. It also replaces map marker addons and removes the fog of war.

- **Opens where you are**: in a dungeon or raid, on its map (and the right wing of Ulduar, Icecrown Citadel, Karazhan, Dire Maul...) with the loot of your difficulty. Outdoors, on the world map, on your zone.
- **Every instance**: Classic, Burning Crusade and Wrath dungeons and raids, plus entrance maps and dungeon locations.
- **Every boss and its loot**: Normal / Heroic, 10 / 25 / 10 Heroic / 25 Heroic, drop chance of each item ("2x" when two drop at once, like emblems), Ulduar hard modes, Alliance / Horde only items, chests, and trash drops. Class items (Vault of Archavon PvP sets, tier pieces...) are in a folded list per class (yours open).
- **Emblems of the current phase**: ChromieCraft hands out emblems by progression phase. Each boss shows the emblem of the current phase first (*current phase*), then the one it gives in a later phase (*later phase*).
- **World drops**: their own lists in the left panel (Classic, Burning Crusade, Wrath): rare and epic items and recipes any creature of the right level can drop, with the creature levels and the chance per kill.
- **World events**: Hallow's End, Brewfest, Love is in the Air, Midsummer, Winter Veil, Lunar Festival, Noblegarden, Children's Week, Pilgrim's Bounty, Darkmoon Faire and more: the holiday bosses and their reward bags, the event vendors with their prices, and the quest rewards.
- **Vendors**: what you can buy with each currency (badges and emblems, Stone Keeper's Shards, Champion's Seals, honor and arena points, battleground marks, Wintergrasp marks...), vendor by vendor with its zone and the price of every item.
- **Search** instances (also by short name: ICC, Uld, EoE, VoA...), bosses, events, vendors and items: every result says where the item comes from (boss, world drop, vendor or quest).
- **World map in the same window**: the map key (M) opens Atlas Plus with the game's own map inside, so quest objectives and Questie keep working. Zone levels, instances and fishing skill, clickable instance icons, coordinates.
- **Map markers**: dungeons, raids, world bosses, boats, zeppelins, the Deeprun Tram and portals. Click a transport or portal to go to where it leads. Filter them, or find any of them in a list.
- **No fog of war**: unexplored areas are shown (a bit darker, optional).
- **Move, resize, opacity**: drag the title, resize from the corner, opacity in the settings.

---

## Installation

1. Close the game.
2. Download the zip (on GitHub: **Code → Download ZIP**) and open it.
3. Copy the **`AtlasPlus`** folder into `<WoW folder>\Interface\AddOns\`. Keep its name: the addon loads from it.
4. Start the game.

**Updating:** close the game, **delete the old `AtlasPlus` folder completely**, then copy in the new one. The game only loads new files after a full restart, not after `/reload`.

Atlas Plus does not need Atlas, AtlasLoot or another map addon. Use it alone: other map addons (Mapster, ModernMapMarkers...) also change the game's map and can show things twice. If TomTom is installed, turn off its world map coordinates.

---

## The window

Open it with the map key (**M**), `/ap`, the minimap button or a key (**Escape → Key Bindings → Atlas Plus**).

Two tabs at the top: **World map** and **Atlas** (instance maps, bosses and loot). Drag the title to move the window, drag the corner at the bottom right to resize it. While you move, it fades (50% by default, setting) unless the mouse is over it. The map works in combat too: the map key opens Atlas Plus with the map as usual. The selected quest's shaded area comes back when the fight ends.

In a dungeon or raid with a game map (Ulduar, Icecrown Citadel...), Atlas Plus opens that map on the World map page, on the floor you are on. The Atlas map stays in the **Atlas** tab.

| Part | What it does |
| --- | --- |
| **Left** | Every instance, by expansion: dungeons and raids, then World Drops, World Events, Vendors, entrances and dungeon locations. Folded when the window opens: click a title to open it. Drag the bar between the list and the map to make the list wider or narrower (right-click it: first width). |
| **Middle** | The map, with numbered bosses and points of interest. **Right-click** on it: back to the world map, as you left it. |
| **Right** | The legend of the map. A boss marked **loot >** opens its loot. **Trash mobs** at the end shows what the trash drops. **Entrance map / Instances** switch between an instance and its entrance. |
| **Top** | **World map** / **Atlas** tabs, search (instances, bosses, loot), Settings. |

In a loot list: hover an item for its tooltip, **Shift-click** to link it, **Ctrl-click** to try it on, **right-click** to go back to the bosses. **HM** = hard mode (Ulduar) or drakes up (Sartharion), **A / H** = Alliance / Horde only.

World Drops, World Events and Vendors have no map: the middle shows what the page holds. Their lists work like a boss's loot:

| Column | World drops | Event bosses and bags | Vendors | Quest rewards |
| --- | --- | --- | --- | --- |
| Middle | Item type and creature levels (**L53-60**) | Item type | Item type | Item type |
| Right | Chance per kill | Drop chance | Price (gold, honor, arena points, badges, emblems, tokens) | **Quest** (the tooltip names the quest) |

---

## World map

The map key (**M**) opens Atlas Plus on its world map page. It holds **the game's own map**, so quest objectives, your group and map addons such as **Questie** show on it.

- **Left-click** to zoom in, **right-click** or **< Zoom out** to zoom out (zone → continent → world).
- Top: continent buttons, a zone list, **Quests** (quest objectives on / off), **Game map**, and **Find me** (your zone, with a pulse on your arrow).
- **Zone panel** (top left): the zone shown, its **level range** (colored for your level), its **dungeons and raids** and its **fishing** skill. On a continent, the same under the zone you point at.
- **No fog of war**: the areas you have not explored yet are shown, a bit darker.
- Your **coordinates** and the cursor coordinates, under the map.

### Map markers

| Marker | Click |
| --- | --- |
| Dungeons (blue) and raids (green) | Its map, bosses and loot |
| Boats, zeppelins, Deeprun Tram, portals | The map where it leads; the arrival point pulses |
| World bosses | Their name and level |
| Flight masters, innkeepers, mailboxes, banks, auction houses | Their name (each type on / off, own size) |

Ring color: blue Alliance, red Horde, gold neutral. Markers also show (smaller) on continent maps. Tooltips give the group size: 5, 10, 25, 40, or 10/25 for the Wrath raids. Under the map: **Markers** chooses which ones show (and *Only my faction's* transports and portals), **Find** lists every marker of a continent by type, with a search box (name or zone); click one and the map goes there.

With Questie installed, its own dungeon and raid icons are hidden while the Atlas Plus ones are on (setting), and come back when you turn those off.

**The game's map on its own**: the **Game map** button opens the game's small map (its own button makes it full screen, with the quest list), and so does the map button of the quest log. It gets the same zone info and coordinates, an opacity setting and a size setting that apply even while it is open, and it always stays on the screen. Untick **The map key (M) opens Atlas Plus** to get it back on M.

---

## Settings

**Settings** button, right-click on the minimap button or `/ap settings`. Settings is a window of its own: move it, resize it from its corner, and watch the map change as you go.

| Column | Options |
| --- | --- |
| **Window** | Open on the map of where you are, open by itself in dungeons and raids, minimap button, lock, fade while moving, opacity while moving, size, opacity |
| **World map** | Map key (M), game instance maps, no fog of war, darken unexplored areas, zone panel, zone info under the cursor, coordinates, quest icon size, game map opacity and small map size |
| **Map markers** | Each type on / off (towns included), on continent maps too, hide Questie's dungeon and raid icons, only my faction's, marker size, town marker size |

*Quest icon size* changes the game's numbered quest icons; Questie's icons have their own size settings in Questie.

## Commands

| Command | What it does |
| --- | --- |
| `/ap` | Open / close |
| `/ap here` | The map of where you are |
| `/ap world` | The world map page |
| `/ap search <text>` | Search instances, bosses and the loot of every instance |
| `/ap settings` | Settings |
| `/ap reset` | Window position, size and opacity |

---

## About the data

- **Maps and legends**: [Atlas](http://www.atlasmod.com) by Dan Gilbert and contributors, released under the GNU GPL v2. Atlas Plus is released under the same license (`LICENSE.txt`).
- **Loot and drop chances, vendors, quests, world events**: the AzerothCore world database (the core ChromieCraft runs on). A server can change some of its loot, so treat the chances as a guide. World drop chances are for a typical creature of the level. Event dates are the usual ones; the server's calendar has the exact dates.
- **Emblems by phase**: ChromieCraft's progression module (mod-progression-system), up to Phase 3 (Ulduar). When the server reaches a new phase, the emblems marked *current phase* can be out of date until Atlas Plus is updated.
- **Prices**: the game's ItemExtendedCost table.
- **Zone levels and instances**: LibTourist-3.0 (MIT, ckknight and Arrowmaster).
- **Boats, zeppelins, portals, world bosses**: the AzerothCore world database (transport routes, portals and their destinations, spawns), placed on the maps with the game's own WorldMapArea table. **Unexplored areas**: the game's WorldMapOverlay table. **Exact entrances** of the Hellfire, Coilfang, Tempest Keep and Auchindoun wings and a few others: the game's AreaTrigger table.
- **Instance icons**: Blizzard Entertainment game art, from the Questie icon set. **Marker icons**: drawn for Atlas Plus.
