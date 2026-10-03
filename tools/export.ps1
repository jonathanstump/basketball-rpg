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
function Invoke-Export($t) {
    # Remove the previous build first: overwriting an .exe that Windows (or an
    # antivirus scan) still has open makes Godot's resource step fail with
    # ERR_CANT_OPEN, leaving an .exe without its name/version info.
    foreach ($old in @($t.path, [IO.Path]::ChangeExtension($t.path, ".pck"))) {
        if (Test-Path $old) { Remove-Item -Force $old -ErrorAction SilentlyContinue }
    }
    $p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", ".", "--export-release", "`"$($t.preset)`"", $t.path) -NoNewWindow -PassThru
    Add-GuardedProcess $p
    if (-not $p.WaitForExit(1800 * 1000)) { Stop-ProcessTree $p }
    $p.WaitForExit()
    return $p.ExitCode
}
foreach ($t in $targets) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $t.path) | Out-Null
    $code = Invoke-Export $t
    $isWin = $t.path.EndsWith(".exe")
    if ($code -eq 0 -and $isWin -and (Test-Path $t.path) -and (Get-Item $t.path).VersionInfo.ProductName -ne "Concrete Crown") {
        Write-Host "  retrying $($t.preset): the .exe is missing its product info"
        Start-Sleep -Seconds 2
        $code = Invoke-Export $t
    }
    if ($code -ne 0 -or -not (Test-Path $t.path)) {
        Write-Host "EXPORT FAIL $($t.preset)"
        $failed++
    }
    elseif ($isWin -and (Get-Item $t.path).VersionInfo.ProductName -ne "Concrete Crown") {
        Write-Host "EXPORT FAIL $($t.preset): no product info in the .exe"
        $failed++
    }
    else {
        Write-Host "EXPORT OK $($t.preset) -> $($t.path)"
    }
}
exit $failed
