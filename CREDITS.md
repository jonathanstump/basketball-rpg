# Credits

Concrete Crown (working title) is built with procedural, self-made assets first (spec D4).

## Engine & tools

- [Godot Engine](https://godotengine.org) 4.7 — MIT license (`licenses/Godot_MIT.txt`). Exported builds also include Godot's third-party components; see https://godotengine.org/license.
- [GUT — Godot Unit Test](https://github.com/bitwes/Gut) 9.7.1 — MIT license (`addons/gut/LICENSE.md`, copy in `licenses/`).

## Fonts

- [Bungee](https://fonts.google.com/specimen/Bungee) by David Jonathan Ross — SIL Open Font License 1.1 (`licenses/Bungee_OFL.txt`).
- [Permanent Marker](https://fonts.google.com/specimen/Permanent+Marker) by Font Diner — Apache License 2.0 (`licenses/PermanentMarker_Apache-2.0.txt`).
- [Inter](https://rsms.me/inter/) by Rasmus Andersson — SIL Open Font License 1.1 (`licenses/Inter_OFL.txt`).

## Assets

All meshes, materials, shaders, music and sound effects are generated procedurally by the game's code:

- **Music:** `BeatSequencer` synthesizes drums, bass, lead and pad from the 16-step patterns in `data/audio/patterns.json`. It is original and uses no samples. Treat it as placeholder until commissioned music replaces it.
- **Sound effects:** `SfxSynth` renders the sfxr-style recipes in `data/audio/sfx.json` at boot.
- **Voices:** procedural syllable blips.
- **Visuals:** primitive meshes, custom shaders, procedural murals and signage. All text, brands and characters are original, with no real brands, logos, people or song samples.

No external CC0 assets are used.
