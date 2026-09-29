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
- built-in Automatic, Vanilla, Modern Dark, Blue, and ElvUI presentation choices;
- a minimap button that common button collectors can detect.

The `v0.2.0` download is published as a pre-release while the wider addon-combination and gameplay test matrix is still being completed.

## Download and install

1. Open the [Releases](https://github.com/Kamui2040/K2040-WotLK-Addons/releases) page.
2. Download `K2040-Loot-and-Salvage-v0.2.0.zip`.
3. Extract the included `K2040_CrapFilter` folder into `World of Warcraft/Interface/AddOns`.
4. Start or restart the game.

The folder keeps its original technical name so existing settings and item lists continue to load.

### Presentation choices

All five presentation choices are included in the main addon. **Automatic** uses the ElvUI presentation only when both ElvUI and AddOnSkins are loaded; otherwise it uses **Vanilla**. **Blue** keeps the Vanilla layout and changes its red action buttons to GMGenie-style blue controls. Changes offer a reload prompt and take effect after reload or restart.

ElvUI and AddOnSkins are needed only when the ElvUI presentation is selected. The separate bridge shipped with the historical `v0.1.0` preview is retired and should not be installed with `v0.2.0`.

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
xmllint --noout addons/K2040_CrapFilter/Bindings.xml
git diff --check
```

Source checks do not replace in-game testing. Please include the exact WotLK client build and enabled addon combination in bug reports.

## Licence

The repository and K2040 Loot & Salvage are available under the [MIT License](LICENSE).
