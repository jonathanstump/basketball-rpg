# Concrete Crown verification harness (spec §15.16) for Windows PowerShell.
# Usage: powershell -ExecutionPolicy Bypass -File tools/verify.ps1 [--full]
# Godot path: $env:GODOT, else tools/.godot_path, else `godot` on PATH.
param([switch]$Full)
$ErrorActionPreference = 'Continue'
if ($args -contains '--full') { $Full = $true }

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Godot = $env:GODOT
if (-not $Godot -and (Test-Path "$Root/tools/.godot_path")) { $Godot = (Get-Content "$Root/tools/.godot_path" -Raw).Trim() }
if (-not $Godot) { $Godot = 'godot' }

. "$PSScriptRoot/proc_guard.ps1"   # Godot children die with this script (no orphans)

$script:Problems = 0
$Ansi = [regex]'\x1b\[[0-9;]*m'
$ErrLine = [regex]'(?m)^\s*(SCRIPT ERROR|USER ERROR|ERROR|SHADER ERROR):'

function Invoke-Godot([string[]]$GArgs, [int]$TimeoutSec = 900) {
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $Godot -ArgumentList $GArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    Add-GuardedProcess $p
    $timedOut = $false
    if (-not $p.WaitForExit($TimeoutSec * 1000)) { Stop-ProcessTree $p; $timedOut = $true }
    $p.WaitForExit()
    $text = (Get-Content $out -Raw) + "`n" + (Get-Content $err -Raw)
    Remove-Item $out, $err -ErrorAction SilentlyContinue
    $text = $Ansi.Replace([string]$text, '')
    return @{ Code = $p.ExitCode; Out = $text; TimedOut = $timedOut }
}

function Fail([string]$msg) { Write-Host "  FAIL: $msg"; $script:Problems++ }
function Show-Tail([string]$text, [int]$n = 25) {
    ($text -split "`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last $n) | ForEach-Object { Write-Host "    $_" }
}
function Show-Errors([string]$text) {
    ($text -split "`n" | Where-Object { $ErrLine.IsMatch($_) } | Select-Object -First 15) | ForEach-Object { Write-Host "    $_" }
}

Write-Host "== Godot: $Godot"
$ver = Invoke-Godot @('--version') 60
Write-Host ("   version " + $ver.Out.Trim())

Write-Host "== [1/5] Import resources"
$r = Invoke-Godot @('--headless', '--path', '.', '--import') 900
if ($r.TimedOut) { Fail "import timed out" }
elseif ($ErrLine.IsMatch($r.Out)) { Fail "import reported errors"; Show-Errors $r.Out }
else { Write-Host "  ok" }

Write-Host "== [2/5] Data validation + map lint"
$r = Invoke-Godot @('--headless', '--path', '.', '-s', 'res://tools/validate_data.gd') 300
Show-Tail ($r.Out -split "`n" | Where-Object { $_ -match 'DATA PROBLEM|VALIDATE DATA' } | Out-String) 40
if ($r.Code -ne 0 -or $r.Out -notmatch 'VALIDATE DATA: .* 0 problems') { Fail "data validation" ; Show-Errors $r.Out }
$r = Invoke-Godot @('--headless', '--path', '.', '-s', 'res://tools/map_lint.gd') 300
Show-Tail ($r.Out -split "`n" | Where-Object { $_ -match 'MAP' } | Out-String) 40
if ($r.Code -ne 0 -or $r.Out -notmatch 'MAP LINT: .* 0 problems') { Fail "map lint"; Show-Errors $r.Out }

Write-Host "== [3/5] Unit + integration tests (GUT)"
$r = Invoke-Godot @('--headless', '--path', '.', '-s', 'res://addons/gut/gut_cmdln.gd', '-gdir=res://tests', '-ginclude_subdirs', '-gexit') 1800
$summary = ($r.Out -split "`n" | Where-Object { $_ -match '^(Scripts|Tests|Passing Tests|Failing Tests|Risky|Pending|Asserts|Time)\s' })
$summary | ForEach-Object { Write-Host "    $_" }
if ($r.Code -ne 0 -or $r.Out -notmatch 'All tests passed') {
    Fail "GUT tests (exit $($r.Code))"
    ($r.Out -split "`n" | Where-Object { $_ -match '\[Failed\]|FAILED|SCRIPT ERROR|Parse Error|ERROR:' } | Select-Object -First 40) | ForEach-Object { Write-Host "    $_" }
}
elseif ($r.Out -match 'SCRIPT ERROR|Parse Error') { Fail "GUT run printed script errors"; Show-Errors $r.Out }

Write-Host "== [4/5] Smoke scenes"
$smokes = Get-ChildItem -Path "$Root/tests/smoke" -Filter *.tscn | Sort-Object Name
foreach ($s in $smokes) {
    $name = $s.BaseName
    $r = Invoke-Godot @('--headless', '--path', '.', "res://tests/smoke/$($s.Name)", '--quit-after', '900', '--fixed-fps', '60') 600
    if ($r.TimedOut) { Fail "$name timed out" }
    elseif ($ErrLine.IsMatch($r.Out)) { Fail "$name printed errors"; Show-Errors $r.Out }
    elseif ($r.Out -notmatch "SMOKE OK $name") { Fail "$name did not report SMOKE OK"; Show-Tail $r.Out 15 }
    else { Write-Host "  ok  $name" }
}

if ($Full) {
    Write-Host "== [5/5] Full: QA scripts, render smoke, export dry run"
    $qas = Get-ChildItem -Path "$Root/tests/qa" -Filter 'qa_*.gd' | Where-Object { $_.Name -ne 'qa_script.gd' } | Sort-Object Name
    foreach ($q in $qas) {
        $id = $q.BaseName.Substring(3)
        $r = Invoke-Godot @('--headless', '--path', '.', '--fixed-fps', '60', '--', "--qa-run=$id") 1800
        if ($r.Out -match "QA PASS $id" -and -not $ErrLine.IsMatch($r.Out)) { Write-Host "  ok  QA $id" }
        else {
            Fail "QA $id"
            ($r.Out -split "`n" | Where-Object { $_ -match 'QA (PASS|FAIL)' }) | ForEach-Object { Write-Host "    $_" }
            Show-Errors $r.Out
        }
    }
    $hasDisplay = [Environment]::UserInteractive -and -not $env:CC_HEADLESS
    if ($hasDisplay) {
        $r = Invoke-Godot @('--path', '.', '-s', 'res://tools/screenshot.gd') 900
        ($r.Out -split "`n" | Where-Object { $_ -match 'RENDER' }) | ForEach-Object { Write-Host "    $_" }
        if ($r.Out -notmatch 'RENDER DONE' -or $r.Out -match 'RENDER FAIL' -or $ErrLine.IsMatch($r.Out)) { Fail "render smoke"; Show-Errors $r.Out }
        else { Write-Host "  ok  render smoke (screenshots in shots/)" }
    }
    else { Write-Host "  WARNING: no display available; render smoke skipped" }
    $verShort = ($ver.Out.Trim() -split '\.')[0..3] -join '.'
    $tplDir = Join-Path $env:APPDATA "Godot/export_templates/$verShort"
    if ((Test-Path "$tplDir/windows_release_x86_64.exe") -and (Test-Path "$tplDir/linux_release.x86_64")) {
        $ex = Start-Process powershell -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', "`"$Root/tools/export.ps1`"", '-DryRun') -NoNewWindow -PassThru
        Add-GuardedProcess $ex
        $ex.WaitForExit()
        if ($ex.ExitCode -ne 0) { Fail "export dry run" } else { Write-Host "  ok  export dry run" }
    }
    else { Write-Host "  WARNING: export templates not installed at $tplDir; export dry run skipped" }
}

if ($script:Problems -eq 0) {
    Write-Host "VERIFY: ALL GREEN"
    exit 0
}
else {
    Write-Host "VERIFY: FAILED ($($script:Problems) problems)"
    exit 1
}
