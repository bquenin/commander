<#
.SYNOPSIS
    Builds a Command & Conquer 3: Kane's Wrath skirmish-AI mod and installs it
    into the user's Kane's Wrath Mods folder.

.DESCRIPTION
    Kane's Wrath does NOT support the Tiberium Wars 1.9 style "mods\<name>\data\mod.manifest"
    extra asset stream (the KW engine has no such loader).  A KW mod is instead a PATCH
    of the game's own "static" stream:

      1. The shipped manifest  Core\1.2\patch2.big : data\static_common_2.manifest
         is extracted from the installed game and used as the base patch stream.
      2. WrathEd compiles Mods\<Mod>\Data\Static.xml against that base and emits
         Static_mod.manifest / .bin / .imp / .relo plus a Static.version file
         containing "_mod".
      3. Those files are packed into <Mod>_<Version>_Streams.big.  When the .big is
         on the search path its Data\Static.version shadows the game's, so the engine
         loads Data\Static_mod.manifest -- which chains back to static_common_2.
      4. Mods\<Mod>\Misc\** is packed into <Mod>_<Version>_Misc.big (string tables etc).
      5. Both .big files and the .skudef are copied to
         Documents\<UserDataLeafName>\Mods\<Mod>\.

    EA's Tiberium Wars BinaryAssetBuilder.exe cannot be used for
    Kane's Wrath: it stamps Tiberium Wars asset type-version hashes into the manifest
    and the KW engine rejects those with "Type hash mismatch for type ...".

.PARAMETER ModName
    Folder name under Mods\.  Default: Commander

.PARAMETER ModVersion
    Version string used in the .big / .skudef file names.  Default: 1.0

.PARAMETER GamePath
    Kane's Wrath installation directory.  Default: read from the registry.

.EXAMPLE
    .\BuildModKW.ps1
    .\BuildModKW.ps1 -ModName Commander -ModVersion 1.0
#>
[CmdletBinding()]
param(
    [string]$ModName    = 'Commander',
    [string]$ModVersion = '1.0',
    [string]$GamePath
)

$ErrorActionPreference = 'Stop'
$root      = $PSScriptRoot
$modSrc    = Join-Path $root "Mods\$ModName"
$wrathEd   = Join-Path $root 'Tools\WrathEd\WrathEd.exe'
$makeBig   = Join-Path $root 'Tools\MakeBig.exe'
$buildRoot = Join-Path $root 'BuiltModsKW'
$baseMan   = Join-Path $buildRoot 'GameFiles\Manifest\static_common_2.manifest'
$outData   = Join-Path $buildRoot "Mods\$ModName\Data"

function Fail([string]$m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $modSrc))                        { Fail "Mod source not found: $modSrc" }
if (-not (Test-Path (Join-Path $modSrc 'Data\Static.xml'))) { Fail "Missing $modSrc\Data\Static.xml" }
if (-not (Test-Path $wrathEd))                       { Fail "Missing $wrathEd" }
if (-not (Test-Path $makeBig))                       { Fail "Missing $makeBig" }

# ---------------------------------------------------------------- locate game
if (-not $GamePath) {
    foreach ($k in @(
        'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath',
        'HKLM:\SOFTWARE\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath')) {
        if (Test-Path $k) { $GamePath = (Get-ItemProperty $k).InstallPath; break }
    }
}
if (-not $GamePath -or -not (Test-Path $GamePath)) {
    Fail "Kane's Wrath installation not found. Pass -GamePath 'C:\...\Command and Conquer 3 - Kane''s Wrath'"
}
$GamePath = $GamePath.TrimEnd('\')
Write-Host "Game        : $GamePath"

# ------------------------------------------------- user data (Documents) path
$userLeaf = 'Command & Conquer 3 Kane''s Wrath'
foreach ($k in @(
    'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath',
    'HKLM:\SOFTWARE\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath')) {
    if (Test-Path $k) {
        $v = (Get-ItemProperty $k).UserDataLeafName
        if ($v) { $userLeaf = $v }
        break
    }
}
$installDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "$userLeaf\Mods\$ModName"
Write-Host "Install to  : $installDir"

# ------------------------------- BIG reader + RefPack (EA compression) decoder
Add-Type -TypeDefinition @'
using System;
using System.IO;

public static class SageBig
{
    static uint BE(byte[] b, int o) {
        return (uint)((b[o] << 24) | (b[o+1] << 16) | (b[o+2] << 8) | b[o+3]);
    }

    // Extract one entry (by name, case-insensitive) from a BIGF/BIG4 archive.
    public static byte[] Extract(string bigPath, string entryName)
    {
        using (FileStream fs = File.OpenRead(bigPath))
        {
            byte[] hdr = new byte[16];
            fs.Read(hdr, 0, 16);
            string magic = System.Text.Encoding.ASCII.GetString(hdr, 0, 4);
            if (magic != "BIGF" && magic != "BIG4")
                throw new Exception("Not a BIG archive: " + bigPath);
            uint count = BE(hdr, 8);
            byte[] e = new byte[8];
            for (uint i = 0; i < count; i++)
            {
                fs.Read(e, 0, 8);
                uint off = BE(e, 0), size = BE(e, 4);
                MemoryStream nm = new MemoryStream();
                int c;
                while ((c = fs.ReadByte()) > 0) nm.WriteByte((byte)c);
                string name = System.Text.Encoding.ASCII.GetString(nm.ToArray());
                if (string.Equals(name, entryName, StringComparison.OrdinalIgnoreCase))
                {
                    byte[] data = new byte[size];
                    fs.Seek(off, SeekOrigin.Begin);
                    int read = 0;
                    while (read < size) read += fs.Read(data, read, (int)size - read);
                    return data;
                }
            }
        }
        throw new Exception("Entry not found in BIG: " + entryName);
    }

    public static bool IsRefPack(byte[] d) { return d.Length > 2 && d[1] == 0xFB; }

    // EA RefPack decompression.
    public static byte[] Decompress(byte[] d)
    {
        int p = 0;
        byte b0 = d[0];
        p = 2;
        if ((b0 & 0x01) != 0) p += ((b0 & 0x80) != 0) ? 4 : 3;
        int usize;
        if ((b0 & 0x80) != 0) { usize = (d[p]<<24)|(d[p+1]<<16)|(d[p+2]<<8)|d[p+3]; p += 4; }
        else                  { usize = (d[p]<<16)|(d[p+1]<<8)|d[p+2];               p += 3; }

        byte[] outBuf = new byte[usize];
        int o = 0;
        while (true)
        {
            int c = d[p++]; int run, off, cnt;
            if (c < 0x80) {
                int a = d[p++];
                run = c & 3;
                Array.Copy(d, p, outBuf, o, run); p += run; o += run;
                off = ((c & 0x60) << 3) + a + 1;
                cnt = ((c >> 2) & 7) + 3;
            } else if (c < 0xC0) {
                int a = d[p], b = d[p+1]; p += 2;
                run = (a >> 6) & 3;
                Array.Copy(d, p, outBuf, o, run); p += run; o += run;
                off = ((a & 0x3F) << 8) + b + 1;
                cnt = (c & 0x3F) + 4;
            } else if (c < 0xE0) {
                int a = d[p], b = d[p+1], e = d[p+2]; p += 3;
                run = c & 3;
                Array.Copy(d, p, outBuf, o, run); p += run; o += run;
                off = ((c & 0x10) << 12) + (a << 8) + b + 1;
                cnt = ((c & 0x0C) << 6) + e + 5;
            } else if (c < 0xFC) {
                run = ((c & 0x1F) << 2) + 4;
                Array.Copy(d, p, outBuf, o, run); p += run; o += run;
                continue;
            } else {
                run = c & 3;
                Array.Copy(d, p, outBuf, o, run); p += run; o += run;
                break;
            }
            int s = o - off;
            for (int i = 0; i < cnt; i++) outBuf[o++] = outBuf[s++];
        }
        if (o != usize) throw new Exception("RefPack size mismatch");
        return outBuf;
    }
}
'@

# ------------------------------------------- extract the game's base manifest
if (-not (Test-Path $baseMan)) {
    $patchBig = Join-Path $GamePath 'Core\1.2\patch2.big'
    $entry    = 'data\static_common_2.manifest'
    if (-not (Test-Path $patchBig)) {
        Fail "Not found: $patchBig  (Kane's Wrath 1.02 / patch2 is required)"
    }
    Write-Host "Extracting  : $entry"
    New-Item -ItemType Directory -Force (Split-Path $baseMan) | Out-Null
    $raw = [SageBig]::Extract($patchBig, $entry)
    if ([SageBig]::IsRefPack($raw)) { $raw = [SageBig]::Decompress($raw) }
    [IO.File]::WriteAllBytes($baseMan, $raw)
    Write-Host "              -> $($raw.Length) bytes"
} else {
    Write-Host "Base stream : $baseMan (cached)"
}

# ------------------------------------------------------------------- compile
if (Test-Path (Join-Path $buildRoot "Mods\$ModName")) {
    Remove-Item -Recurse -Force (Join-Path $buildRoot "Mods\$ModName")
}
New-Item -ItemType Directory -Force $outData | Out-Null

Write-Host "Compiling   : Mods\$ModName\Data\Static.xml"
# WrathEd.exe is a WPF (GUI subsystem) executable, so the shell does not block on
# it -- Start-Process -Wait is required, otherwise the outputs are checked too early.
# It briefly shows a compile-progress window and closes itself when finished.
$q = '"'
$argLine = @(
    "$q-gameDefinition:Kane's Wrath$q"
    "$q-compile:$modSrc\Data\Static.xml$q"
    "$q-art:..\Art$q"
    "$q-audio:..\Audio$q"
    "$q-out:$outData$q"
    "$q-version:_mod$q"
    "$q-bps:static_common_2.manifest,$baseMan$q"
    "$q-lowlod:static_mod.manifest$q"
) -join ' '
# -WorkingDirectory keeps WrathEd's stringhashes.xml by-product out of the repo root.
Start-Process -FilePath $wrathEd -ArgumentList $argLine -WorkingDirectory $buildRoot `
              -Wait -NoNewWindow | Out-Null

if (-not (Test-Path (Join-Path $outData 'Static_mod.manifest'))) {
    Fail "WrathEd did not produce Static_mod.manifest. See Documents\WrathEd\Logs\ for details."
}

# The stringhashes stream is a build by-product; shipping it would replace the
# game's own data\stringhashes.* .  The official SDK does not pack it either.
Get-ChildItem $outData -Filter 'stringhashes.*' -ErrorAction SilentlyContinue | Remove-Item -Force

# ---------------------------------------------------------------- verify hash
$man  = [IO.File]::ReadAllBytes((Join-Path $outData 'Static_mod.manifest'))
$all  = [BitConverter]::ToUInt32($man, 8)
if ($all -ne 0x12B3E763) {
    Fail ("AllTypesHash is 0x{0:X8}, expected 0x12B3E763 (Kane's Wrath 1.02). Wrong compiler/game definition." -f $all)
}
Write-Host ("AllTypesHash: 0x{0:X8}  (Kane's Wrath 1.02 - OK)" -f $all)

# ------------------------------------------------------------------- package
$streamsBig = Join-Path $buildRoot "${ModName}_${ModVersion}_Streams.big"
$miscBig    = Join-Path $buildRoot "${ModName}_${ModVersion}_Misc.big"

Write-Host "Packing     : $streamsBig"
Remove-Item $streamsBig -Force -ErrorAction SilentlyContinue
& $makeBig -f (Join-Path $buildRoot "Mods\$ModName") "-o:$streamsBig" | Out-Null
if (-not (Test-Path $streamsBig)) { Fail "MakeBig did not produce $streamsBig" }

$miscSrc = Join-Path $modSrc 'Misc'
if (Test-Path $miscSrc) {
    Write-Host "Packing     : $miscBig"
    Remove-Item $miscBig -Force -ErrorAction SilentlyContinue
    & $makeBig -f $miscSrc "-o:$miscBig" | Out-Null
}

# ------------------------------------------------------------------- install
New-Item -ItemType Directory -Force $installDir | Out-Null
Copy-Item $streamsBig $installDir -Force
if (Test-Path $miscBig) { Copy-Item $miscBig $installDir -Force }
$skudefOut = Join-Path $installDir "${ModName}_${ModVersion}.skudef"

# skudef: use the checked-in one if present, otherwise generate one add-big line
# per .big that was actually produced. KW skudefs hold add-big lines only - there
# is no "mod-game" directive (that is a Tiberium Wars 1.9 thing).
$skudefSrc = Join-Path $root "Mods\${ModName}_${ModVersion}.skudef"
if (Test-Path $skudefSrc) {
    Copy-Item $skudefSrc $skudefOut -Force
} else {
    $lines = @()
    if (Test-Path $streamsBig) { $lines += "add-big ${ModName}_${ModVersion}_Streams.big" }
    if (Test-Path $miscBig)    { $lines += "add-big ${ModName}_${ModVersion}_Misc.big" }
    Set-Content -Path $skudefOut -Value $lines -Encoding ascii
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Get-ChildItem $installDir | ForEach-Object { '  {0,12:N0}  {1}' -f $_.Length, $_.Name }
Write-Host ''
Write-Host 'Launch the game, pick the mod in the launcher''s mod list, then'
Write-Host 'Skirmish -> set an opponent''s AI personality to "Commander".'
