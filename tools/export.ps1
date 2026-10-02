# Export Concrete Crown for Windows and Linux into builds/ (spec §16 M14).
# Usage: powershell -ExecutionPolicy Bypass -File tools/export.ps1 [-DryRun]
#   -DryRun  exports to builds/dryrun/ and checks both files exist.
# Needs the Godot export templates for the running version installed
# (Editor > Manage Export Templates, or unpack the official .tpz into
#  %APPDATA%\Godot\export_templates\<version>).
param([switch]$DryRun)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
. "$PSScriptRoot/proc_guard.ps1"   # Godot children die with this script (no orphans)
$Godot = $env:GODOT
if (-not $Godot) { $Godot = (Get-Content "$Root/tools/.godot_path" -Raw).Trim() }
$out = if ($DryRun) { "builds/dryrun" } else { "builds" }
$targets = @(
    @{ preset = "Windows Desktop"; path = "$out/windows/ConcreteCrown.exe" },
    @{ preset = "Linux"; path = "$out/linux/ConcreteCrown.x86_64" }
)
$failed = 0
foreach ($t in $targets) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $t.path) | Out-Null
    $p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", ".", "--export-release", "`"$($t.preset)`"", $t.path) -NoNewWindow -PassThru
    Add-GuardedProcess $p
    if (-not $p.WaitForExit(1800 * 1000)) { Stop-ProcessTree $p }
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -or -not (Test-Path $t.path)) {
        Write-Host "EXPORT FAIL $($t.preset)"
        $failed++
    }
    else {
        Write-Host "EXPORT OK $($t.preset) -> $($t.path)"
    }
}
exit $failed
