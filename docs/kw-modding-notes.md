# Kane's Wrath modding notes

Hard-won facts about getting a data mod to load in Command & Conquer 3: Kane's
Wrath 1.02 (Steam build), recorded so nobody has to rediscover them. Everything
here was verified on 2026-08-23 with a real game launch, using
[KWBandage](https://github.com/theHostileNegotiator/KWBandage) R4.0 as a
known-good control mod.

## What works

| Topic | Answer |
|---|---|
| Compiler | WrathEd 1.10 (vendored in `Tools/WrathEd`). Stamps the KW type hashes (`AllTypesHash 0x12B3E763`). |
| Stream naming | `static_common_mod` patched on `static_common_2`; low LOD `static_l_common_mod` patched on `static_l_common_2` (separate compile with `-postfix:L -bcn:LowLOD`). |
| `.version` files | Written by hand: `data\static.version` and `data\static_l.version` both contain `_common_mod`. The suffix is appended to `static` / `static_l`. |
| Base manifests | Extracted from `Core\1.2\patch2.big` (`data\static_common_2.manifest`, `data\static_l_common_2.manifest`), RefPack-decompressed. |
| Overriding stock assets | Redeclare with the same `id`. WrathEd accepts it; verified in game (`5RandomOverlord` relabelled). |
| UI strings | `data\cnc3.str` in a language `.big`, generated from the game's `cnc3.csf` + the mod's additions. |
| Loading | A `CNC3EP1_<language>_1.3.SkuDef` in the game folder: `set-exe`, the mod's `add-big` lines, then `add-config CNC3EP1_<language>_1.2.SkuDef`. The stub launches the highest-versioned SkuDef. First entries win. |
| Skirmish AI dropdown | Enumerates all `AIPersonalityDefinition` with `SkirmishPersonality="true"`, de-duplicated by `PersonalityUIName`. New ids appear; no fixed list. A missing string shows as `MISSING: Personality:...`. |

## Dead ends (do not retry)

| Attempt | Result |
|---|---|
| EA's Tiberium Wars `BinaryAssetBuilder.exe` with KW XML/XSD | Compiles identical instance data but stamps TW type hashes (`0xEB19D975`); the KW engine rejects it: *"Type hash mismatch for type ... DID YOU REMEMBER TO BUILD DATA???"*. |
| Qibbi's C# BinaryAssetBuilder | `AIPersonalityDefinition` not implemented (type registry commented out); needs a .NET SDK. |
| TW-style `Mod.xml` + `mod-game 1.9` mod stream | KW has no `mods\<name>\data\mod.manifest` loader. |
| `CNC3EP1.exe -modConfig <skudef>` (direct or via Steam launch options) | The stub forwards it to `cnc3ep1.dat` **and appends `-config <stock SkuDef>`**; the mod is never applied. Verified with KWBandage: window title stayed stock. Independent of `mod-game 1.02` / `1.2`, CRLF, path characters, `add-big` relative/absolute. |
| `CNC3EP1.exe -ui` (Control Center) | Opens, but KW's Control Center has no Mods tab (the `Launcher:ModTab` string is a leftover). |
| Running `cnc3ep1.dat` directly | Exits immediately; needs the stub. |
| `mod.str` (TW mod-string mechanism) | Never loaded. Strings resolve only from `cnc3.csf` / `cnc3.str`. |
| WrathEd `-lowlod:` shortcut + `_mod` version | Produced `static_mod` streams that the engine did not pick up. Use the two-pass `_common_mod` recipe. |
| File-lock test ("is the .big open?") | Not a valid load signal: stream `.big`s are read once and closed. Use a data-driven marker instead. |

## Useful verification tricks

* **Load marker without playing:** `GUI:FullGameName` is the game window title
  (`Command & Conquer(tm) 3: Kane's Wrath`). Override it in `cnc3.str` and read
  the title of the `cnc3ep1.dat` window with `EnumWindows` — no in-game action
  needed.
* **Personality visible-change test:** override `5RandomOverlord` with
  `PersonalityUIName="Personality:Test"` — "Steamroller" becomes "TEST".
* **Process command line:** `Get-CimInstance Win32_Process | ? Name -match cnc3ep1`
  shows exactly what the stub passed to the game.
* WrathEd logs: `Documents\WrathEd\Logs\`. Note WrathEd is a GUI-subsystem exe:
  run it with `Start-Process -Wait`, and never without arguments (opens BigView).

## Facts about the engine data

* The five stock dropdown entries are `1RandomOptimal` ("Balanced"),
  `2RandomOffensive` ("Rusher"), `3RandomDefensive` ("Turtle"),
  `4RandomGuerilla`, `5RandomOverlord` ("Steamroller") — `Side=Null` wrappers
  with a `PersonalityMap` per faction, in `SkirmishAI/Personalities/RandomPersonalities.xml`.
* Personalities live in the **static** stream (`Static.xml` →
  `SkirmishAI/SkirmishAIIncludes.xml` → `Personalities/PersonalityList.xml`).
* `CNC3EP1.exe` (13 MB) is the Control Center + stub; `RetailExe\1.2\cnc3ep1.dat`
  is the game. The registry key
  `HKLM\SOFTWARE\WOW6432Node\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath`
  holds `InstallPath` and `UserDataLeafName` (`Command & Conquer 3 Kane's Wrath`, with apostrophe).
* Stock `.SkuDef`/`config.txt` files are CRLF, ASCII.
