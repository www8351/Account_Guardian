# Phase 0 test harness for AccountGuardian.
# Drives the JustMarkets demo terminal: kill, relaunch with a startup config,
# collect the EA journal (MQL5\Logs) lines for the run.
#
# STATUS 2026-07-29: the /config startup-attach path is DEFECTIVE and its cause
# is UNKNOWN. Experts loaded through it never executed. Do not use Start-Terminal
# with a SetFile, and do not use Invoke-AgRun, until that is diagnosed.
#
# The hard-kill rows do not need it: the EA is attached in the saved chart
# profile, so Stop-Terminal followed by a plain launch of terminal64.exe restores
# the attachment. Use Stop-Terminal, Get-AgLogMark and Get-AgLogSince only.
$ErrorActionPreference = "Stop"

$TermExe  = "C:\Program Files\MetaTrader 5\terminal64.exe"
$DataDir  = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
$Presets  = "$DataDir\MQL5\Presets"
$AgFiles  = "$DataDir\MQL5\Files\AccountGuardian"
$Tmp      = "$env:USERPROFILE\.claude\jobs\4afd0c2a\tmp"

function Stop-Terminal {
    param([switch]$Hard)
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) {
        if ($Hard) { $p | Stop-Process -Force } else { $p | Stop-Process -Force }
        Start-Sleep -Seconds 2
    }
}

function New-SetFile {
    param([string]$Name, [hashtable]$Params)
    New-Item -ItemType Directory -Force $Presets | Out-Null
    $lines = @()
    foreach ($k in $Params.Keys) { $lines += "$k=$($Params[$k])" }
    $path = Join-Path $Presets "$Name.set"
    Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding ASCII
    return "$Name.set"
}

function Get-AgLogPath {
    $d = "$DataDir\MQL5\Logs"
    $today = Get-Date -Format "yyyyMMdd"
    return "$d\$today.log"
}

function Get-AgLogMark {
    $p = Get-AgLogPath
    if (Test-Path $p) { return (Get-Content $p -Encoding Unicode).Count } else { return 0 }
}

function Get-AgLogSince {
    param([int]$Mark)
    $p = Get-AgLogPath
    if (-not (Test-Path $p)) { return @() }
    $all = Get-Content $p -Encoding Unicode
    if ($all.Count -le $Mark) { return @() }
    return $all[$Mark..($all.Count - 1)] | Where-Object { $_ -match "AccountGuardian|AG\|" }
}

function Start-Terminal {
    param([string]$SetFile = "", [string]$Symbol = "EURUSD", [string]$Period = "M1")
    $cfg = Join-Path $Tmp "startup.ini"
    $body = @("[Experts]", "Enabled=1", "AllowLiveTrading=0", "AllowDllImport=0", "",
              "[StartUp]", "Expert=AccountGuardian\AccountGuardian", "Symbol=$Symbol", "Period=$Period")
    if ($SetFile -ne "") { $body += "ExpertParameters=$SetFile" }
    Set-Content -Path $cfg -Value ($body -join "`r`n") -Encoding Unicode
    Start-Process -FilePath $TermExe -ArgumentList "/config:$cfg"
}

function Invoke-AgRun {
    param([string]$SetFile = "", [int]$WaitSeconds = 25)
    $mark = Get-AgLogMark
    Start-Terminal -SetFile $SetFile
    Start-Sleep -Seconds $WaitSeconds
    return Get-AgLogSince -Mark $mark
}
