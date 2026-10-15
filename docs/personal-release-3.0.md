# Personal release 3.0

Source release: kevinerikjs/gta5-ios-port `7b2f2cdc4ad82870c8ed08d44fa81ad2dad6a40d` (v1.3.3).
Personal feature source: `d9bbafd471e6ff89bb67eca32d017e688b843953` (v2.4).

Added to the current release:
- Existing Zenyical launcher, artwork, icon and Story/Sandbox selection sheet.
- Trainer commands, wardrobe editor, police vehicles and suits, saved outfit and Story-mode skin protection.
- Sandbox checkpoint storage and collision-gated resume, including the v2.4 character-swap fix.
- Default-on manual driving-camera hold, controlled from Settings.
- One-time FPS, camera and graphics settings migration, plus compatibility for saved control positions.

Kevin's new renderer, audio, memory budgeting, installer, intro, controls, story cheats and translation resources are the foundation. Old custom graphics/rendering/audio overrides are not applied.

The bundle identifier remains `io.github.playgta5ios.app`; save/cache roots and the Sandbox checkpoint record are unchanged. Update with the same Apple signing identity, over the installed app. Never delete the existing app to update.

Native regression tests exercise the trainer engine dispatch, wardrobe and checkpoint state, durable store, camera hold, memory guard and settings migration. A generated-code test exercises the patched character-swap function itself. Simulator UI tests exercise real launcher, trainer, wardrobe, controls and settings views with an isolated engine bridge. Physical-device gameplay and retention still need device observation.
