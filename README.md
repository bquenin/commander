# Commander

A skirmish AI mod for **Command & Conquer 3: Kane's Wrath** (1.02).

Goal: a non-cheating AI that gives seasoned players a better challenge than the
stock *Hard* difficulty. Playable locally, or online when every player has the
same mod installed.

> The original 2016 Tiberium Wars version of this mod lives on the
> [`archive`](../../tree/archive) branch. It is not maintained.

## Status

Pipeline proof: the mod builds, installs and shows up in the game — the skirmish
AI Personality dropdown gets a *Commander* entry. It is currently a copy of the
stock `1GDIOptimal` personality with a new id; the AI design work has not
started yet.

## Build & install

Requirements: Kane's Wrath 1.02 installed (Steam build tested), PowerShell 5.1
or 7+, .NET Framework 4.x (stock on Windows 10/11).

```powershell
git clone https://github.com/bquenin/commander.git
cd commander
.\BuildModKW.ps1                       # -ModName Commander -ModVersion 1.0 -Language english
.\BuildModKW.ps1 -GamePath "D:\Games\Command and Conquer 3 - Kane's Wrath"
```

Then start the game normally and, in a skirmish, set an opponent's AI
personality to *Commander*.

The script installs the `.big` files under
`Documents\Command & Conquer 3 Kane's Wrath\Mods\Commander\` and writes one
file into the game folder, `CNC3EP1_english_1.3.SkuDef`, which makes the game
load them. **While that file exists the mod is always active**, including in
online games — run `.\UninstallModKW.ps1` to remove it and get the stock game
back.

## Layout

```
Mods/Commander/
    Data/Static.xml                                        stream root
    Data/SkirmishAI/Personalities/GDICommander.xml         the GDI personality
    Data/SkirmishAI/Personalities/RandomCommander.xml      side-agnostic entry mapping each faction to a personality
    Strings/english.str                                    the mod's UI strings
BuildModKW.ps1                                             build + install
UninstallModKW.ps1                                         remove the mod from the game
Tools/WrathEd/                                             vendored compiler (GPL v3)
Tools/MakeBig.exe                                          EA .big packer
```

## How a Kane's Wrath mod is built and loaded

Everything below was established empirically on the Steam build, cross-checked
against [KWBandage](https://github.com/theHostileNegotiator/KWBandage), a
community mod built with the same tools.

**Data** — a mod is a *patch* of the game's own `static` stream:

1. `Data\Static.xml` is compiled with WrathEd against the shipped
   `Core\1.2\patch2.big : data\static_common_2.manifest` as the base patch
   stream, producing `static_common_mod.{manifest,bin,imp,relo}`; a second pass
   against `static_l_common_2.manifest` produces the low-LOD
   `static_l_common_mod` stream.
2. `data\static.version` / `static_l.version` containing `_common_mod` are
   packed alongside; they shadow the game's own `_common_2` so the engine loads
   the mod streams, which chain back to the stock ones. Everything goes into
   `<Mod>_<Version>_Streams.big`.
3. Existing assets can be overridden by redeclaring them with the same id.

**Strings** — Kane's Wrath does *not* load a `mod.str`. UI strings come from
`cnc3.csf` in the language `.big`, and a `data\cnc3.str` replaces the whole
table. The build converts the game's `cnc3.csf` to `.str`, appends
`Mods\<Mod>\Strings\<language>.str`, and packs the result as
`<Mod>_<Version>_<language>.big`.

**Loading** — the Steam build's `CNC3EP1.exe` ignores `-modConfig` (verified
with KWBandage as a control), and its Control Center (`-ui`) has no Mods tab.
What it does do is launch the highest `CNC3EP1_<language>_<version>.SkuDef` in
the game folder. So the installer writes a `1.3` one:

```
set-exe RetailExe\1.2\cnc3ep1.dat
add-big <Documents>\...\Mods\Commander\Commander_1.0_english.big
add-big <Documents>\...\Mods\Commander\Commander_1.0_Streams.big
add-config CNC3EP1_english_1.2.SkuDef
```

Entries listed first take priority, so the mod's `.big` files go before the
stock configuration.

**Skirmish AI dropdown** — it lists every `AIPersonalityDefinition` with
`SkirmishPersonality="true"`, de-duplicated by `PersonalityUIName`. The stock
five entries are side-agnostic wrappers (`Side=Null` + a `PersonalityMap` per
faction) — `RandomCommander.xml` follows the same pattern, mapping GDI to
`GDICommander` and the other factions to their stock *Balanced* personality
until they get their own.

**Why WrathEd** — EA's Tiberium Wars `BinaryAssetBuilder.exe` cannot build
this: it writes Tiberium Wars asset type-version hashes into the manifest and
the KW engine aborts with *"Type hash mismatch for type ..."*. See
[`Tools/WrathEd/README.md`](Tools/WrathEd/README.md).

## References

The Kane's Wrath XML and schema sources the personality was derived from are
EA's public [CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support)
release (`Kanes Wrath/Xml/SkirmishAI/`). They are not needed to build and are
not vendored here.

## Compatibility notes

* The mod changes the asset manifest, so replays recorded with it will not play
  back on a stock install, and online games require every player to run the
  identical `.big` files.
* The build is pinned to patch 1.02 (`Core\1.2\patch2.big`); on other versions
  the script stops with a clear error.
* Only the `english` language table is generated by default; pass
  `-Language <name>` for another installed language.
