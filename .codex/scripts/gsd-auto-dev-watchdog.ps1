[CmdletBinding()]
param(
    [string]$RunnerPath = "$env:USERPROFILE\.codex\scripts\gsd-auto-dev-e2e.ps1",
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$RoadmapPath = ".planning/ROADMAP.md",
    [string]$StatePath = ".planning/STATE.md",
    [string]$StatusFile = ".planning/agent-output/gsd-e2e-status.log",
    [string]$WatchdogLogFile = ".planning/agent-output/gsd-watchdog.log",
    [int]$PollSeconds = 30,
    [int]$StaleSeconds = 120,
    [int]$StartupGraceSeconds = 120,
    [int]$RestartDelaySeconds = 5,
    [int]$MaxRestartsPerHour = 20,
    [int]$AutoDevMaxCycles = 20,
    [int]$MaxOuterLoops = 500,
    [switch]$StrictRoot = $true,
    [int]$HeartbeatSeconds = 300,
    [int]$HeartbeatCheckSeconds = 30,
    [switch]$AllowRun = $true,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
    param(
        [string]$Root,
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $Root $PathValue)
}

function Convert-CimDateToLocal {
    param([object]$CreationDateValue)

    if ($null -eq $CreationDateValue) { return (Get-Date) }
    if ($CreationDateValue -is [datetime]) { return [datetime]$CreationDateValue }

    $text = [string]$CreationDateValue
    if ([string]::IsNullOrWhiteSpace($text)) { return (Get-Date) }

    try {
        return [System.Management.ManagementDateTimeConverter]::ToDateTime($text)
    } catch {
        return (Get-Date)
    }
}

function New-WatchdogMutexName {
    param([string]$ProjectRootValue)

    $key = if ([string]::IsNullOrWhiteSpace($ProjectRootValue)) { "." } else { $ProjectRootValue }
    try { $key = [System.IO.Path]::GetFullPath($key) } catch { }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($key.ToLowerInvariant())
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $hash = $sha1.ComputeHash($bytes)
    } finally {
        $sha1.Dispose()
    }

    $hex = -join ($hash | ForEach-Object { $_.ToString("x2") })
    return ("Global\GsdAutoDevWatchdog_{0}" -f $hex)
}

function Acquire-WatchdogMutex {
    param([string]$ProjectRootValue)

    $name = New-WatchdogMutexName -ProjectRootValue $ProjectRootValue
    $created = $false
    $mutex = $null
    try {
        $mutex = New-Object System.Threading.Mutex($false, $name, [ref]$created)
    } catch {
        return $null
    }

    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(0, $false)
    } catch {
        $acquired = $false
    }

    if (-not $acquired) {
        try { $mutex.Dispose() } catch { }
        return $null
    }

    return $mutex
}

function Get-RunnerProcesses {
    param(
        [string]$RunnerScriptPath,
        [string]$ProjectRootValue
    )

    $rows = @()
    $runnerNamePattern = [regex]::Escape([System.IO.Path]::GetFileName($RunnerScriptPath))
    $watchdogNamePattern = 'gsd-auto-dev-watchdog\.ps1'
    $projectPattern = [regex]::Escape($ProjectRootValue)

    try {
        $rows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.Name -match '^powershell(\.exe)?$' -and
            $_.CommandLine -notmatch $watchdogNamePattern -and
            $_.CommandLine -match $runnerNamePattern -and
            $_.CommandLine -match $projectPattern
        })
    } catch {
        $rows = @()
    }

    return @($rows)
}

function Write-WatchdogLog {
    param(
        [string]$LogPath,
        [string]$Message
    )

    try {
        $parent = Split-Path -Parent $LogPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogPath -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
    } catch { }
}

function Stop-RunnerSet {
    param(
        [object[]]$RunnerRows,
        [string]$Reason,
        [string]$LogPath
    )

    foreach ($row in @($RunnerRows)) {
        $procId = [int]$row.ProcessId
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-WatchdogLog -LogPath $LogPath -Message ("runner-stop pid={0} reason={1}" -f $procId, $Reason)
        } catch {
            Write-WatchdogLog -LogPath $LogPath -Message ("runner-stop-failed pid={0} reason={1}" -f $procId, $Reason)
        }
    }
}

function Start-Runner {
    param(
        [string]$RunnerScriptPath,
        [string]$ProjectRootValue,
        [string]$RoadmapPathValue,
        [string]$StatePathValue,
        [int]$AutoDevMaxCyclesValue,
        [int]$MaxOuterLoopsValue,
        [bool]$StrictRootValue,
        [int]$HeartbeatSecondsValue,
        [int]$HeartbeatCheckSecondsValue,
        [bool]$AllowRunValue,
        [string]$LogPath
    )

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $RunnerScriptPath,
        "-ProjectRoot", $ProjectRootValue,
        "-RoadmapPath", $RoadmapPathValue,
        "-StatePath", $StatePathValue,
        "-AutoDevMaxCycles", [string]$AutoDevMaxCyclesValue,
        "-MaxOuterLoops", [string]$MaxOuterLoopsValue,
        "-HeartbeatSeconds", [string]$HeartbeatSecondsValue,
        "-HeartbeatCheckSeconds", [string]$HeartbeatCheckSecondsValue
    )

    if ($StrictRootValue) { $args += "-StrictRoot" }
    if ($AllowRunValue) { $args += "-AllowRun" }

    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru
    Write-WatchdogLog -LogPath $LogPath -Message ("runner-start pid={0}" -f $proc.Id)
    return $proc
}

function Get-StatusAgeSeconds {
    param([string]$StatusPath)

    if (-not (Test-Path $StatusPath)) { return [double]::PositiveInfinity }

    try {
        $item = Get-Item -Path $StatusPath -ErrorAction Stop
        return ((Get-Date) - $item.LastWriteTime).TotalSeconds
    } catch {
        return [double]::PositiveInfinity
    }
}

$resolvedProjectRoot = (Resolve-Path -Path $ProjectRoot).Path
$resolvedRunnerPath = if ([System.IO.Path]::IsPathRooted($RunnerPath)) { $RunnerPath } else { Resolve-AbsolutePath -Root $resolvedProjectRoot -PathValue $RunnerPath }
$resolvedStatusPath = Resolve-AbsolutePath -Root $resolvedProjectRoot -PathValue $StatusFile
$resolvedWatchdogLogPath = Resolve-AbsolutePath -Root $resolvedProjectRoot -PathValue $WatchdogLogFile

if (-not (Test-Path $resolvedRunnerPath)) {
    throw "Runner script not found: $resolvedRunnerPath"
}

$mutex = Acquire-WatchdogMutex -ProjectRootValue $resolvedProjectRoot
if ($null -eq $mutex) {
    Write-WatchdogLog -LogPath $resolvedWatchdogLogPath -Message "watchdog-skip another watchdog instance is already active"
    return
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try { $mutex.ReleaseMutex() } catch { }
    try { $mutex.Dispose() } catch { }
}

$restartHistory = New-Object System.Collections.Generic.List[datetime]
$poll = [Math]::Max(5, [int]$PollSeconds)
$staleThreshold = [Math]::Max(30, [int]$StaleSeconds)
$startupGrace = [Math]::Max(30, [int]$StartupGraceSeconds)
$restartDelay = [Math]::Max(1, [int]$RestartDelaySeconds)
$restartCap = [Math]::Max(1, [int]$MaxRestartsPerHour)

Write-WatchdogLog -LogPath $resolvedWatchdogLogPath -Message ("watchdog-start project={0} poll_s={1} stale_s={2} startup_grace_s={3}" -f $resolvedProjectRoot, $poll, $staleThreshold, $startupGrace)

while ($true) {
    $now = Get-Date
    $cutoff = $now.AddHours(-1)
    $recentRestarts = @($restartHistory | Where-Object { $_ -ge $cutoff })
    $restartHistory.Clear()
    foreach ($restartAt in $recentRestarts) {
        $restartHistory.Add([datetime]$restartAt) | Out-Null
    }

    $runners = @(Get-RunnerProcesses -RunnerScriptPath $resolvedRunnerPath -ProjectRootValue $resolvedProjectRoot)
    if ($runners.Count -gt 1) {
        $ordered = @($runners | Sort-Object ProcessId)
        $keep = @($ordered | Select-Object -First 1)
        $kill = @($ordered | Select-Object -Skip 1)
        Stop-RunnerSet -RunnerRows $kill -Reason "duplicate-runner" -LogPath $resolvedWatchdogLogPath
        $runners = $keep
    }

    $needsStart = $false
    if ($runners.Count -eq 0) {
        Write-WatchdogLog -LogPath $resolvedWatchdogLogPath -Message "runner-missing restart_requested=true"
        $needsStart = $true
    } else {
        $runner = $runners[0]
        $createdAt = Convert-CimDateToLocal -CreationDateValue $runner.CreationDate
        $runnerAge = ((Get-Date) - $createdAt).TotalSeconds
        $statusAge = Get-StatusAgeSeconds -StatusPath $resolvedStatusPath

        if ($runnerAge -ge $startupGrace -and $statusAge -ge $staleThreshold) {
            Write-WatchdogLog -LogPath $resolvedWatchdogLogPath -Message ("runner-stale pid={0} runner_age_s={1} status_age_s={2} threshold_s={3}" -f $runner.ProcessId, [int][Math]::Round($runnerAge), [int][Math]::Round($statusAge), $staleThreshold)
            Stop-RunnerSet -RunnerRows @($runner) -Reason "stale-status-log" -LogPath $resolvedWatchdogLogPath
            $needsStart = $true
        }
    }

    if ($needsStart) {
        if ($restartHistory.Count -ge $restartCap) {
            Write-WatchdogLog -LogPath $resolvedWatchdogLogPath -Message ("restart-throttled cap_per_hour={0}" -f $restartCap)
        } else {
            $null = Start-Runner `
                -RunnerScriptPath $resolvedRunnerPath `
                -ProjectRootValue $resolvedProjectRoot `
                -RoadmapPathValue $RoadmapPath `
                -StatePathValue $StatePath `
                -AutoDevMaxCyclesValue $AutoDevMaxCycles `
                -MaxOuterLoopsValue $MaxOuterLoops `
                -StrictRootValue ([bool]$StrictRoot) `
                -HeartbeatSecondsValue $HeartbeatSeconds `
                -HeartbeatCheckSecondsValue $HeartbeatCheckSeconds `
                -AllowRunValue ([bool]$AllowRun) `
                -LogPath $resolvedWatchdogLogPath
            $restartHistory.Add((Get-Date)) | Out-Null
            Start-Sleep -Seconds $restartDelay
        }
    }

    if ($Once) { break }
    Start-Sleep -Seconds $poll
}
