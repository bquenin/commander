# WrathEd (vendored)

These are the pre-built binaries and Kane's Wrath game definition of **WrathEd**,
the community SAGE asset compiler used by `BuildModKW.ps1`.

* Upstream author: Bibber (Thundermods.net); later edits by Jenkins87 / JMDigital,
  Darth Jane, JonWil, theHostileNegotiator, TheFilthyCasual.
* Obtained from the *Kane's Wrath Mod SDK 2020* bundle:
  <https://github.com/JenkinsTR/KanesWrath-MODSDK-2020> (`Tools/`).
* Version: see `version.txt` (1.10).
* Licence: **GNU GPL v3** - see `COPYING`. It applies to WrathEd, not to the rest
  of this repository.

## Why this and not EA's `BinaryAssetBuilder.exe`

EA's `BinaryAssetBuilder.exe` is the Tiberium Wars pipeline. Driven with the
Kane's Wrath schemas it produces byte-identical *instance data* to the shipped
Kane's Wrath assets, but it stamps **Tiberium Wars** asset type-version hashes
into the stream manifest (`AllTypesHash 0xEB19D975`, e.g. `AIPersonalityDefinition
0x7DCE182F`). The Kane's Wrath engine carries a compiled-in table of the values it
expects (`AllTypesHash 0x12B3E763`, `AIPersonalityDefinition 0xC360B65B`) and
aborts with *"Type hash mismatch for type ..."* on anything else. WrathEd knows
the Kane's Wrath values, so it is the tool that works.

## Contents

Only what the command-line compile needs is vendored:

* `WrathEd.exe`, `WrathEdControls.dll`, `SAGE*.dll`, `Files.dll`, `Dds.dll`,
  `EALA.Hash.dll`, `Mvp.Xml.dll`, `EALayer3.exe`
* `Localization\WrathEd.csf` (required at startup)
* `Games\Kane's Wrath.xml` + `Games\Kane's Wrath\` + `Games\Schema\` (asset type
  definitions)

The four compiled game-data streams that the upstream bundle also ships inside
`Games\Kane's Wrath\` (`static_2.manifest`, `global_2.manifest`,
`worldbuilder_2.manifest`, `stringhashes.bin`) are **not** vendored - they are EA
game data and are not needed for a command-line compile. `BuildModKW.ps1` reads
the one manifest it needs straight out of your own game installation instead.

## Note

Run `WrathEd.exe` only with command-line arguments. Started with no arguments it
opens its BigView GUI.
