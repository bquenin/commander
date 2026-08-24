# Commander

A skirmish AI mod for **Command & Conquer 3: Kane's Wrath** (1.02).

Goal: a non-cheating AI that gives seasoned players a better challenge than the
stock *Hard* difficulty. Playable locally, or online when every player has the
same mod installed.

> The original 2016 Tiberium Wars version of this mod lives on the
> [`archive`](../../tree/archive) branch. It is not maintained.

## Status

Pipeline proof: the mod builds and installs, and adds one GDI personality,
*Commander*, to the skirmish AI dropdown. It is currently a copy of the
stock `1GDIOptimal` personality with a new id — the AI design work has not
started yet.

## Build & install

Requirements: Kane's Wrath 1.02 installed (the build reads one manifest out of
the installation; nothing in it is modified), PowerShell 5.1 or 7+, .NET
Framework 4.x (stock on Windows 10/11).

```powershell
git clone https://github.com/bquenin/commander.git
cd commander
.\BuildModKW.ps1                       # defaults to -ModName Commander -ModVersion 1.0
.\BuildModKW.ps1 -GamePath "D:\Games\Command and Conquer 3 - Kane's Wrath"
```

The script builds and installs to
`Documents\Command & Conquer 3 Kane's Wrath\Mods\Commander\`. Start the game,
pick the mod in the launcher's mod list, then in a skirmish set an opponent's AI
to *Commander*.

## Layout

```
Mods/Commander/
    Data/Static.xml                                        stream root
    Data/SkirmishAI/Personalities/GDICommander.xml     the personality
    Misc/Data/mod.str                                      "Commander" UI string
Mods/Commander_1.0.skudef                              reference copy of the skudef
BuildModKW.ps1                                             build + install
Tools/WrathEd/                                             vendored compiler (GPL v3)
Tools/MakeBig.exe                                          EA .big packer
```

## How a Kane's Wrath mod is built

Tiberium Wars 1.9 loads an extra asset stream from
`mods\<name>\data\mod.manifest` and a `.skudef` that starts with `mod-game 1.9`.
**Kane's Wrath has neither** — there is no mod-stream loader in the engine and KW
`.skudef` files contain only `add-big` lines.

A Kane's Wrath mod is instead a **patch of the game's own `static` stream**:

1. `Data\Static.xml` is compiled against the shipped
   `Core\1.2\patch2.big : data\static_common_2.manifest` as the base patch stream.
2. The compiler emits `Static_mod.manifest` / `.bin` / `.imp` / `.relo`, plus a
   `Static.version` file containing `_mod`.
3. Those go into `<Mod>_<Version>_Streams.big`. Once the `.big` is on the search
   path its `Data\Static.version` shadows the game's, so the engine loads
   `Data\Static_mod.manifest`, which chains back to `static_common_2`.
4. `Mods\<Mod>\Misc\**` is packed into `<Mod>_<Version>_Misc.big` (string tables).

EA's Tiberium Wars `BinaryAssetBuilder.exe` **cannot** build this: it writes
Tiberium Wars asset type-version hashes into the manifest and the KW engine
aborts with *"Type hash mismatch for type ..."*. The build therefore uses the
community compiler WrathEd — see [`Tools/WrathEd/README.md`](Tools/WrathEd/README.md).

## References

The Kane's Wrath XML and schema sources the personality was derived from are
EA's public [CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support)
release (`Kanes Wrath/Xml/SkirmishAI/`). They are not needed to build and are
not vendored here.

## Compatibility notes

* The mod changes the asset manifest, so replays recorded with it will not play
  back on a stock install, and online games require every player to run the
  identical `.big`.
* The build is pinned to patch 1.02 (`Core\1.2\patch2.big`); on other versions
  the script stops with a clear error.
