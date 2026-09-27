# K2040 Loot & Salvage

Sort loot, clean bags, and process profession items in World of Warcraft WotLK 3.3.5a.

## Target

- Client: WotLK 3.3.5a build 12340
- Interface: `30300`
- Runtime: Lua 5.1
- Required dependencies: none
- Optional integration: AdiBags

## Main behavior

- Separate searchable Always Keep and Always Crap settings pages with unlimited item-ID rules, visible selectable rows, dedicated removal, and confirmation-protected list reset.
- Quality, vendor-value, food, water, potion, cloth, scroll, and trade-goods classification.
- Independent always-loot choices for Linen, Wool, Silk, Mageweave, Runecloth, Netherweave, and Frostweave Cloth.
- Separate loot and destruction decisions.
- Optional automatic merchant selling for every sellable item currently classified as crap.
- Skinnable, mineable, gatherable, and engineerable corpse overrides.
- Safety-bounded auto-destroy that removes no more than the proven net increase from the current loot session.
- Modifier + right-click and mouse-over keybind classification for supported Blizzard, ElvUI, and AdiBags item buttons.
- Separate Disenchant, Milling, and Prospecting queues with profession-specific Always/Never lists.
- User-triggered profession casts through one secure action. The next eligible Disenchant, Milling, or Prospecting target is prepared automatically, and the action advances after each completed result.
- Optional profession-result auto-loot, disabled by default and limited to the immediate item-only window following a cast started from the prepared action; later or mixed windows remain manual.
- Optional AdiBags `IsJunk(itemID)` input. Always Keep takes precedence.
- A compact movable and resizable two-pane quick-list window whose pane backgrounds accept dragged items for Always Keep or Always Crap, with search, selection/removal, and reset controls for either canonical list. Pane widths and visible rows adjust with the window.
- An original filter symbol inside the standard circular WotLK minimap-button frame, plus absent-safe LibDataBroker/LibDBIcon registration for compatible button collectors and broker displays.
- Native settings under Interface -> AddOns. `/kcf` opens the same settings panel.

## Safety rules

- Automatic destruction is disabled by default.
- Automatic merchant selling is disabled by default and skips Always Keep, profession-reserved, locked, and unsellable items.
- Uncached or unrecognized items are kept.
- Always Keep overrides every automatic crap classifier.
- Quest-category items are protected by default.
- For food, water, combined food/drink, potions, and scrolls, the optional lower-tier rule protects the highest tier the character can currently use and classifies only lower usable tiers as crap.
- Automatic destruction is capped at Common quality and below.
- Profession targets are reserved before destruction.
- If the addon cannot prove how many copies were newly looted, it keeps them.
- Profession casts require a user click; the addon never loops protected casts.
- Profession result windows bypass ordinary crap-loot and auto-destroy attribution.

## Commands and keybinds

- `/kcf` — open Interface Options.
- `/kcf lists` — toggle the compact Always Keep / Always Crap window.
- `/kcf process` — toggle profession processing. Enable each queue in its settings page, then click the prepared action once per cast.
- `/kcf scan` — rescan bag and profession targets.
- `/kcf help` — show command help.

Mouse-over Always Crap/Always Keep actions are available in the normal WoW Key Bindings window under K2040 Loot & Salvage.

## Validation

From the repository root:

```bash
bash tools/run-luacheck.sh
luajit tools/test-k2040-crap-filter.lua "$PWD"
xmllint --noout addons/K2040_CrapFilter/Bindings.xml
git diff --check
```

Static validation does not prove in-game behavior. Installation, `/reload`, relog, secure-action behavior, bag-addon coexistence, SavedVariables persistence, UI appearance, and actual loot/destruction behavior require controlled physical-client QA.

## Provenance

This is an original K2040 implementation. KarniCrap source was not copied or reused. The historical AddOnSkins KarniCrap adapter was consulted only to identify legacy settings and controls. Enchantrix was inspected only as a behavioral reference for one-click profession processing; no Enchantrix code or data is embedded. AdiBags integration uses its exposed `IsJunk(itemID)` method and filter-change message; no AdiBags source is embedded. The minimap icon is a project-owned, text-generated original; its source and conversion record are kept under `assets/K2040_CrapFilter` in this repository.

## Licence

K2040 Loot & Salvage is available under the MIT License. See `LICENSE`.

The technical addon folder remains `K2040_CrapFilter` so existing settings and lists continue to load.

The public package contains only the standalone addon and does not require ElvUI or AddOnSkins.
