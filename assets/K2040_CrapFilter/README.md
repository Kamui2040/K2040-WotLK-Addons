# K2040 Loot & Salvage minimap icon

`MinimapIcon-master.png` is the project-owned source for the addon's minimap and broker icon.

## Provenance

- Created on 2026-09-27 with OpenAI's built-in image-generation tool at the project owner's request.
- Generated from text only. No third-party image, game texture, logo, or trademark was used as an input.
- Intended design: a dark-steel sorting funnel, one retained gold glint, and rejected red shards on a transparent background.
- The generated output and its derived game texture are included under the addon's MIT licence.

## Runtime derivative

The WotLK-compatible texture is `addons/K2040_CrapFilter/Media/MinimapIcon.tga`. It is a 64 x 64, 32-bit RGBA, uncompressed TGA derived with:

```bash
magick assets/K2040_CrapFilter/MinimapIcon-master.png -filter Lanczos -resize 64x64 -alpha on -depth 8 -define tga:bits-per-pixel=32 -compress None addons/K2040_CrapFilter/Media/MinimapIcon.tga
```

SHA-256:

- master PNG: `feca49bb97aa0c6e17b795d508395b891989d03e3741e865b8d519b049c92e85`
- runtime TGA: `65abcb10f431664b7ebf6167b2fda42795569a336dc7f2629b40dcff36d87050`
