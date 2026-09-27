# K2040 WotLK Addons

Open-source addons for World of Warcraft: Wrath of the Lich King 3.3.5a.

## K2040 Loot & Salvage

K2040 Loot & Salvage sorts loot, cleans bags, sells unwanted items, and helps process profession materials. It works as a standalone addon with the default Blizzard UI.

Main features:

- unlimited Always Keep and Always Crap lists;
- quality, vendor-value, food, water, potion, cloth, scroll, and trade-goods rules;
- optional merchant selling and carefully limited auto-destroy;
- quick bag-item classification and a compact two-pane list window;
- user-clicked Disenchant, Milling, and Prospecting processing;
- optional AdiBags Junk classification;
- a minimap button that common button collectors can detect.

The `v0.1.0` downloads are published as a preview while the wider addon-combination and gameplay test matrix is still being completed.

## Download and install

1. Open the [Releases](https://github.com/Kamui2040/K2040-WotLK-Addons/releases) page.
2. Download `K2040-Loot-and-Salvage-v0.1.0.zip`.
3. Extract the included `K2040_CrapFilter` folder into `World of Warcraft/Interface/AddOns`.
4. Start or restart the game.

The folder keeps its original technical name so existing settings and item lists continue to load.

### Optional AddOnSkins bridge

If you use ElvUI and ElvUI AddOnSkins, the release also provides `K2040-Loot-and-Salvage-AddOnSkins-v0.1.0.zip` as a separate download.

1. Install K2040 Loot & Salvage, ElvUI, and ElvUI AddOnSkins first.
2. Extract the included `K2040_LootAndSalvage_AddOnSkins` folder beside those addons.
3. Enable **K2040 Loot & Salvage - AddOnSkins** on the character-selection AddOns screen.

The bridge changes presentation only. It does not replace AddOnSkins files, and the main addon remains fully standalone.

## Compatibility

- WoW WotLK 3.3.5a, build 12340
- Interface `30300`
- Lua 5.1
- No required libraries or UI replacement

Use `/kcf` to open the settings. See the [addon guide](addons/K2040_CrapFilter/README.md) for all commands and safety details.

## Development

Run the local checks from the repository root:

```bash
bash tools/run-luacheck.sh
luajit tools/test-k2040-crap-filter.lua "$PWD"
luajit tools/test-addonskins-adapter.lua "$PWD"
xmllint --noout addons/K2040_CrapFilter/Bindings.xml
git diff --check
```

Source checks do not replace in-game testing. Please include the exact WotLK client build and enabled addon combination in bug reports.

## Licence

The repository and K2040 Loot & Salvage are available under the [MIT License](LICENSE).
