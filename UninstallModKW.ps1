<#
.SYNOPSIS
    Removes the Commander mod loader from the Kane's Wrath installation and the
    installed .big files, restoring the unmodified game.
#>
[CmdletBinding()]
param(
    [string]$ModName  = 'Commander',
    [string]$GamePath,
    [string]$Language = 'english'
)
$ErrorActionPreference = 'Stop'
$userLeaf = 'Command & Conquer 3 Kane''s Wrath'
foreach ($k in @(
    'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath',
    'HKLM:\SOFTWARE\Electronic Arts\Electronic Arts\Command and Conquer 3 Kanes Wrath')) {
    if (Test-Path $k) {
        $p = Get-ItemProperty $k
        if (-not $GamePath -and $p.InstallPath) { $GamePath = $p.InstallPath }
        if ($p.UserDataLeafName) { $userLeaf = $p.UserDataLeafName }
        break
    }
}
if ($GamePath) {
    $sku = Join-Path $GamePath.TrimEnd('\') "CNC3EP1_${Language}_1.3.SkuDef"
    if (Test-Path $sku) { Remove-Item $sku -Force; Write-Host "Removed $sku" } else { Write-Host "No loader found at $sku" }
}
$dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "$userLeaf\Mods\$ModName"
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force; Write-Host "Removed $dir" }
Write-Host 'Done.'
