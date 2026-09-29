# Changelog

## 0.2.0 - 2026-09-30

- Added built-in Automatic, Vanilla, Modern Dark, Blue, and ElvUI presentation choices across addon-owned settings, profession processing, and Quick Lists surfaces.
- Automatic now uses ElvUI only when both ElvUI and AddOnSkins are available and otherwise uses Vanilla.
- Added a reload prompt when the selected presentation changes.
- Kept dropdown labels, arrows, editable-field carets, semantic text colors, overlapping-window controls, and native minimap behavior visible across the selectable presentations.
- Retired the separate `v0.1.0` AddOnSkins bridge. AddOnSkins remains optional and is used only by the built-in ElvUI presentation.

This version remains a pre-release while the broader gameplay, dependency, persistence, reload/relog, and secure-action matrix is completed.

## 0.1.0 - 2026-09-27

Initial public preview of K2040 Loot & Salvage.

### Included

- Unlimited searchable Always Keep and Always Crap item lists.
- Quality, vendor-value, consumable, cloth, scroll, and trade-goods rules.
- Optional cloth auto-loot and merchant selling.
- Newly-looted-only auto-destroy safeguards.
- Corpse loot overrides for gathering professions.
- Quick classification for supported bag buttons.
- A compact, resizable Quick Lists window and collector-compatible minimap button.
- User-clicked Disenchant, Milling, and Prospecting processing with optional immediate result auto-loot.
- Optional AdiBags Junk classification.

This version is a pre-release while the wider in-game compatibility matrix is still being completed.

### Optional separate download

- Added the K2040 Loot & Salvage - AddOnSkins bridge as its own addon and release download.
- The bridge requires separately installed copies of ElvUI, ElvUI AddOnSkins, and K2040 Loot & Salvage.
- It does not overwrite or bundle third-party addon files.
