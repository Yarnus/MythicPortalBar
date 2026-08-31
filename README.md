# MythicPortalBar

MythicPortalBar is a lightweight Retail World of Warcraft addon that adds a current-season dungeon bar to the Premade Groups dungeon search page.

Each dungeon item shows:

- The dungeon icon and localized dungeon name
- The character's highest completed keystone level
- The character's Blizzard dungeon score on hover
- Whether the character has learned the dungeon portal

Click a learned portal to teleport. Unlearned or unmapped portals are greyed out. Hold Shift and left-drag to move the bar.

## Features

- Dynamically reads the current Mythic+ dungeon pool in Blizzard order
- Uses only Blizzard APIs and no third-party libraries
- Refreshes from game events with no polling or `OnUpdate` loop
- Supports English and Simplified Chinese clients
- Provides native addon settings for scale, opacity, icon size, spacing, abbreviations, position locking, and typography
- Saves position and appearance account-wide

## Commands

- `/mpb options` opens addon settings
- `/mpb reset` resets the bar position
- `/mpb resetall` restores all defaults
- `/mpb scale <0.5-2.0>` changes scale directly

## Installation

Place the `MythicPortalBar` directory in `_retail_/Interface/AddOns/`, then restart World of Warcraft or reload the UI.

## Compatibility

The initial release targets Retail 12.1.0. The season pool and scores are dynamic. Dungeon portal spells require a small maintained Challenge Mode map-to-spell mapping in `Data.lua`.

## License

[MIT](LICENSE)
