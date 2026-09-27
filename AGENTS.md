# Repository instructions

## Scope

- Target World of Warcraft WotLK 3.3.5a build 12340, Interface `30300`, and Lua 5.1.
- Keep each addon usable without ElvUI or another UI replacement unless its own documentation explicitly says otherwise.
- Preserve the `K2040_CrapFilter` folder, addon ID, and `K2040CrapFilterDB` SavedVariables name unless a tested migration is included.

## Safety and compatibility

- Keep Always Keep stronger than automatic cleanup rules.
- Do not destroy quantities that existed before the current loot session.
- Keep profession casts user-triggered. Do not automate protected actions.
- Preserve unknown SavedVariables fields where practical. Migrations must be versioned, bounded, and failure-safe.
- Treat item links, SavedVariables, archives, Lua, XML, TOC files, and media as untrusted input.

## Public repository rules

- Do not commit credentials, personal data, real account/WTF data, character or realm details, private URLs, local machine paths, game/client files, or private-server material.
- Use synthetic fixtures for tests.
- Include only code and assets with clear redistribution rights. Preserve required notices and provenance.
- Do not add third-party source, libraries, or artwork without a compatible licence and explicit attribution.

## Validation

Before submitting a change:

```bash
bash tools/run-luacheck.sh
luajit tools/test-k2040-crap-filter.lua "$PWD"
xmllint --noout addons/K2040_CrapFilter/Bindings.xml
git diff --check
```

Also verify TOC load order, Lua 5.1 syntax, package contents, privacy, licences, and any changed SavedVariables behavior. In-game compatibility claims require actual testing on WotLK 3.3.5a with the named addon combination.

## Collaboration

- Use focused branches and pull requests. Do not rewrite shared history.
- Keep unrelated changes separate.
- Public releases and repository settings are maintainer-controlled.
