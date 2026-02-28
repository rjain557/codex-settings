# gsd-auto-dev-e2e.ps1
# Global end-to-end auto-dev runner with strict-root gates, per-minute progress updates,
# commit/push auto-retry, and final clean confirmation.

[CmdletBinding()]
param(
    [int]$MaxOuterLoops = 500,
    [int]$AutoDevMaxCycles = 20,
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$RoadmapPath = ".planning/ROADMAP.md",
    [string]$StatePath = ".planning/STATE.md",
    [switch]$StrictRoot = $true,
    [string]$ReviewRootRelative = "docs/review",
    [string[]]$SummaryPaths = @(),
    [string]$LogDir = ".planning/agent-output",
    [string]$StatusFile = ".planning/agent-output/gsd-e2e-status.log",
    [int]$HeartbeatSeconds = 60,
    [int]$HeartbeatCheckSeconds = 30,
    [int]$PreflightMaxSeconds = 180,
    [bool]$AutoRecoverOnStop = $true,
    [int]$AutoRecoverMaxRestarts = 40,
    [int]$AutoRecoverDelaySeconds = 15,
    [switch]$ProgressToConsole = $false,
    [switch]$AllowRun = $false,
    [switch]$OpenWindow,
    [switch]$AllowOpenWindow = $false,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:LastReviewProgressSignature = ""
$script:RunnerStartTime = $null
$script:LastReviewFindingKeys = @()
$script:LastPhaseMapByKey = @{}
$script:InstanceMutex = $null
$script:InstanceMutexName = ""

if (-not $AllowRun) {
    Write-Host "Auto-dev execution blocked. Pass -AllowRun to explicitly permit running." -ForegroundColor Yellow
    return
}

function Get-CurrentProcessId {
    return [System.Diagnostics.Process]::GetCurrentProcess().Id
}

function Get-ExistingAutoDevWorkerProcesses {
    $selfPid = Get-CurrentProcessId
    $rows = @()

    try {
        $rows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.ProcessId -ne $selfPid -and
            $_.Name -match '^powershell(\.exe)?$' -and
            (
                $_.CommandLine -match 'run-gsd-e2e-' -or
                $_.CommandLine -match 'gsd-auto-dev-e2e\.ps1'
            )
        })
    } catch {
        $rows = @()
    }

    return @($rows)
}

function Get-SingleInstanceMutexName {
    param([string]$ProjectRootValue)

    $key = if ([string]::IsNullOrWhiteSpace($ProjectRootValue)) { "." } else { $ProjectRootValue }
    try {
        $key = [System.IO.Path]::GetFullPath($key)
    } catch { }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($key.ToLowerInvariant())
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $hash = $sha1.ComputeHash($bytes)
    } finally {
        $sha1.Dispose()
    }

    $hex = -join ($hash | ForEach-Object { $_.ToString("x2") })
    return ("Global\GsdAutoDevE2E_{0}" -f $hex)
}

function Acquire-SingleInstanceGuard {
    param([string]$ProjectRootValue)

    $name = Get-SingleInstanceMutexName -ProjectRootValue $ProjectRootValue
    $script:InstanceMutexName = $name

    $created = $false
    $mutex = $null
    try {
        $mutex = New-Object System.Threading.Mutex($false, $name, [ref]$created)
    } catch {
        return $false
    }

    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(0, $false)
    } catch {
        $acquired = $false
    }

    if (-not $acquired) {
        try { $mutex.Dispose() } catch { }
        return $false
    }

    $script:InstanceMutex = $mutex
    return $true
}

function Release-SingleInstanceGuard {
    if ($script:InstanceMutex) {
        try { $script:InstanceMutex.ReleaseMutex() } catch { }
        try { $script:InstanceMutex.Dispose() } catch { }
        $script:InstanceMutex = $null
    }
}

if ($OpenWindow) {
    if (-not $AllowOpenWindow) {
        Write-Host "OpenWindow launch blocked. Pass -AllowOpenWindow to explicitly permit opening a worker window." -ForegroundColor Yellow
        return
    }

    $existingWorkers = @(Get-ExistingAutoDevWorkerProcesses)
    if ($existingWorkers.Count -gt 0) {
        $ids = @($existingWorkers | Select-Object -ExpandProperty ProcessId)
        Write-Host ("Existing auto-dev worker already running. Skipping new launch. PID(s): {0}" -f ($ids -join ",")) -ForegroundColor Yellow
        return
    }

    $selfPath = $MyInvocation.MyCommand.Path
    if (-not (Test-Path $selfPath)) {
        throw "Cannot relaunch: script path not found ($selfPath)."
    }

    $launcherDir = Join-Path $env:TEMP "codex-gsd-launchers"
    if (-not (Test-Path $launcherDir)) {
        New-Item -ItemType Directory -Path $launcherDir -Force | Out-Null
    }

    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $launcherPath = Join-Path $launcherDir ("run-gsd-e2e-{0}.ps1" -f $stamp)

    $selfEsc = $selfPath.Replace("'", "''")
    $projectEsc = $ProjectRoot.Replace("'", "''")
    $roadmapEsc = $RoadmapPath.Replace("'", "''")
    $stateEsc = $StatePath.Replace("'", "''")
    $logDirEsc = $LogDir.Replace("'", "''")
    $statusEsc = $StatusFile.Replace("'", "''")
    $reviewRootEsc = $ReviewRootRelative.Replace("'", "''")
    $strictLiteral = if ($StrictRoot) { '$true' } else { '$false' }
    $autoRecoverLiteral = if ($AutoRecoverOnStop) { '$true' } else { '$false' }
    $progressToConsoleLiteral = if ($ProgressToConsole) { '$true' } else { '$false' }
    $allowRunLiteral = if ($AllowRun) { '$true' } else { '$false' }
    $summaryLine = ""
    if ($PSBoundParameters.ContainsKey("SummaryPaths")) {
        $summaryItems = @()
        foreach ($sp in @($SummaryPaths)) {
            $summaryItems += ("'{0}'" -f $sp.Replace("'", "''"))
        }
        $summaryLiteral = if ($summaryItems.Count -gt 0) { "@({0})" -f ($summaryItems -join ", ") } else { "@()" }
        $summaryLine = "    SummaryPaths = $summaryLiteral"
    }
    $dryLine = if ($DryRun) { '`$params.DryRun = `$true' } else { '' }

    $launcherContent = @"
`$params = @{
    MaxOuterLoops = $MaxOuterLoops
    AutoDevMaxCycles = $AutoDevMaxCycles
    ProjectRoot = '$projectEsc'
    RoadmapPath = '$roadmapEsc'
    StatePath = '$stateEsc'
    ReviewRootRelative = '$reviewRootEsc'
    LogDir = '$logDirEsc'
    StatusFile = '$statusEsc'
    HeartbeatSeconds = $HeartbeatSeconds
    HeartbeatCheckSeconds = $HeartbeatCheckSeconds
    PreflightMaxSeconds = $PreflightMaxSeconds
    AutoRecoverOnStop = $autoRecoverLiteral
    AutoRecoverMaxRestarts = $AutoRecoverMaxRestarts
    AutoRecoverDelaySeconds = $AutoRecoverDelaySeconds
    StrictRoot = $strictLiteral
    ProgressToConsole = $progressToConsoleLiteral
    AllowRun = $allowRunLiteral
$summaryLine
}
$dryLine
`$maxRestarts = [Math]::Max(0, [int]`$params.AutoRecoverMaxRestarts)
`$restartDelay = [Math]::Max(1, [int]`$params.AutoRecoverDelaySeconds)
`$resolvedStatusPath = if ([System.IO.Path]::IsPathRooted(`$params.StatusFile)) { `$params.StatusFile } else { Join-Path `$params.ProjectRoot `$params.StatusFile }

function Write-SupervisorStatus {
    param(
        [string]`$Message
    )
    try {
        `$statusDir = Split-Path -Parent `$resolvedStatusPath
        if (-not [string]::IsNullOrWhiteSpace(`$statusDir) -and -not (Test-Path `$statusDir)) {
            New-Item -ItemType Directory -Path `$statusDir -Force | Out-Null
        }
        Add-Content -Path `$resolvedStatusPath -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), `$Message)
    } catch { }
}

`$attempt = 1
`$restartsUsed = 0
while (`$true) {
    Write-SupervisorStatus -Message ("supervisor-start attempt={0} auto_recover={1} max_restarts={2} delay_seconds={3}" -f `$attempt, $autoRecoverLiteral, `$maxRestarts, `$restartDelay)
    & '$selfEsc' @params
    `$exitCode = if (`$null -eq `$LASTEXITCODE) { 1 } else { [int]`$LASTEXITCODE }

    if (`$exitCode -eq 0) {
        Write-SupervisorStatus -Message ("supervisor-success attempt={0} exit={1}" -f `$attempt, `$exitCode)
        exit 0
    }

    Write-SupervisorStatus -Message ("supervisor-stop attempt={0} exit={1} action=restart_evaluate" -f `$attempt, `$exitCode)
    if ((-not $autoRecoverLiteral) -or (`$restartsUsed -ge `$maxRestarts)) {
        Write-SupervisorStatus -Message ("supervisor-giveup attempt={0} exit={1} restarts_used={2}" -f `$attempt, `$exitCode, `$restartsUsed)
        exit `$exitCode
    }

    `$restartsUsed++
    Write-SupervisorStatus -Message ("supervisor-restart attempt={0} next_attempt={1} restarts_used={2}/{3} sleep_seconds={4}" -f `$attempt, (`$attempt + 1), `$restartsUsed, `$maxRestarts, `$restartDelay)
    Start-Sleep -Seconds `$restartDelay
    `$attempt++
}
"@
    Set-Content -Path $launcherPath -Value $launcherContent -Encoding UTF8

    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $launcherPath)
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WindowStyle Normal -PassThru
    Write-Host ("Launched gsd-auto-dev-e2e in a new PowerShell window (PID={0})." -f $proc.Id) -ForegroundColor Green
    return
}

if (-not (Acquire-SingleInstanceGuard -ProjectRootValue $ProjectRoot)) {
    $running = @(Get-ExistingAutoDevWorkerProcesses | Select-Object -ExpandProperty ProcessId)
    $pidText = if ($running.Count -gt 0) { ($running -join ",") } else { "unknown" }
    Write-Host ("Another auto-dev worker is already active for this repo lock ({0}). Refusing to start. Existing PID(s): {1}" -f $script:InstanceMutexName, $pidText) -ForegroundColor Yellow
    return
}

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Release-SingleInstanceGuard
}

function Resolve-CodexCommand {
    $cmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $vscodeExtRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
    if (Test-Path $vscodeExtRoot) {
        $candidates = Get-ChildItem -Path $vscodeExtRoot -Directory -Filter "openai.chatgpt-*-win32-x64" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        foreach ($ext in $candidates) {
            $candidate = Join-Path $ext.FullName "bin\windows-x86_64\codex.exe"
            if (Test-Path $candidate) { return $candidate }
        }
    }

    return $null
}

function Ensure-CodexOnPath {
    param([string]$CodexExePath)
    if (-not $CodexExePath) { return }

    $codexDir = Split-Path $CodexExePath -Parent
    if (-not (($env:Path -split ';') -contains $codexDir)) {
        $env:Path = "$env:Path;$codexDir"
    }
}

function Resolve-GitCommand {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles "Git\\cmd\\git.exe"),
        (Join-Path $env:ProgramFiles "Git\\bin\\git.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Git\\cmd\\git.exe"),
        "C:\\Program Files\\Git\\cmd\\git.exe",
        "C:\\Program Files\\Git\\bin\\git.exe",
        "C:\\Program Files (x86)\\Git\\cmd\\git.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    return $null
}

function Ensure-GitOnPath {
    param([string]$GitExePath)
    if (-not $GitExePath) { return }

    $gitDir = Split-Path $GitExePath -Parent
    if (-not (($env:Path -split ';') -contains $gitDir)) {
        $env:Path = "$env:Path;$gitDir"
    }
}

function Convert-WindowsPathToWsl {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }

    $candidate = $PathValue
    try {
        if (Test-Path $PathValue) {
            $candidate = (Resolve-Path -Path $PathValue).Path
        }
    } catch { }

    $output = $null
    try {
        $output = & wsl.exe wslpath -a "$candidate" 2>$null
    } catch {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }

    $rows = @($output)
    if ($rows.Count -eq 0) { return $null }
    return ([string]$rows[0]).Trim()
}

function Resolve-WslCodexPath {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) { return $null }

    $userSegment = $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($userSegment)) { return $null }

    $probe = "ls -1 /mnt/c/Users/{0}/.vscode/extensions/openai.chatgpt-*-win32-x64/bin/linux-x86_64/codex 2>/dev/null | sort | tail -n 1" -f $userSegment
    $output = $null
    try {
        $output = & wsl.exe bash -lc $probe
    } catch {
        return $null
    }

    $rows = @($output)
    if ($rows.Count -eq 0) { return $null }
    $first = [string]$rows[0]
    if ([string]::IsNullOrWhiteSpace($first)) { return $null }

    return $first.Trim()
}

function Resolve-PathFromRoot {
    param(
        [string]$Root,
        [string]$PathValue
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($PathValue)) {
        $PathValue
    } else {
        Join-Path $Root $PathValue
    }

    if (Test-Path $candidate) {
        return (Resolve-Path -Path $candidate).Path
    }

    return [System.IO.Path]::GetFullPath($candidate)
}

function Resolve-ReviewRootPath {
    param(
        [string]$Root,
        [string]$RelativeOrAbsolute
    )

    $value = if ([string]::IsNullOrWhiteSpace($RelativeOrAbsolute)) { "docs/review" } else { $RelativeOrAbsolute }
    if ([System.IO.Path]::IsPathRooted($value)) {
        return [System.IO.Path]::GetFullPath($value)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root ($value -replace '/', '\')))
}

function Resolve-SummaryMetrics {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return $null }
    $content = Get-Content -Raw -Path $Path

    $health = $null
    $h1 = [regex]::Match($content, "(?im)^\s*Health(?:\s+Score)?\s*:\s*(\d{1,3})\s*/\s*100")
    if ($h1.Success) {
        $health = [int]$h1.Groups[1].Value
    } else {
        $h2 = [regex]::Match($content, "(?im)\bhealth(?:\s+score)?\b[^0-9]{0,20}(\d{1,3})\s*/\s*100")
        if ($h2.Success) { $health = [int]$h2.Groups[1].Value }
    }

    $driftMatch = [regex]::Match($content, "(?im)Deterministic\s+Drift\s+Totals\s*:\s*.*?TOTAL\s*=\s*(\d+)")
    $unmappedMatch = [regex]::Match($content, "(?im)Unmapped\s+findings\s*:\s*(\d+)")

    return [PSCustomObject]@{
        Path     = $Path
        Parsed   = (($null -ne $health) -or $driftMatch.Success -or $unmappedMatch.Success)
        Complete = (($null -ne $health) -and $driftMatch.Success -and $unmappedMatch.Success)
        Health   = $health
        Drift    = $(if ($driftMatch.Success) { [int]$driftMatch.Groups[1].Value } else { $null })
        Unmapped = $(if ($unmappedMatch.Success) { [int]$unmappedMatch.Groups[1].Value } else { $null })
    }
}

function Try-ParseUtcDateTime {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try {
        return [DateTime]::Parse(
            $Text,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal
        ).ToUniversalTime()
    } catch {
        return $null
    }
}

function Get-DeepReviewEvidence {
    param([datetime]$NotBeforeUtc)

    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($summaryPath in @($script:ResolvedSummaryPaths)) {
        if (-not (Test-Path $summaryPath)) { continue }

        $reviewDir = Split-Path -Parent $summaryPath
        $codeReviewSummaryPath = Join-Path $reviewDir "layers\code-review-summary.json"
        if (-not (Test-Path $codeReviewSummaryPath)) { continue }

        $summaryText = Get-Content -Raw -Path $summaryPath
        $deepIngestedSummary = [regex]::IsMatch($summaryText, '(?im)^\s*Deep Review Totals:\s*STATUS=INGESTED\b')
        $sourcePatternEscaped = [regex]::Escape([string]$script:ReviewSummarySourceRelative)
        $deepFromSummarySource = [regex]::IsMatch($summaryText, ("(?im)^\s*Deep Review Totals:.*\bSOURCE={0}\b" -f $sourcePatternEscaped))

        $jsonRaw = Get-Content -Raw -Path $codeReviewSummaryPath
        $json = $null
        try { $json = $jsonRaw | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }

        $deepStatus = ""
        $deepHealthScore = $null
        $hasTotalFindings = $false
        $lineTraceStatus = ""
        $generatedUtc = $null

        if ($json) {
            if ($json.PSObject.Properties.Name -contains "deepReview" -and $json.deepReview) {
                $deepStatus = [string]$json.deepReview.status
            }
            if ([string]::IsNullOrWhiteSpace($deepStatus) -and ($json.PSObject.Properties.Name -contains "status")) {
                $deepStatus = [string]$json.status
            }

            if ($json.PSObject.Properties.Name -contains "lineTraceability" -and $json.lineTraceability) {
                $lineTraceStatus = [string]$json.lineTraceability.status
            }

            if (($json.PSObject.Properties.Name -contains "deepReview") -and $json.deepReview) {
                if ($json.deepReview.PSObject.Properties.Name -contains "healthScore") {
                    $deepHealthScore = $json.deepReview.healthScore
                }
            }

            if (($json.PSObject.Properties.Name -contains "totals") -and $json.totals) {
                if ($json.totals.PSObject.Properties.Name -contains "TOTAL_FINDINGS") {
                    $tf = $json.totals.TOTAL_FINDINGS
                    if ($null -ne $tf) {
                        $parsedTf = 0
                        if ([int]::TryParse([string]$tf, [ref]$parsedTf)) {
                            $hasTotalFindings = $true
                        }
                    }
                }
            }

            $generatedText = ""
            if ($json.PSObject.Properties.Name -contains "generatedUtc") {
                $generatedText = [string]$json.generatedUtc
            }
            if ([string]::IsNullOrWhiteSpace($generatedText) -and
                ($json.PSObject.Properties.Name -contains "deepReview") -and
                $json.deepReview -and
                ($json.deepReview.PSObject.Properties.Name -contains "generatedUtc")) {
                $generatedText = [string]$json.deepReview.generatedUtc
            }
            $generatedUtc = Try-ParseUtcDateTime -Text $generatedText
        }

        $mtimeUtc = (Get-Item $codeReviewSummaryPath).LastWriteTimeUtc
        $effectiveUtc = if ($generatedUtc) { $generatedUtc } else { $mtimeUtc }

        $freshEnough = $effectiveUtc -ge $NotBeforeUtc.AddMinutes(-1)
        $deepStatusIngested = $deepStatus -match '^\s*INGESTED\s*$'
        $deepStatusUnparsable = $deepStatus -match '^\s*UNPARSABLE\s*$'
        $deepStatusMissing = [string]::IsNullOrWhiteSpace($deepStatus)
        $lineTracePassed = $lineTraceStatus -match '^\s*(PASSED|PASS)\s*$'
        $parsedDeepHealth = 0
        $deepHealthValid = ([int]::TryParse([string]$deepHealthScore, [ref]$parsedDeepHealth)) -and ($parsedDeepHealth -ge 0)

        $ok = $freshEnough -and (-not $deepStatusIngested) -and (-not $deepStatusUnparsable) -and (-not $deepStatusMissing) -and $deepHealthValid -and $hasTotalFindings -and (-not $deepIngestedSummary) -and (-not $deepFromSummarySource) -and $lineTracePassed

        $rows.Add([PSCustomObject]@{
            SummaryPath            = $summaryPath
            CodeReviewSummaryPath  = $codeReviewSummaryPath
            DeepStatus             = $deepStatus
            DeepHealthScore        = $deepHealthScore
            HasTotalFindings       = $hasTotalFindings
            LineTraceabilityStatus = $lineTraceStatus
            GeneratedUtc           = $effectiveUtc
            FreshEnough            = $freshEnough
            DeepIngestedSummary    = $deepIngestedSummary
            DeepFromSummarySource  = $deepFromSummarySource
            Ok                     = $ok
        }) | Out-Null
    }

    if ($rows.Count -eq 0) {
        return [PSCustomObject]@{
            Ok     = $false
            Reason = "missing-code-review-summary"
            Best   = $null
            All    = @()
        }
    }

    $best = @($rows | Sort-Object GeneratedUtc -Descending)[0]
    if ($best.Ok) {
        return [PSCustomObject]@{
            Ok     = $true
            Reason = "ok"
            Best   = $best
            All    = $rows.ToArray()
        }
    }

    $reasons = New-Object System.Collections.Generic.List[string]
    if (-not $best.FreshEnough) { $reasons.Add("stale-code-review-summary") | Out-Null }
    if ($best.DeepStatus -match '^\s*INGESTED\s*$') { $reasons.Add("deep-status-ingested") | Out-Null }
    if ($best.DeepStatus -match '^\s*UNPARSABLE\s*$') { $reasons.Add("deep-status-unparsable") | Out-Null }
    if ([string]::IsNullOrWhiteSpace([string]$best.DeepStatus)) { $reasons.Add("deep-status-missing") | Out-Null }
    $parsedBestDeepHealth = 0
    $bestDeepHealthValid = ([int]::TryParse([string]$best.DeepHealthScore, [ref]$parsedBestDeepHealth)) -and ($parsedBestDeepHealth -ge 0)
    if (-not $bestDeepHealthValid) { $reasons.Add("deep-health-invalid") | Out-Null }
    if (-not $best.HasTotalFindings) { $reasons.Add("deep-total-findings-missing") | Out-Null }
    if ($best.DeepIngestedSummary) { $reasons.Add("deep-review-totals-ingested") | Out-Null }
    if ($best.DeepFromSummarySource) { $reasons.Add("deep-review-source-summary-artifact") | Out-Null }
    if (-not ($best.LineTraceabilityStatus -match '^\s*(PASSED|PASS)\s*$')) { $reasons.Add("line-traceability-not-passed") | Out-Null }
    if ($reasons.Count -eq 0) { $reasons.Add("deep-review-validation-failed") | Out-Null }

    return [PSCustomObject]@{
        Ok     = $false
        Reason = ([string]::Join(",", $reasons.ToArray()))
        Best   = $best
        All    = $rows.ToArray()
    }
}

function Get-BestMetricSnapshot {
    param([string[]]$Paths)

    $existing = @()
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            $item = Get-Item $path
            $existing += [PSCustomObject]@{
                Path = $path
                LastWriteTime = $item.LastWriteTime
            }
        }
    }

    if ($existing.Count -eq 0) { return $null }

    foreach ($candidate in ($existing | Sort-Object LastWriteTime -Descending)) {
        $parsed = Resolve-SummaryMetrics -Path $candidate.Path
        if ($parsed -and $parsed.Parsed) { return $parsed }
    }

    return (Resolve-SummaryMetrics -Path $existing[0].Path)
}

function Get-PendingPhases {
    param([string]$RoadmapFile)

    if (-not (Test-Path $RoadmapFile)) { return @() }
    $matches = @(Select-String -Path $RoadmapFile -Pattern '^- \[ \] \*\*Phase (\d+):' -CaseSensitive:$false)
    $phases = @()

    foreach ($m in $matches) {
        if ($m.Matches.Count -gt 0) {
            $phases += [int]$m.Matches[0].Groups[1].Value
        }
    }

    return @($phases | Sort-Object -Unique)
}

function Get-CompletedPhases {
    param([string]$RoadmapFile)

    if (-not (Test-Path $RoadmapFile)) { return @() }
    $matches = @(Select-String -Path $RoadmapFile -Pattern '^- \[[xX]\] \*\*Phase (\d+):' -CaseSensitive:$false)
    $phases = @()

    foreach ($m in $matches) {
        if ($m.Matches.Count -gt 0) {
            $phases += [int]$m.Matches[0].Groups[1].Value
        }
    }

    return @($phases | Sort-Object -Unique)
}

function Get-CodeFingerprint {
    $statusRes = Invoke-GitCapture -GitArgs @("status", "--porcelain") -AllowFail
    if ($statusRes.ExitCode -ne 0 -or @($statusRes.Output).Count -eq 0) { return @() }

    $lines = @()
    foreach ($row in $statusRes.Output) {
        $line = [string]$row
        if ($line.Length -lt 3) { continue }
        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim() } else { "" }
        if ($path -match '\s->\s') { $path = ($path -split '\s->\s')[-1].Trim() }

        if ($path -match '\.(cs|csproj|sln|ts|tsx|js|jsx|sql)$') {
            $lines += $line.Trim()
        }
    }

    return ($lines | Sort-Object)
}

function Test-CodeFingerprintEqual {
    param([string[]]$Left, [string[]]$Right)
    return ((@($Left) -join "`n") -eq (@($Right) -join "`n"))
}

function Get-FirstShaFromOutput {
    param(
        [object[]]$Output,
        [int]$Length = 40
    )

    if ($Length -lt 7) { $Length = 7 }
    $pattern = "\b[0-9a-fA-F]{$Length}\b"

    foreach ($row in @($Output)) {
        $text = [string]$row
        $match = [regex]::Match($text, $pattern)
        if ($match.Success) {
            return $match.Value.ToLowerInvariant()
        }
    }

    return ""
}

function Get-FirstIntFromOutput {
    param([object[]]$Output)

    foreach ($row in @($Output)) {
        $text = [string]$row
        $match = [regex]::Match($text, '^\s*(\d+)\s*$')
        if ($match.Success) {
            return [int]$match.Groups[1].Value
        }
    }

    return $null
}

function Get-NestedGitRepoPaths {
    param([string]$RootPath)

    if (-not (Test-Path $RootPath)) { return @() }
    $repos = @()

    $children = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        $gitMarker = Join-Path $child.FullName ".git"
        if (Test-Path $gitMarker) {
            $repos += (Resolve-Path -Path $child.FullName).Path
        }
    }

    return @($repos | Sort-Object -Unique)
}

function Convert-ToProcessArgToken {
    param([string]$Value)

    if ($null -eq $Value) { return '""' }

    # Preserve whitespace/special chars when passing a single command-line string.
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }

    return $Value
}

function Invoke-GitCapture {
    param(
        [string[]]$GitArgs,
        [switch]$AllowFail
    )

    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()

    $output = @()
    $exitCode = 0

    try {
        $gitCommand = if ($script:GitExe) { $script:GitExe } else { "git" }
        $effectiveArgs = @()
        if (
            -not [string]::IsNullOrWhiteSpace($script:GitRepoRoot) -and
            -not (@($GitArgs).Count -ge 2 -and $GitArgs[0] -eq "-C")
        ) {
            $effectiveArgs += @("-C", $script:GitRepoRoot)
        }
        $effectiveArgs += @($GitArgs)
        $argumentLine = (@($effectiveArgs | ForEach-Object { Convert-ToProcessArgToken -Value ([string]$_) }) -join ' ')

        $proc = Start-Process `
            -FilePath $gitCommand `
            -ArgumentList $argumentLine `
            -NoNewWindow `
            -PassThru `
            -Wait `
            -RedirectStandardOutput $tmpOut `
            -RedirectStandardError $tmpErr

        $exitCode = $proc.ExitCode
        if (Test-Path $tmpOut) { $output += @(Get-Content -Path $tmpOut -ErrorAction SilentlyContinue) }
        if (Test-Path $tmpErr) { $output += @(Get-Content -Path $tmpErr -ErrorAction SilentlyContinue) }
    } finally {
        Remove-Item -Path $tmpOut, $tmpErr -ErrorAction SilentlyContinue
    }

    if ((-not $AllowFail) -and $exitCode -ne 0) {
        throw ("git {0} failed (exit {1})`n{2}" -f ($effectiveArgs -join " "), $exitCode, (@($output) -join "`n"))
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = @($output)
    }
}

function Get-GitHeadWithRetry {
    param(
        [string]$RepoPath,
        [int]$Attempts = 5,
        [int]$DelaySeconds = 2,
        [switch]$AllowMissing
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $headRes = Invoke-GitCapture -GitArgs @("-C", $RepoPath, "rev-parse", "HEAD") -AllowFail
        if ($headRes.ExitCode -eq 0) {
            $sha = Get-FirstShaFromOutput -Output $headRes.Output -Length 40
            if (-not [string]::IsNullOrWhiteSpace($sha)) {
                return $sha
            }
        }

        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    if ($AllowMissing) { return "" }
    throw "Unable to resolve git HEAD baseline for '$RepoPath' after $Attempts attempts."
}

function Initialize-CommitBaselines {
    $script:TrackedRepos = @($script:ResolvedProjectRoot)
    $script:TrackedRepos += @(Get-NestedGitRepoPaths -RootPath $script:ResolvedProjectRoot)
    $script:TrackedRepos = @($script:TrackedRepos | Sort-Object -Unique)

    $script:StartHeads = @{}
    foreach ($repoPath in $script:TrackedRepos) {
        $head = Get-GitHeadWithRetry -RepoPath $repoPath -AllowMissing
        if (-not [string]::IsNullOrWhiteSpace($head)) {
            $script:StartHeads[$repoPath] = $head
        }
    }

    $script:StartHead = ""
    if ($script:StartHeads.Contains($script:ResolvedProjectRoot)) {
        $script:StartHead = [string]$script:StartHeads[$script:ResolvedProjectRoot]
    }

    if ([string]::IsNullOrWhiteSpace($script:StartHead) -and -not $DryRun) {
        throw "Cannot establish root git baseline commit (start_head) for '$($script:ResolvedProjectRoot)'. Aborting to avoid incorrect commit telemetry."
    }
}

function Ensure-GitPushSynced {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$Stage,
        [int]$MaxAttempts = 12
    )

    if ($DryRun) {
        return [PSCustomObject]@{ Ok = $true; Status = "dry-run"; Detail = "" }
    }

    $branchLine = ""
    $statusDetail = ""

    for ($statusAttempt = 1; $statusAttempt -le 6; $statusAttempt++) {
        $statusRes = Invoke-GitCapture -GitArgs @("status", "-sb") -AllowFail
        if ($statusRes.ExitCode -eq 0 -and @($statusRes.Output).Count -gt 0) {
            $branchLine = [string]$statusRes.Output[0]
            break
        }

        $statusDetail = (@($statusRes.Output) -join "`n")
        if ($statusAttempt -lt 6) { Start-Sleep -Seconds 2 }
    }

    $statusUnavailable = [string]::IsNullOrWhiteSpace($branchLine)
    $needsPush = ($branchLine -match '\[ahead ') -or ($branchLine -match 'diverged')

    if ($statusUnavailable) {
        $needsPush = $true
    }

    if (-not $needsPush) {
        return [PSCustomObject]@{ Ok = $true; Status = "no-push-needed"; Detail = $branchLine }
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $pushRes = Invoke-GitCapture -GitArgs @("push") -AllowFail
        if ($pushRes.ExitCode -eq 0) {
            return [PSCustomObject]@{ Ok = $true; Status = "push-succeeded"; Detail = (@($pushRes.Output) -join "`n") }
        }

        $pushText = (@($pushRes.Output) -join "`n")
        if ($pushText -match 'no upstream branch' -or $pushText -match '--set-upstream' -or $pushText -match 'set the remote as upstream') {
            $upstreamRes = Invoke-GitCapture -GitArgs @("push", "-u", "origin", "HEAD") -AllowFail
            if ($upstreamRes.ExitCode -eq 0) {
                return [PSCustomObject]@{ Ok = $true; Status = "push-upstream-succeeded"; Detail = (@($upstreamRes.Output) -join "`n") }
            }
            $pushText = (@($upstreamRes.Output) -join "`n")
        }

        $authFailed = (
            $pushText -match 'Authentication failed' -or
            $pushText -match 'Permission denied' -or
            $pushText -match 'could not read Username' -or
            $pushText -match 'Access denied'
        )
        if ($authFailed) {
            return [PSCustomObject]@{ Ok = $false; Status = "push-auth-failed"; Detail = $pushText }
        }

        $pushRejected = (
            $pushText -match 'failed to push some refs' -or
            $pushText -match 'non-fast-forward' -or
            $pushText -match '\[rejected\]' -or
            $pushText -match 'fetch first'
        )
        if ($pushRejected) {
            $pullRes = Invoke-GitCapture -GitArgs @("pull", "--rebase", "--autostash") -AllowFail
            if ($pullRes.ExitCode -ne 0) {
                $null = Invoke-GitCapture -GitArgs @("rebase", "--abort") -AllowFail
            }
        }

        Start-Sleep -Seconds 2
    }

    $detail = "Could not push after retries."
    if (-not [string]::IsNullOrWhiteSpace($statusDetail)) {
        $detail += "`nStatus probe detail:`n" + $statusDetail
    }

    return [PSCustomObject]@{ Ok = $false; Status = "push-max-attempts-exceeded"; Detail = $detail }
}

function Convert-ToCommitLabel {
    param(
        [string]$Text,
        [int]$MaxLength = 88
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }

    $label = [string]$Text
    $label = $label -replace '[\r\n\t]+', ' '
    $label = $label -replace '\s+', ' '
    $label = $label -replace '[`"]', ''
    $label = $label.Trim()
    $label = $label -replace '^[\s\-\|:;,.]+', ''
    $label = $label -replace '[\s\-\|:;,.]+$', ''

    if ($label.Length -gt $MaxLength) {
        $label = $label.Substring(0, $MaxLength).Trim()
        $label = $label -replace '[\s\-\|:;,.]+$', ''
    }

    return $label
}

function Get-PreviousExecutiveSummaryContext {
    param([string[]]$SummaryPaths)

    foreach ($summaryPath in @($SummaryPaths)) {
        if (-not (Test-Path $summaryPath)) { continue }

        $lines = @()
        try { $lines = @(Get-Content -Path $summaryPath -ErrorAction Stop) } catch { $lines = @() }
        if ($lines.Count -eq 0) { continue }

        $rawLabel = ""
        foreach ($line in $lines) {
            $text = [string]$line
            $m = [regex]::Match($text, '^\s*Summary\s*:\s*(.+?)\s*$')
            if ($m.Success) {
                $rawLabel = [string]$m.Groups[1].Value.Trim()
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($rawLabel)) {
            foreach ($line in $lines) {
                $text = [string]$line
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                if ($text -match '^\s*#') { continue }
                $rawLabel = $text.Trim()
                break
            }
        }

        $label = Convert-ToCommitLabel -Text $rawLabel
        if (-not [string]::IsNullOrWhiteSpace($label)) {
            return [PSCustomObject]@{
                Path  = $summaryPath
                Raw   = $rawLabel
                Label = $label
            }
        }
    }

    return [PSCustomObject]@{
        Path  = "unavailable"
        Raw   = ""
        Label = "review-summary-unavailable"
    }
}

function Invoke-PreReviewCommitPush {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$LogName
    )

    $summaryCtx = Get-PreviousExecutiveSummaryContext -SummaryPaths $script:ResolvedSummaryPaths
    $summaryLabel = [string]$summaryCtx.Label
    if ([string]::IsNullOrWhiteSpace($summaryLabel)) {
        $summaryLabel = "review-summary-unavailable"
    }

    $summarySource = [string]$summaryCtx.Path
    if ([string]::IsNullOrWhiteSpace($summarySource)) {
        $summarySource = "unavailable"
    }

    $commitMessage = "auto-dev pre-review: $summaryLabel"
    $commitMessage = Convert-ToCommitLabel -Text $commitMessage -MaxLength 120
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "auto-dev pre-review"
    }

    Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-enter" -Doing ("pre-review commit check summary_label='{0}' summary_source={1}" -f $summaryLabel, $summarySource) -Phase "-" -IsRunning $false -LogName $LogName

    if ($DryRun) {
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-dry-run" -Doing ("dry-run skip pre-review commit message='{0}'" -f $commitMessage) -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $true; Status = "dry-run"; CommitMessage = $commitMessage; CommitSha = "" }
    }

    $statusRes = Invoke-GitCapture -GitArgs @("status", "--porcelain") -AllowFail
    if ($statusRes.ExitCode -ne 0) {
        $detail = (@($statusRes.Output) -join " ")
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-failed" -Doing ("git status failed before pre-review commit detail='{0}'" -f $detail) -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $false; Status = "git-status-failed"; Detail = $detail; CommitMessage = $commitMessage; CommitSha = "" }
    }

    if (@($statusRes.Output).Count -eq 0) {
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-skip" -Doing "no code updates detected before code-review; skipping commit" -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $true; Status = "no-changes"; CommitMessage = $commitMessage; CommitSha = "" }
    }

    $addRes = Invoke-GitCapture -GitArgs @("add", "-A") -AllowFail
    if ($addRes.ExitCode -ne 0) {
        $detail = (@($addRes.Output) -join " ")
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-failed" -Doing ("git add failed before code-review detail='{0}'" -f $detail) -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $false; Status = "git-add-failed"; Detail = $detail; CommitMessage = $commitMessage; CommitSha = "" }
    }

    $stagedRes = Invoke-GitCapture -GitArgs @("diff", "--cached", "--name-only") -AllowFail
    if ($stagedRes.ExitCode -ne 0) {
        $detail = (@($stagedRes.Output) -join " ")
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-failed" -Doing ("git diff --cached failed detail='{0}'" -f $detail) -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $false; Status = "git-diff-cached-failed"; Detail = $detail; CommitMessage = $commitMessage; CommitSha = "" }
    }

    if (@($stagedRes.Output).Count -eq 0) {
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-skip" -Doing "no staged changes after git add; skipping commit" -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $true; Status = "no-staged-changes"; CommitMessage = $commitMessage; CommitSha = "" }
    }

    $commitRes = Invoke-GitCapture -GitArgs @("commit", "-m", $commitMessage) -AllowFail
    if ($commitRes.ExitCode -ne 0) {
        $commitText = (@($commitRes.Output) -join " ")
        if ($commitText -match 'nothing to commit') {
            Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-skip" -Doing "nothing to commit before code-review" -Phase "-" -IsRunning $false -LogName $LogName
            return [PSCustomObject]@{ Ok = $true; Status = "nothing-to-commit"; CommitMessage = $commitMessage; CommitSha = "" }
        }

        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-failed" -Doing ("git commit failed before code-review detail='{0}'" -f $commitText) -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $false; Status = "git-commit-failed"; Detail = $commitText; CommitMessage = $commitMessage; CommitSha = "" }
    }

    $headRes = Invoke-GitCapture -GitArgs @("rev-parse", "HEAD") -AllowFail
    $commitSha = ""
    if ($headRes.ExitCode -eq 0) {
        $commitSha = Get-FirstShaFromOutput -Output $headRes.Output -Length 40
    }
    $shortSha = if ([string]::IsNullOrWhiteSpace($commitSha)) { "unknown" } else { $commitSha.Substring(0, [Math]::Min(7, $commitSha.Length)) }

    $pushRes = Ensure-GitPushSynced -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit"
    if (-not $pushRes.Ok) {
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage ("pre-review-commit-{0}" -f $pushRes.Status) -Doing "pre-review commit created but push failed" -Phase "-" -IsRunning $false -LogName $LogName
        return [PSCustomObject]@{ Ok = $false; Status = ("push-{0}" -f $pushRes.Status); Detail = $pushRes.Detail; CommitMessage = $commitMessage; CommitSha = $commitSha }
    }

    Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage "pre-review-commit-done" -Doing ("pre-review updates committed/pushed sha={0} message='{1}'" -f $shortSha, $commitMessage) -Phase "-" -IsRunning $false -LogName $LogName
    return [PSCustomObject]@{ Ok = $true; Status = "committed"; CommitMessage = $commitMessage; CommitSha = $commitSha }
}

function Get-CommitDeltaSinceStart {
    if (-not $script:StartHeads -or $script:StartHeads.Count -eq 0) { return 0 }

    $total = 0
    foreach ($entry in $script:StartHeads.GetEnumerator()) {
        $repoPath = [string]$entry.Key
        $startSha = [string]$entry.Value
        if ([string]::IsNullOrWhiteSpace($startSha)) { continue }

        $countRes = Invoke-GitCapture -GitArgs @("-C", $repoPath, "rev-list", "--count", "$startSha..HEAD") -AllowFail
        if ($countRes.ExitCode -ne 0) { continue }

        $value = Get-FirstIntFromOutput -Output $countRes.Output
        if ($null -ne $value) {
            $total += [int]$value
        }
    }

    return $total
}

function Get-PhaseCounts {
    param(
        [string]$RoadmapFile,
        [bool]$IsRunning,
        [string]$PhaseText
    )

    $completed = @(Get-CompletedPhases -RoadmapFile $RoadmapFile).Count
    $pending = @(Get-PendingPhases -RoadmapFile $RoadmapFile).Count

    $inProgress = 0
    if ($IsRunning) {
        if ($pending -gt 0) {
            $inProgress = 1
        } elseif (-not [string]::IsNullOrWhiteSpace($PhaseText) -and $PhaseText -ne "-") {
            $inProgress = 1
        }
    }

    return [PSCustomObject]@{
        Completed = $completed
        InProgress = $inProgress
        Pending = $pending
    }
}

function Get-AllPhases {
    param([string]$RoadmapFile)

    if (-not (Test-Path $RoadmapFile)) { return @() }
    $matches = @(Select-String -Path $RoadmapFile -Pattern '^- \[[ xX]\] \*\*Phase (\d+):' -CaseSensitive:$false)
    $phases = @()

    foreach ($m in $matches) {
        if ($m.Matches.Count -gt 0) {
            $phases += [int]$m.Matches[0].Groups[1].Value
        }
    }

    return @($phases | Sort-Object -Unique)
}

function Join-StringList {
    param(
        [string[]]$Values,
        [int]$MaxItems = 8
    )

    $items = @()
    foreach ($v in @($Values)) {
        $text = [string]$v
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $items += $text.Trim()
    }

    $items = @($items | Sort-Object -Unique)
    if ($items.Count -eq 0) { return "none" }
    if ($MaxItems -lt 1 -or $items.Count -le $MaxItems) { return ($items -join ",") }

    $shown = @($items[0..($MaxItems - 1)])
    return ("{0}...(+{1})" -f ($shown -join ","), ($items.Count - $MaxItems))
}

function Get-PendingPhasesText {
    param([int]$MaxItems = 12)
    $pending = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
    return (Join-IntList -Values $pending -MaxItems $MaxItems)
}

function Get-PhasesNeedingResearch {
    param([int[]]$PhaseIds)

    $targets = @()
    foreach ($phaseId in @($PhaseIds | Sort-Object -Unique)) {
        $dir = Get-PhaseDirectoryPath -PhaseId $phaseId
        if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path $dir)) {
            $targets += $phaseId
            continue
        }

        $researchFiles = @(Get-ChildItem -Path $dir -File -Filter "*RESEARCH.md" -ErrorAction SilentlyContinue)
        if ($researchFiles.Count -eq 0) {
            $targets += $phaseId
        }
    }

    return @($targets | Sort-Object -Unique)
}

function Get-PhasesNeedingPlan {
    param([int[]]$PhaseIds)

    $targets = @()
    foreach ($phaseId in @($PhaseIds | Sort-Object -Unique)) {
        $dir = Get-PhaseDirectoryPath -PhaseId $phaseId
        if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path $dir)) {
            $targets += $phaseId
            continue
        }

        $planFiles = @(Get-ChildItem -Path $dir -File -Filter "*-PLAN.md" -ErrorAction SilentlyContinue)
        if ($planFiles.Count -eq 0) {
            $targets += $phaseId
        }
    }

    return @($targets | Sort-Object -Unique)
}

function Set-RoadmapPhaseCompletionState {
    param(
        [string]$RoadmapFile,
        [int[]]$PhaseIds,
        [switch]$Complete
    )

    if (-not (Test-Path $RoadmapFile)) { return $false }

    $phaseSet = New-Object System.Collections.Generic.HashSet[int]
    foreach ($phaseId in @($PhaseIds | Sort-Object -Unique)) {
        [void]$phaseSet.Add([int]$phaseId)
    }
    if ($phaseSet.Count -eq 0) { return $false }

    $updated = $false
    $targetToken = if ($Complete) { "x" } else { " " }
    $lines = @(Get-Content -Path $RoadmapFile)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $match = [regex]::Match($line, '^- \[[ xX]\] \*\*Phase (\d+):', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) { continue }

        $phaseId = 0
        if (-not [int]::TryParse([string]$match.Groups[1].Value, [ref]$phaseId)) { continue }
        if (-not $phaseSet.Contains($phaseId)) { continue }

        $newLine = [regex]::Replace($line, '^- \[[ xX]\]', ("- [{0}]" -f $targetToken), 1)
        if ($newLine -ne $line) {
            $lines[$i] = $newLine
            $updated = $true
        }
    }

    if ($updated) {
        Set-Content -Path $RoadmapFile -Value $lines -Encoding UTF8
    }

    return $updated
}

function Get-PhaseDirectoryPath {
    param([int]$PhaseId)

    $phaseRoot = Join-Path $script:ResolvedProjectRoot ".planning\phases"
    if (-not (Test-Path $phaseRoot)) { return $null }

    $pattern = "^[0]*{0}-" -f [regex]::Escape([string]$PhaseId)
    $candidates = @(Get-ChildItem -Path $phaseRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern } | Sort-Object Name)
    if ($candidates.Count -eq 0) { return $null }
    return $candidates[0].FullName
}

function Get-FindingRefsFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $results = New-Object System.Collections.Generic.List[string]
    $patterns = @(
        '(?im)\b([A-Z][A-Z0-9]+(?:-[A-Z0-9]+){2,})\b',
        '(?im)\b(FINDING[-_ #]*\d{1,5})\b'
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($Text, $pattern)
        foreach ($m in $matches) {
            if (-not $m.Success -or $m.Groups.Count -lt 2) { continue }
            $value = [string]$m.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            $value = ($value -replace '\s+', '-' -replace '_', '-').ToUpperInvariant()
            if ($value.Length -gt 84) { continue }
            if ($value -match '^(PHASE|ROADMAP|STATE|DOCS|REVIEW|LAYER)-') { continue }
            if (-not $results.Contains($value)) {
                $results.Add($value) | Out-Null
            }
        }
    }

    return $results.ToArray()
}

function Get-PhaseFindingReferences {
    param([int]$PhaseId)

    $dir = Get-PhaseDirectoryPath -PhaseId $PhaseId
    if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path $dir)) { return @() }

    $files = @()
    $files += @(Get-ChildItem -Path $dir -File -Filter "*-PLAN.md" -ErrorAction SilentlyContinue)
    $files += @(Get-ChildItem -Path $dir -File -Filter "*RESEARCH.md" -ErrorAction SilentlyContinue)
    $files += @(Get-ChildItem -Path $dir -File -Filter "*-SUMMARY.md" -ErrorAction SilentlyContinue)
    $files = @($files | Sort-Object FullName -Unique)

    $refs = New-Object System.Collections.Generic.List[string]
    foreach ($f in $files) {
        $text = ""
        try { $text = Get-Content -Raw -Path $f.FullName -ErrorAction Stop } catch { $text = "" }
        foreach ($item in @(Get-FindingRefsFromText -Text $text)) {
            if (-not $refs.Contains($item)) {
                $refs.Add($item) | Out-Null
            }
        }
    }

    return @($refs.ToArray() | Sort-Object -Unique)
}

function Write-PhaseFindingMapProgress {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$Stage,
        [string]$MapType,
        [int[]]$PhaseIds,
        [string]$LogName,
        [switch]$Force
    )

    $phases = @($PhaseIds | Sort-Object -Unique)
    if ($phases.Count -eq 0) { return }

    foreach ($phase in $phases) {
        $refs = @(Get-PhaseFindingReferences -PhaseId $phase)
        $refsText = Join-StringList -Values $refs -MaxItems 8

        $sigKey = "{0}|{1}|{2}" -f $Stage, $MapType, $phase
        if ((-not $Force) -and $script:LastPhaseMapByKey.ContainsKey($sigKey) -and [string]$script:LastPhaseMapByKey[$sigKey] -eq $refsText) {
            continue
        }
        $script:LastPhaseMapByKey[$sigKey] = $refsText

        $doing = "phase-finding-map type=$MapType phase=$phase mapped_findings=$refsText"
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage ("{0}-phase-map-{1}" -f $Stage, $MapType) -Doing $doing -Phase ([string]$phase) -IsRunning $false -LogName $LogName
    }
}

function Test-IsCodePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $false }
    return ($PathValue -match '\.(cs|csproj|sln|ts|tsx|js|jsx|sql|py|java|go|rb|php)$')
}

function Get-CodeFileWorkingSetPaths {
    $statusRes = Invoke-GitCapture -GitArgs @("status", "--porcelain") -AllowFail
    if ($statusRes.ExitCode -ne 0) { return @() }

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($row in @($statusRes.Output)) {
        $line = [string]$row
        if ($line.Length -lt 3) { continue }

        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim() } else { "" }
        if ($path -match '\s->\s') { $path = ($path -split '\s->\s')[-1].Trim() }
        if (-not (Test-IsCodePath -PathValue $path)) { continue }

        if (-not $files.Contains($path)) {
            $files.Add($path) | Out-Null
        }
    }

    return @($files.ToArray() | Sort-Object -Unique)
}

function Get-CodeFileWorkingSetCount {
    return @(Get-CodeFileWorkingSetPaths).Count
}

function Get-CodeFilesChangedSinceHead {
    param([string]$StartHead)

    if ([string]::IsNullOrWhiteSpace($StartHead)) { return @() }

    $diffRes = Invoke-GitCapture -GitArgs @("diff", "--name-only", "$StartHead..HEAD") -AllowFail
    if ($diffRes.ExitCode -ne 0) { return @() }

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($row in @($diffRes.Output)) {
        $path = [string]$row
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $path = $path.Trim()
        if (-not (Test-IsCodePath -PathValue $path)) { continue }

        if (-not $files.Contains($path)) {
            $files.Add($path) | Out-Null
        }
    }

    return @($files.ToArray() | Sort-Object -Unique)
}

function Get-PhaseExecutionCodeEvidence {
    param(
        [string]$StartHead,
        [string[]]$BeforeWorkingSet
    )

    $before = @()
    foreach ($item in @($BeforeWorkingSet)) {
        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $before += $text.Trim()
    }
    $before = @($before | Sort-Object -Unique)

    $after = @(Get-CodeFileWorkingSetPaths)
    $newWorkingSet = @($after | Where-Object { $before -notcontains $_ } | Sort-Object -Unique)
    $commitChanged = @(Get-CodeFilesChangedSinceHead -StartHead $StartHead)

    $allChanged = @($newWorkingSet + $commitChanged | Sort-Object -Unique)

    return [PSCustomObject]@{
        StartHead       = $StartHead
        WorkingSetBefore = $before
        WorkingSetAfter = $after
        NewWorkingSet   = $newWorkingSet
        CommitChanged   = $commitChanged
        ChangedCodeFiles = $allChanged
        CodeGenerated   = ($allChanged.Count -gt 0)
    }
}

function Get-FindingCodeEvidenceText {
    param(
        [string[]]$FindingRefs,
        [string[]]$ChangedCodeFiles,
        [int]$MaxFindings = 8,
        [int]$MaxFiles = 3
    )

    $findings = @()
    foreach ($item in @($FindingRefs)) {
        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $findings += $text.Trim().ToUpperInvariant()
    }
    $findings = @($findings | Sort-Object -Unique)
    if ($findings.Count -eq 0) { return "none" }

    $filesText = Join-StringList -Values @($ChangedCodeFiles) -MaxItems $MaxFiles
    $entries = New-Object System.Collections.Generic.List[string]
    $limit = [Math]::Min($MaxFindings, $findings.Count)
    for ($i = 0; $i -lt $limit; $i++) {
        $entries.Add(("{0}=>{1}" -f $findings[$i], $filesText)) | Out-Null
    }

    if ($findings.Count -gt $limit) {
        $entries.Add(("...(+{0})" -f ($findings.Count - $limit))) | Out-Null
    }

    return ([string]::Join(";", $entries.ToArray()))
}

function Reset-PhaseForResearchPlan {
    param([int]$PhaseId)

    $removed = New-Object System.Collections.Generic.List[string]
    $dir = Get-PhaseDirectoryPath -PhaseId $PhaseId
    if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path $dir)) {
        $patterns = @("*RESEARCH.md", "*-PLAN.md", "*-SUMMARY.md")
        foreach ($pattern in $patterns) {
            $files = @(Get-ChildItem -Path $dir -File -Filter $pattern -ErrorAction SilentlyContinue)
            foreach ($file in $files) {
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $removed.Add($file.Name) | Out-Null
                } catch { }
            }
        }
    }

    $reopened = Set-RoadmapPhaseCompletionState -RoadmapFile $script:ResolvedRoadmapPath -PhaseIds @($PhaseId)

    return [PSCustomObject]@{
        RemovedArtifacts = @($removed.ToArray() | Sort-Object -Unique)
        RemovedCount     = @($removed.ToArray() | Sort-Object -Unique).Count
        Reopened         = [bool]$reopened
    }
}

function Get-ExecuteCodeSignal {
    param(
        [int]$PreviousCommitCount,
        [int]$PreviousCodeFileCount
    )

    $commitsNow = Get-CommitDeltaSinceStart
    $codeFilesNow = Get-CodeFileWorkingSetCount

    $newCommits = $commitsNow - $PreviousCommitCount
    $codeFileDelta = $codeFilesNow - $PreviousCodeFileCount
    $codeGenerated = ($newCommits -gt 0 -or $codeFilesNow -gt 0 -or $codeFileDelta -gt 0)

    return [PSCustomObject]@{
        CommitsNow      = $commitsNow
        CodeFilesNow    = $codeFilesNow
        NewCommits      = $newCommits
        CodeFileDelta   = $codeFileDelta
        CodeGenerated   = $codeGenerated
    }
}

function Join-IntList {
    param(
        [int[]]$Values,
        [int]$MaxItems = 8
    )

    $sorted = @($Values | Sort-Object -Unique)
    if ($sorted.Count -eq 0) { return "none" }
    if ($MaxItems -lt 1 -or $sorted.Count -le $MaxItems) { return ($sorted -join ",") }

    $shown = @($sorted[0..($MaxItems - 1)])
    return ("{0}...(+{1})" -f ($shown -join ","), ($sorted.Count - $MaxItems))
}

function Get-DeltaText {
    param(
        [string]$Name,
        [object]$Before,
        [object]$After
    )

    if ($null -eq $Before -or $null -eq $After) { return ("{0}=unknown" -f $Name) }

    $delta = [int]$After - [int]$Before
    $deltaText = if ($delta -ge 0) { "+$delta" } else { [string]$delta }
    return ("{0}={1}" -f $Name, $deltaText)
}

function Get-LogSubstageSnapshot {
    param(
        [string]$LogFile,
        [string]$FallbackPhase
    )

    $substage = "working"
    $hint = ""
    $phase = $FallbackPhase

    if (-not (Test-Path $LogFile)) {
        return [PSCustomObject]@{
            Substage = $substage
            Hint     = $hint
            Phase    = $phase
        }
    }

    $tail = @(Get-Content -Path $LogFile -Tail 320 -ErrorAction SilentlyContinue)
    for ($i = $tail.Count - 1; $i -ge 0; $i--) {
        $line = [string]$tail[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ([string]::IsNullOrWhiteSpace($hint)) {
            $mAction = [regex]::Match($line, '(?i)Current action:\s*(.+)$')
            if ($mAction.Success) {
                $hint = [string]$mAction.Groups[1].Value.Trim()
            }
        }

        if ([string]::IsNullOrWhiteSpace($hint)) {
            $mSummary = [regex]::Match($line, '(?i)^\s*Summary:\s*(.+)$')
            if ($mSummary.Success) {
                $hint = [string]$mSummary.Groups[1].Value.Trim()
            }
        }

        if ([string]::IsNullOrWhiteSpace($phase) -or $phase -eq "-") {
            $mPhase = [regex]::Match($line, '(?i)\bphase(?:s)?\s+(\d{1,4})\b')
            if ($mPhase.Success) {
                $phase = [string]$mPhase.Groups[1].Value
            }
        }

        if ($line -match '(?i)\b(phase synthesis|remediation phase|created phase)\b') {
            $substage = "phase-synthesis"
            break
        }
        if ($line -match '(?i)\b(gsd-code-review|gsd-sdlc-review|code-review-summary|executive-summary|finalreview|deep review|runtime gates|build/typecheck|review pipeline)\b') {
            $substage = "code-review"
            break
        }
        if ($line -match '(?i)\b(executed_sequential_count|gsd-batch-execute|execute-phase|sequential phase execution|execution stage|marking phases .* complete|phase execution)\b') {
            $substage = "execute"
            break
        }
        if ($line -match '(?i)\b(plan_dispatched|gsd-batch-plan|batch-plan|plan artifacts?|needs plan|planning)\b') {
            $substage = "planning"
            break
        }
        if ($line -match '(?i)\b(research_dispatched|gsd-batch-research|batch-research|research artifacts?|needs research|research)\b') {
            $substage = "research"
            break
        }
    }

    if ($hint.Length -gt 220) {
        $hint = $hint.Substring(0, 217) + "..."
    }

    return [PSCustomObject]@{
        Substage = $substage
        Hint     = $hint
        Phase    = $phase
    }
}

function Get-CodeReviewSnapshot {
    param([datetime]$NotBeforeUtc)

    $candidates = New-Object System.Collections.Generic.List[object]

    foreach ($summaryPath in @($script:ResolvedSummaryPaths)) {
        $reviewDir = Split-Path -Parent $summaryPath
        if ([string]::IsNullOrWhiteSpace($reviewDir)) { continue }
        $codeReviewSummaryPath = Join-Path $reviewDir "layers\code-review-summary.json"
        if (-not (Test-Path $codeReviewSummaryPath)) { continue }

        $mtimeUtc = (Get-Item $codeReviewSummaryPath).LastWriteTimeUtc
        $candidates.Add([PSCustomObject]@{
            Path     = $codeReviewSummaryPath
            MTimeUtc = $mtimeUtc
        }) | Out-Null
    }

    if ($candidates.Count -eq 0) { return $null }
    $pick = @($candidates | Sort-Object MTimeUtc -Descending)[0]

    $jsonRaw = Get-Content -Raw -Path $pick.Path
    $json = $null
    try { $json = $jsonRaw | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }

    if (-not $json) {
        return [PSCustomObject]@{
            Path            = $pick.Path
            FreshEnough     = $false
            GeneratedUtc    = $pick.MTimeUtc
            DeepStatus      = "UNAVAILABLE"
            DeepHealthScore = $null
            TotalFindings   = $null
            Blocker         = $null
            High            = $null
            Medium          = $null
            Low             = $null
            FindingKeys     = @()
            LineTraceStatus = "UNAVAILABLE"
            ParseError      = $true
        }
    }

    $deepStatus = ""
    $deepHealth = $null
    $lineTraceStatus = ""
    $totalFindings = $null
    $blocker = $null
    $high = $null
    $medium = $null
    $low = $null
    $findingKeys = New-Object System.Collections.Generic.List[string]

    if (($json.PSObject.Properties.Name -contains "deepReview") -and $json.deepReview) {
        if ($json.deepReview.PSObject.Properties.Name -contains "status") {
            $deepStatus = [string]$json.deepReview.status
        }
        if ($json.deepReview.PSObject.Properties.Name -contains "healthScore") {
            $deepHealth = $json.deepReview.healthScore
        }
        if (($json.deepReview.PSObject.Properties.Name -contains "totals") -and $json.deepReview.totals) {
            $deepTotals = $json.deepReview.totals
            $tmp = 0
            if (($deepTotals.PSObject.Properties.Name -contains "TOTAL_FINDINGS") -and [int]::TryParse([string]$deepTotals.TOTAL_FINDINGS, [ref]$tmp)) {
                $totalFindings = $tmp
            }
        }
    }

    if (($json.PSObject.Properties.Name -contains "lineTraceability") -and $json.lineTraceability) {
        if ($json.lineTraceability.PSObject.Properties.Name -contains "status") {
            $lineTraceStatus = [string]$json.lineTraceability.status
        }
    }

    if (($json.PSObject.Properties.Name -contains "totals") -and $json.totals) {
        $totals = $json.totals
        $tmp = 0
        if (($totals.PSObject.Properties.Name -contains "TOTAL_FINDINGS") -and [int]::TryParse([string]$totals.TOTAL_FINDINGS, [ref]$tmp)) {
            $totalFindings = $tmp
        }
        if (($totals.PSObject.Properties.Name -contains "BLOCKER") -and [int]::TryParse([string]$totals.BLOCKER, [ref]$tmp)) {
            $blocker = $tmp
        }
        if (($totals.PSObject.Properties.Name -contains "HIGH") -and [int]::TryParse([string]$totals.HIGH, [ref]$tmp)) {
            $high = $tmp
        }
        if (($totals.PSObject.Properties.Name -contains "MEDIUM") -and [int]::TryParse([string]$totals.MEDIUM, [ref]$tmp)) {
            $medium = $tmp
        }
        if (($totals.PSObject.Properties.Name -contains "LOW") -and [int]::TryParse([string]$totals.LOW, [ref]$tmp)) {
            $low = $tmp
        }
    }

    if (($json.PSObject.Properties.Name -contains "findings") -and $json.findings) {
        foreach ($finding in @($json.findings)) {
            if (-not $finding) { continue }
            $id = ""
            $severity = ""
            $title = ""
            $evidence = ""

            if ($finding.PSObject.Properties.Name -contains "id") { $id = [string]$finding.id }
            if ($finding.PSObject.Properties.Name -contains "severity") { $severity = [string]$finding.severity }
            if ($finding.PSObject.Properties.Name -contains "title") { $title = [string]$finding.title }
            if ($finding.PSObject.Properties.Name -contains "evidence") { $evidence = [string]$finding.evidence }

            $key = if (-not [string]::IsNullOrWhiteSpace($id)) {
                $id.Trim().ToUpperInvariant()
            } else {
                ("{0}|{1}|{2}" -f $severity.Trim().ToUpperInvariant(), $title.Trim().ToUpperInvariant(), $evidence.Trim().ToUpperInvariant())
            }

            if (-not [string]::IsNullOrWhiteSpace($key) -and -not $findingKeys.Contains($key)) {
                $findingKeys.Add($key) | Out-Null
            }
        }
    }

    $generatedText = ""
    if ($json.PSObject.Properties.Name -contains "generatedUtc") {
        $generatedText = [string]$json.generatedUtc
    }
    if ([string]::IsNullOrWhiteSpace($generatedText) -and
        ($json.PSObject.Properties.Name -contains "deepReview") -and
        $json.deepReview -and
        ($json.deepReview.PSObject.Properties.Name -contains "generatedUtc")) {
        $generatedText = [string]$json.deepReview.generatedUtc
    }

    $generatedUtc = Try-ParseUtcDateTime -Text $generatedText
    if (-not $generatedUtc) { $generatedUtc = $pick.MTimeUtc }

    $freshEnough = $generatedUtc -ge $NotBeforeUtc.AddMinutes(-1)

    return [PSCustomObject]@{
        Path            = $pick.Path
        FreshEnough     = $freshEnough
        GeneratedUtc    = $generatedUtc
        DeepStatus      = $deepStatus
        DeepHealthScore = $deepHealth
        TotalFindings   = $totalFindings
        Blocker         = $blocker
        High            = $high
        Medium          = $medium
        Low             = $low
        FindingKeys     = $findingKeys.ToArray()
        LineTraceStatus = $lineTraceStatus
        ParseError      = $false
    }
}

function Write-CodeReviewProgress {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$Stage,
        [string]$Phase,
        [string]$LogName,
        [datetime]$NotBeforeUtc,
        [switch]$Force
    )

    $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
    $review = Get-CodeReviewSnapshot -NotBeforeUtc $NotBeforeUtc
    if (-not $review) {
        Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage ("{0}-review-summary" -f $Stage) -Doing "code-review summary missing" -Phase $Phase -IsRunning $false -LogName $LogName
        return
    }

    $healthText = if ($metric -and $null -ne $metric.Health) { "{0}/100" -f $metric.Health } else { "unknown" }
    $driftText = if ($metric -and $null -ne $metric.Drift) { [string]$metric.Drift } else { "unknown" }
    $unmappedText = if ($metric -and $null -ne $metric.Unmapped) { [string]$metric.Unmapped } else { "unknown" }

    $deepHealthText = if ($null -ne $review.DeepHealthScore -and -not [string]::IsNullOrWhiteSpace([string]$review.DeepHealthScore)) { [string]$review.DeepHealthScore } else { "unknown" }
    $findingsText = if ($null -ne $review.TotalFindings) { [string]$review.TotalFindings } else { "unknown" }
    $lineTraceText = if ([string]::IsNullOrWhiteSpace([string]$review.LineTraceStatus)) { "unknown" } else { [string]$review.LineTraceStatus }
    $deepStatusText = if ([string]::IsNullOrWhiteSpace([string]$review.DeepStatus)) { "unknown" } else { [string]$review.DeepStatus }
    $freshText = if ($review.FreshEnough) { "fresh" } else { "stale" }
    $generatedText = if ($review.GeneratedUtc) { $review.GeneratedUtc.ToString("yyyy-MM-ddTHH:mm:ssZ") } else { "unknown" }

    $currentKeys = @()
    if ($review.PSObject.Properties.Name -contains "FindingKeys") {
        $currentKeys = @($review.FindingKeys | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
    }
    $previousKeys = @($script:LastReviewFindingKeys | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)

    $resolvedKeys = @($previousKeys | Where-Object { $currentKeys -notcontains $_ } | Sort-Object -Unique)
    $newKeys = @($currentKeys | Where-Object { $previousKeys -notcontains $_ } | Sort-Object -Unique)
    $baseline = if ($previousKeys.Count -gt 0) { "available" } else { "initial" }
    $resolvedText = Join-StringList -Values $resolvedKeys -MaxItems 6
    $newText = Join-StringList -Values $newKeys -MaxItems 6

    $resolvedConfirm = if ($baseline -eq "initial") {
        "baseline-pending"
    } elseif ($resolvedKeys.Count -gt 0 -and $newKeys.Count -eq 0) {
        "yes"
    } elseif ($newKeys.Count -gt 0) {
        "partial"
    } else {
        "no-change"
    }

    $signature = "{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}" -f $generatedText, $healthText, $driftText, $unmappedText, $deepStatusText, $deepHealthText, $findingsText, $lineTraceText, ($resolvedKeys.Count), ($newKeys.Count)
    if ((-not $Force) -and $signature -eq $script:LastReviewProgressSignature) {
        return
    }
    $script:LastReviewProgressSignature = $signature
    $script:LastReviewFindingKeys = @($currentKeys)

    $doing = "code-review summary health=$healthText drift=$driftText unmapped=$unmappedText deep_status=$deepStatusText deep_health=$deepHealthText findings=$findingsText line_trace=$lineTraceText generated_utc=$generatedText freshness=$freshText baseline=$baseline resolved_count=$($resolvedKeys.Count) new_count=$($newKeys.Count) previous_findings_resolved=$resolvedConfirm resolved_ids=$resolvedText new_ids=$newText"
    Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage ("{0}-review-summary" -f $Stage) -Doing $doing -Phase $Phase -IsRunning $false -LogName $LogName
}

function Write-PhaseWaveProgress {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$Stage,
        [string]$Phase,
        [string]$LogName,
        [int[]]$BeforePending,
        [int[]]$AfterPending,
        [int[]]$BeforeAll,
        [int[]]$AfterAll,
        [object]$BeforeMetric,
        [object]$AfterMetric
    )

    $created = @($AfterAll | Where-Object { $BeforeAll -notcontains $_ } | Sort-Object -Unique)
    $completedNow = @($BeforePending | Where-Object { $AfterPending -notcontains $_ } | Sort-Object -Unique)
    $newPending = @($AfterPending | Where-Object { $BeforePending -notcontains $_ } | Sort-Object -Unique)

    $pendingDelta = @($AfterPending).Count - @($BeforePending).Count
    $pendingDeltaText = if ($pendingDelta -ge 0) { "+$pendingDelta" } else { [string]$pendingDelta }

    $assignedText = "findings_assigned_delta=unknown"
    if ($BeforeMetric -and $AfterMetric -and $null -ne $BeforeMetric.Unmapped -and $null -ne $AfterMetric.Unmapped) {
        $assigned = [int]$BeforeMetric.Unmapped - [int]$AfterMetric.Unmapped
        $assignedText = if ($assigned -ge 0) { "findings_assigned_delta=+$assigned" } else { "findings_assigned_delta=$assigned" }
    }

    $doing = "phase-wave created={0} completed={1} new_pending={2} pending_delta={3} {4} {5} {6} {7}" -f `
        (Join-IntList -Values $created),
        (Join-IntList -Values $completedNow),
        (Join-IntList -Values $newPending),
        $pendingDeltaText,
        $assignedText,
        (Get-DeltaText -Name "health_delta" -Before $(if ($BeforeMetric) { $BeforeMetric.Health } else { $null }) -After $(if ($AfterMetric) { $AfterMetric.Health } else { $null })),
        (Get-DeltaText -Name "drift_delta" -Before $(if ($BeforeMetric) { $BeforeMetric.Drift } else { $null }) -After $(if ($AfterMetric) { $AfterMetric.Drift } else { $null })),
        (Get-DeltaText -Name "unmapped_delta" -Before $(if ($BeforeMetric) { $BeforeMetric.Unmapped } else { $null }) -After $(if ($AfterMetric) { $AfterMetric.Unmapped } else { $null }))

    Write-ProgressUpdate -StatusPath $StatusPath -Cycle $Cycle -Stage ("{0}-phase-wave" -f $Stage) -Doing $doing -Phase $Phase -IsRunning $false -LogName $LogName

    if ($created.Count -gt 0) {
        Write-PhaseFindingMapProgress -StatusPath $StatusPath -Cycle $Cycle -Stage $Stage -MapType "created" -PhaseIds $created -LogName $LogName
    }
    if ($newPending.Count -gt 0) {
        Write-PhaseFindingMapProgress -StatusPath $StatusPath -Cycle $Cycle -Stage $Stage -MapType "assigned" -PhaseIds $newPending -LogName $LogName
    }
    if ($completedNow.Count -gt 0) {
        Write-PhaseFindingMapProgress -StatusPath $StatusPath -Cycle $Cycle -Stage $Stage -MapType "completed" -PhaseIds $completedNow -LogName $LogName
    }
}

function Write-ProgressUpdate {
    param(
        [string]$StatusPath,
        [int]$Cycle,
        [string]$Stage,
        [string]$Doing,
        [string]$Phase,
        [bool]$IsRunning,
        [string]$LogName
    )

    $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
    $healthText = if ($metric -and $null -ne $metric.Health) { "{0}/100" -f $metric.Health } else { "unknown" }
    $driftText = if ($metric -and $null -ne $metric.Drift) { [string]$metric.Drift } else { "unknown" }
    $unmappedText = if ($metric -and $null -ne $metric.Unmapped) { [string]$metric.Unmapped } else { "unknown" }

    $phaseCounts = Get-PhaseCounts -RoadmapFile $script:ResolvedRoadmapPath -IsRunning $IsRunning -PhaseText $Phase
    $commitsDone = Get-CommitDeltaSinceStart

    $stageText = if ([string]::IsNullOrWhiteSpace($Stage)) { "-" } else { ($Stage -replace '\s+', '_').Trim() }
    $phaseText = if ([string]::IsNullOrWhiteSpace($Phase)) { "-" } else { ($Phase -replace '\s+', '').Trim() }
    $doingText = if ([string]::IsNullOrWhiteSpace($Doing)) { "-" } else { ($Doing -replace '[\r\n]+', ' ' -replace '"', "'").Trim() }
    if ($doingText.Length -gt 320) {
        $doingText = $doingText.Substring(0, 317) + "..."
    }

    $elapsedText = "unknown"
    if ($script:RunnerStartTime -is [datetime]) {
        $elapsed = (Get-Date) - $script:RunnerStartTime
        if ($elapsed.TotalSeconds -ge 0) {
            $elapsedText = "{0:00}:{1:00}:{2:00}" -f [int][math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
        }
    }

    $logText = if ([string]::IsNullOrWhiteSpace($LogName)) { "-" } else { $LogName.Trim() }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = '[{0}] cycle={1} stage={2} doing="{3}" phase={4} phases(completed={5},in_progress={6},pending={7}) target(h=100,d=0,u=0) current(h={8},d={9},u={10}) commits={11} elapsed={12} log={13}' -f `
        $ts, $Cycle, $stageText, $doingText, $phaseText, $phaseCounts.Completed, $phaseCounts.InProgress, $phaseCounts.Pending, $healthText, $driftText, $unmappedText, $commitsDone, $elapsedText, $logText

    Add-Content -Path $StatusPath -Value $line
    if ($ProgressToConsole) {
        Write-Host $line -ForegroundColor Green
    }
}

function Invoke-GlobalSkillMonitored {
    param(
        [string]$Prompt,
        [string]$LogFile,
        [string]$Stage,
        [int]$Cycle,
        [string]$Phase,
        [string]$Doing
    )

    if ($ProgressToConsole) {
        Write-Host ""
        Write-Host ("Headless command: codex exec ... ({0})" -f $Stage) -ForegroundColor DarkGray
    }

    if ($DryRun) { return 0 }

    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $promptFile = Join-Path $script:ResolvedLogDir ("{0}-cycle-{1:D3}-{2}.prompt.txt" -f ($Stage -replace '[^a-zA-Z0-9_-]', '_'), $Cycle, $stamp)
    $errFile = $LogFile + ".stderr"

    Set-Content -Path $promptFile -Value $Prompt -NoNewline -Encoding UTF8

    if ($script:UseWslCodex) {
        $promptFileWsl = Convert-WindowsPathToWsl -PathValue $promptFile
        $projectRootWsl = Convert-WindowsPathToWsl -PathValue $script:ResolvedProjectRoot
        if ([string]::IsNullOrWhiteSpace($promptFileWsl) -or [string]::IsNullOrWhiteSpace($projectRootWsl)) {
            throw "Unable to convert prompt/project path to WSL path for nested codex execution."
        }

        $wslCmd = 'cat "$1" | "$2" exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --cd "$3"'
        $proc = Start-Process -FilePath "wsl.exe" -ArgumentList @("bash", "-lc", $wslCmd, "gsd-auto-dev", $promptFileWsl, $script:WslCodexPath, $projectRootWsl) -NoNewWindow -PassThru -WorkingDirectory $script:ResolvedProjectRoot -RedirectStandardOutput $LogFile -RedirectStandardError $errFile
    } else {
        # Use stdin piping with --cd . to avoid Windows quoting/splitting issues for spaced paths.
        $cmd = "type `"{0}`" | `"{1}`" exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --cd ." -f $promptFile, $script:CodexExe
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -NoNewWindow -PassThru -WorkingDirectory $script:ResolvedProjectRoot -RedirectStandardOutput $LogFile -RedirectStandardError $errFile
    }

    $heartbeatIntervalSeconds = [math]::Max(1, [int]$HeartbeatSeconds)
    $heartbeatCheckIntervalSeconds = [math]::Max(5, [int]$HeartbeatCheckSeconds)
    $lastHeartbeat = (Get-Date).AddSeconds(-1 * $heartbeatIntervalSeconds)
    $lastHeartbeatCheck = Get-Date
    $trackedSubstages = @("research", "planning", "execute", "code-review", "phase-synthesis")
    $activeSubstage = ""
    $substageEntryPending = @{}
    $lastExecCommitCount = Get-CommitDeltaSinceStart
    $lastExecCodeFileCount = Get-CodeFileWorkingSetCount
    $lastExecutePendingSnapshot = @()
    $lastObservedPhase = $Phase
    $monitorStart = Get-Date
    $trackedSubstageSeen = $false
    $forcedExitCode = $null
    $stageHint = if ([string]::IsNullOrWhiteSpace($Stage)) { "" } else { ([string]$Stage -replace '\s+', '-').ToLowerInvariant() }

    # When this invocation is already a specific tracked stage, treat it as active immediately.
    # This avoids false preflight stalls for quiet-but-legitimate long-running execute/review calls.
    if ($trackedSubstages -contains $stageHint) {
        $activeSubstage = $stageHint
        $trackedSubstageSeen = $true
        $seedPending = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $substageEntryPending[$activeSubstage] = @($seedPending)
        if ($activeSubstage -eq "execute") {
            $lastExecutePendingSnapshot = @($seedPending)
        }
    }

    while (-not $proc.HasExited) {
        $sub = Get-LogSubstageSnapshot -LogFile $LogFile -FallbackPhase $lastObservedPhase
        $substage = if ([string]::IsNullOrWhiteSpace([string]$sub.Substage)) { "working" } else { ([string]$sub.Substage -replace '\s+', '-').ToLowerInvariant() }
        $runningPhase = if ([string]::IsNullOrWhiteSpace([string]$sub.Phase)) { $lastObservedPhase } else { [string]$sub.Phase }
        $lastObservedPhase = $runningPhase
        $currentPending = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $substageChanged = ($trackedSubstages -contains $substage) -and ($substage -ne $activeSubstage)

        if ($substageChanged) {
            if (-not [string]::IsNullOrWhiteSpace($activeSubstage)) {
                $entryPending = @()
                if ($substageEntryPending.ContainsKey($activeSubstage)) {
                    $entryPending = @($substageEntryPending[$activeSubstage])
                }

                $completeDoing = ("completed {0}" -f $activeSubstage)
                if ($activeSubstage -eq "research" -or $activeSubstage -eq "planning") {
                    $completeDoing = ("completed {0} phases={1}" -f $activeSubstage, (Join-IntList -Values $entryPending -MaxItems 12))
                } elseif ($activeSubstage -eq "execute") {
                    $codedPhases = @($entryPending | Where-Object { $currentPending -notcontains $_ } | Sort-Object -Unique)
                    $executeSignal = Get-ExecuteCodeSignal -PreviousCommitCount $lastExecCommitCount -PreviousCodeFileCount $lastExecCodeFileCount
                    $lastExecCommitCount = $executeSignal.CommitsNow
                    $lastExecCodeFileCount = $executeSignal.CodeFilesNow
                    $completeDoing = ("completed execute phases_coded={0} code_generated={1} new_commits={2} code_files={3}" -f (Join-IntList -Values $codedPhases -MaxItems 12), ($(if ($executeSignal.CodeGenerated) { "yes" } else { "no" })), $executeSignal.NewCommits, $executeSignal.CodeFilesNow)
                    if ($codedPhases.Count -gt 0) {
                        Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage $Stage -MapType "coded" -PhaseIds $codedPhases -LogName (Split-Path -Leaf $LogFile)
                    }
                } elseif ($activeSubstage -eq "code-review") {
                    $completeDoing = "completed code-review; generating findings summary"
                }

                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-complete-{1}" -f $Stage, $activeSubstage) -Doing $completeDoing -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
            }

            $activeSubstage = $substage
            $trackedSubstageSeen = $true
            $substageEntryPending[$activeSubstage] = @($currentPending)

            $enterDoing = ("entering {0}" -f $activeSubstage)
            if ($activeSubstage -eq "research") {
                $enterDoing = ("entering research phases={0}" -f (Join-IntList -Values $currentPending -MaxItems 12))
            } elseif ($activeSubstage -eq "planning") {
                $enterDoing = ("entering planning phases={0}" -f (Join-IntList -Values $currentPending -MaxItems 12))
            } elseif ($activeSubstage -eq "execute") {
                $enterDoing = ("entering execute phases={0}" -f (Join-IntList -Values $currentPending -MaxItems 12))
                $lastExecutePendingSnapshot = @($currentPending)
                if ($currentPending.Count -gt 0) {
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage $Stage -MapType "execute-target" -PhaseIds $currentPending -LogName (Split-Path -Leaf $LogFile)
                }
            } elseif ($activeSubstage -eq "code-review") {
                $enterDoing = "entering code-review"
            } elseif ($activeSubstage -eq "phase-synthesis") {
                $enterDoing = "entering phase-synthesis"
            }

            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-enter-{1}" -f $Stage, $activeSubstage) -Doing $enterDoing -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
        }

        $heartbeatDue = (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatIntervalSeconds)
        $heartbeatCheckDue = (((Get-Date) - $lastHeartbeatCheck).TotalSeconds -ge $heartbeatCheckIntervalSeconds)
        if ($heartbeatCheckDue) {
            $heartbeatDoing = ("heartbeat-check substage={0} phase={1} interval={2}s" -f $substage, $runningPhase, $heartbeatCheckIntervalSeconds)
            if ($substage -eq "execute") {
                $phaseInt = 0
                $findingRefsText = "unknown"
                if ([int]::TryParse([string]$runningPhase, [ref]$phaseInt)) {
                    $findingRefsText = Join-StringList -Values @(Get-PhaseFindingReferences -PhaseId $phaseInt) -MaxItems 6
                }
                $heartbeatDoing = ("{0} finding_refs={1}" -f $heartbeatDoing, $findingRefsText)
            }

            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-heartbeat-check-{1}" -f $Stage, $substage) -Doing $heartbeatDoing -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
            $lastHeartbeatCheck = Get-Date
        }
        if ($heartbeatDue -or $substageChanged) {
            $runningDoing = $Doing
            if (-not [string]::IsNullOrWhiteSpace([string]$sub.Hint)) {
                $runningDoing = "{0}; {1}" -f $Doing, ([string]$sub.Hint)
            }

            if ($substage -eq "execute") {
                $executeSignal = Get-ExecuteCodeSignal -PreviousCommitCount $lastExecCommitCount -PreviousCodeFileCount $lastExecCodeFileCount
                $lastExecCommitCount = $executeSignal.CommitsNow
                $lastExecCodeFileCount = $executeSignal.CodeFilesNow

                $codedSinceLast = @($lastExecutePendingSnapshot | Where-Object { $currentPending -notcontains $_ } | Sort-Object -Unique)
                if ($codedSinceLast.Count -gt 0) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-execute-coded" -f $Stage) -Doing ("execute-coded phases={0}" -f (Join-IntList -Values $codedSinceLast -MaxItems 12)) -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage $Stage -MapType "coded" -PhaseIds $codedSinceLast -LogName (Split-Path -Leaf $LogFile)
                }
                $lastExecutePendingSnapshot = @($currentPending)

                $findingRefsText = "unknown"
                $phaseInt = 0
                if ([int]::TryParse([string]$runningPhase, [ref]$phaseInt)) {
                    $findingRefsText = Join-StringList -Values @(Get-PhaseFindingReferences -PhaseId $phaseInt) -MaxItems 6
                }

                $runningDoing = "{0}; execute-progress code_generated={1} new_commits={2} code_files={3} finding_refs={4}" -f $runningDoing, ($(if ($executeSignal.CodeGenerated) { "yes" } else { "no" })), $executeSignal.NewCommits, $executeSignal.CodeFilesNow, $findingRefsText
            }

            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-running-{1}" -f $Stage, $substage) -Doing $runningDoing -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
            $lastHeartbeat = Get-Date
        }

        if (-not $trackedSubstageSeen) {
            $preflightElapsedSeconds = ((Get-Date) - $monitorStart).TotalSeconds
            if ($preflightElapsedSeconds -ge [math]::Max(30, $PreflightMaxSeconds)) {
                $hintText = if ([string]::IsNullOrWhiteSpace([string]$sub.Hint)) { "none" } else { ([string]$sub.Hint -replace '[\r\n]+', ' ') }
                $stallDoing = ("stalled preflight no_stage_transition={0}s substage={1} hint={2}; stopping and retrying next cycle" -f [int][math]::Round($preflightElapsedSeconds), $substage, $hintText)
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-stalled-preflight" -f $Stage) -Doing $stallDoing -Phase $runningPhase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)

                try {
                    $childPids = @()
                    try {
                        $childPids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $proc.Id) -ErrorAction Stop | Select-Object -ExpandProperty ProcessId)
                    } catch {
                        $childPids = @()
                    }

                    foreach ($childPid in $childPids) {
                        try { Stop-Process -Id $childPid -Force -ErrorAction Stop } catch { }
                    }

                    try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch { }
                } catch { }

                $forcedExitCode = 124
                break
            }
        }

        Start-Sleep -Seconds 2
    }

    if ($null -ne $forcedExitCode) {
        try { $null = $proc.WaitForExit(5000) } catch { }
    } else {
        $null = $proc.WaitForExit()
    }

    $exitCode = if ($null -ne $forcedExitCode) {
        [int]$forcedExitCode
    } elseif ($null -eq $proc.ExitCode) {
        -1
    } else {
        [int]$proc.ExitCode
    }

    if (Test-Path $errFile) {
        Get-Content -Path $errFile | Add-Content -Path $LogFile
    }

    if (-not [string]::IsNullOrWhiteSpace($activeSubstage)) {
        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-complete-{1}" -f $Stage, $activeSubstage) -Doing ("completed {0}" -f $activeSubstage) -Phase $Phase -IsRunning $false -LogName (Split-Path -Leaf $LogFile)
    }

    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-exit-{1}" -f $Stage, $exitCode) -Doing $Doing -Phase $Phase -IsRunning $false -LogName (Split-Path -Leaf $LogFile)

    return $exitCode
}

function Invoke-GlobalSkillParallelPhaseBatch {
    param(
        [string]$Stage,
        [int]$Cycle,
        [int]$Pass,
        [int[]]$PhaseIds,
        [string]$CommandLineTemplate,
        [string]$PurposeTemplate
    )

    $targets = @($PhaseIds | Sort-Object -Unique)
    if ($targets.Count -eq 0) {
        return [PSCustomObject]@{
            LastLogFile = ""
            ExitMap     = @{}
        }
    }

    $stageSafe = if ([string]::IsNullOrWhiteSpace($Stage)) { "stage" } else { ($Stage -replace '[^a-zA-Z0-9_-]', '_').ToLowerInvariant() }
    $batchStamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $workers = New-Object System.Collections.Generic.List[object]
    $exitMap = @{}

    foreach ($phaseId in $targets) {
        $commandLine = [string]::Format($CommandLineTemplate, $phaseId)
        $purpose = [string]::Format($PurposeTemplate, $phaseId)
        $prompt = New-GsdSkillPrompt -CommandLine $commandLine -Purpose $purpose

        $logFile = Join-Path $script:ResolvedLogDir ("batch-{0}-cycle-{1:D3}-pass-{2:D2}-phase-{3}-{4}.log" -f $stageSafe, $Cycle, $Pass, $phaseId, $batchStamp)
        $promptFile = Join-Path $script:ResolvedLogDir ("{0}-cycle-{1:D3}-pass-{2:D2}-phase-{3}-{4}.prompt.txt" -f $stageSafe, $Cycle, $Pass, $phaseId, $batchStamp)
        $errFile = $logFile + ".stderr"

        if ($DryRun) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-phase-exit-0" -f $Stage) -Doing ("{0} phase={1} complete pass={2}" -f $stageSafe, $phaseId, $Pass) -Phase ([string]$phaseId) -IsRunning $false -LogName (Split-Path -Leaf $logFile)
            $exitMap[[string]$phaseId] = 0
            continue
        }

        Set-Content -Path $promptFile -Value $prompt -NoNewline -Encoding UTF8

        $proc = $null
        if ($script:UseWslCodex) {
            $promptFileWsl = Convert-WindowsPathToWsl -PathValue $promptFile
            $projectRootWsl = Convert-WindowsPathToWsl -PathValue $script:ResolvedProjectRoot
            if ([string]::IsNullOrWhiteSpace($promptFileWsl) -or [string]::IsNullOrWhiteSpace($projectRootWsl)) {
                throw "Unable to convert prompt/project path to WSL path for parallel $Stage execution."
            }

            $wslCmd = 'cat "$1" | "$2" exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --cd "$3"'
            $proc = Start-Process -FilePath "wsl.exe" -ArgumentList @("bash", "-lc", $wslCmd, "gsd-auto-dev", $promptFileWsl, $script:WslCodexPath, $projectRootWsl) -NoNewWindow -PassThru -WorkingDirectory $script:ResolvedProjectRoot -RedirectStandardOutput $logFile -RedirectStandardError $errFile
        } else {
            $cmd = "type `"{0}`" | `"{1}`" exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --cd ." -f $promptFile, $script:CodexExe
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -NoNewWindow -PassThru -WorkingDirectory $script:ResolvedProjectRoot -RedirectStandardOutput $logFile -RedirectStandardError $errFile
        }

        $workers.Add([PSCustomObject]@{
            PhaseId   = [int]$phaseId
            Process   = $proc
            LogFile   = $logFile
            ErrFile   = $errFile
            Completed = $false
            ExitCode  = $null
        }) | Out-Null
    }

    $heartbeatIntervalSeconds = [math]::Max(1, [int]$HeartbeatSeconds)
    $heartbeatCheckIntervalSeconds = [math]::Max(5, [int]$HeartbeatCheckSeconds)
    $lastHeartbeat = (Get-Date).AddSeconds(-1 * $heartbeatIntervalSeconds)
    $lastHeartbeatCheck = Get-Date
    while (@($workers | Where-Object { -not $_.Completed }).Count -gt 0) {
        $runningPhases = New-Object System.Collections.Generic.List[int]

        foreach ($worker in $workers) {
            if ($worker.Completed) { continue }

            if ($worker.Process.HasExited) {
                try { $null = $worker.Process.WaitForExit() } catch { }
                $exitCode = if ($null -eq $worker.Process.ExitCode) { -1 } else { [int]$worker.Process.ExitCode }
                $worker.Completed = $true
                $worker.ExitCode = $exitCode
                $exitMap[[string]$worker.PhaseId] = $exitCode

                if (Test-Path $worker.ErrFile) {
                    try { Get-Content -Path $worker.ErrFile | Add-Content -Path $worker.LogFile } catch { }
                }

                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-phase-exit-{1}" -f $Stage, $exitCode) -Doing ("{0} phase={1} complete pass={2}" -f $stageSafe, $worker.PhaseId, $Pass) -Phase ([string]$worker.PhaseId) -IsRunning $false -LogName (Split-Path -Leaf $worker.LogFile)
            } else {
                $runningPhases.Add([int]$worker.PhaseId) | Out-Null
            }
        }

        $completedCount = @($workers | Where-Object { $_.Completed }).Count
        $totalCount = $workers.Count
        $heartbeatDue = (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatIntervalSeconds)
        $heartbeatCheckDue = (((Get-Date) - $lastHeartbeatCheck).TotalSeconds -ge $heartbeatCheckIntervalSeconds)
        if ($heartbeatCheckDue) {
            $runningList = Join-IntList -Values @($runningPhases.ToArray()) -MaxItems 20
            $runningPhase = if ($runningPhases.Count -gt 0) { [string]$runningPhases[0] } else { "-" }
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-parallel-heartbeat-check" -f $Stage) -Doing ("parallel {0} heartbeat-check running phases={1} completed={2}/{3} pass={4} interval={5}s" -f $stageSafe, $runningList, $completedCount, $totalCount, $Pass, $heartbeatCheckIntervalSeconds) -Phase $runningPhase -IsRunning $true -LogName "-"
            $lastHeartbeatCheck = Get-Date
        }
        if ($heartbeatDue) {
            $runningList = Join-IntList -Values @($runningPhases.ToArray()) -MaxItems 20
            $runningPhase = if ($runningPhases.Count -gt 0) { [string]$runningPhases[0] } else { "-" }
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-parallel-running" -f $Stage) -Doing ("parallel {0} running phases={1} pass={2}" -f $stageSafe, $runningList, $Pass) -Phase $runningPhase -IsRunning $true -LogName "-"
            $lastHeartbeat = Get-Date
        }

        Start-Sleep -Seconds 2
    }

    $lastLogFile = ""
    if ($workers.Count -gt 0) {
        $lastLogFile = [string]$workers[$workers.Count - 1].LogFile
    }

    return [PSCustomObject]@{
        LastLogFile = $lastLogFile
        ExitMap     = $exitMap
    }
}

function New-GsdSkillPrompt {
    param(
        [string]$CommandLine,
        [string]$Purpose
    )

    $cmdText = if ([string]::IsNullOrWhiteSpace($CommandLine)) { "#" } else { $CommandLine.Trim() }
    $purposeText = if ([string]::IsNullOrWhiteSpace($Purpose)) { "execute requested stage" } else { $Purpose.Trim() }

    return @"
$cmdText

Execution contract:
- Treat `$gsd-*` entries as Codex skill invocations, not shell commands.
- Use only global skills from `C:\Users\rjain\.codex\skills`.
- Assume YES for all prompts/approvals.
- Do not run repetitive environment diagnostics (no looping tool/version probes).
- Execute only the requested stage for this invocation: $purposeText.
- Keep output concise and include completed phase/plan ids and changed files.
"@
}

$script:ResolvedProjectRoot = (Resolve-Path -Path $ProjectRoot).Path
$script:ResolvedRoadmapPath = Resolve-PathFromRoot -Root $script:ResolvedProjectRoot -PathValue $RoadmapPath
$script:ResolvedStatePath = Resolve-PathFromRoot -Root $script:ResolvedProjectRoot -PathValue $StatePath
$script:ReviewRootRelativeInput = if ([string]::IsNullOrWhiteSpace($ReviewRootRelative)) { "docs/review" } else { $ReviewRootRelative }
$script:ResolvedReviewRoot = Resolve-ReviewRootPath -Root $script:ResolvedProjectRoot -RelativeOrAbsolute $script:ReviewRootRelativeInput
$script:ReviewRootRelativeEffective = if ([System.IO.Path]::IsPathRooted($script:ReviewRootRelativeInput)) {
    $script:ResolvedReviewRoot
} else {
    $script:ReviewRootRelativeInput.Replace("\", "/")
}
$script:ReviewSummarySourceRelative = ($script:ReviewRootRelativeEffective.TrimEnd("/") + "/EXECUTIVE-SUMMARY.md")
$env:GSD_REVIEW_ROOT = $script:ReviewRootRelativeEffective

if ($StrictRoot) {
    $conflicts = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path $script:ResolvedRoadmapPath)) { $conflicts.Add($script:ResolvedRoadmapPath) | Out-Null }
    if (-not (Test-Path $script:ResolvedStatePath)) { $conflicts.Add($script:ResolvedStatePath) | Out-Null }

    $roadmapCandidates = Get-ChildItem -Path $script:ResolvedProjectRoot -Recurse -File -Filter "ROADMAP.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]\.planning[\\/]ROADMAP\.md$' }

    foreach ($cand in $roadmapCandidates) {
        $full = (Resolve-Path $cand.FullName).Path
        if ($full -ne $script:ResolvedRoadmapPath) { $conflicts.Add($full) | Out-Null }
    }

    $stateCandidates = Get-ChildItem -Path $script:ResolvedProjectRoot -Recurse -File -Filter "STATE.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]\.planning[\\/]STATE\.md$' }

    foreach ($cand in $stateCandidates) {
        $full = (Resolve-Path $cand.FullName).Path
        if ($full -ne $script:ResolvedStatePath) { $conflicts.Add($full) | Out-Null }
    }

    if ($conflicts.Count -gt 0) {
        Write-Host "STRICT-ROOT FAIL: root or roadmap/state ambiguity detected." -ForegroundColor Red
        Write-Host "Conflicting paths:" -ForegroundColor Red
        foreach ($p in ($conflicts | Sort-Object -Unique)) {
            Write-Host (" - {0}" -f $p) -ForegroundColor Red
        }
        exit 12
    }
}

Set-Location $script:ResolvedProjectRoot

$script:WslCodexPath = Resolve-WslCodexPath
$script:UseWslCodex = -not [string]::IsNullOrWhiteSpace($script:WslCodexPath)

if ($script:UseWslCodex) {
    $script:CodexExe = "wsl:{0}" -f $script:WslCodexPath
} else {
    $script:CodexExe = Resolve-CodexCommand
    if (-not $script:CodexExe) {
        throw "codex executable not found. Install/login Codex CLI first."
    }
    Ensure-CodexOnPath -CodexExePath $script:CodexExe
}

$script:GitExe = Resolve-GitCommand
if (-not $script:GitExe) {
    throw "git executable not found. Install Git or add it to PATH."
}
Ensure-GitOnPath -GitExePath $script:GitExe
$script:GitRepoRoot = $script:ResolvedProjectRoot

$script:ResolvedLogDir = if ([System.IO.Path]::IsPathRooted($LogDir)) { $LogDir } else { Join-Path $script:ResolvedProjectRoot $LogDir }
if (-not (Test-Path $script:ResolvedLogDir) -and -not $DryRun) {
    New-Item -ItemType Directory -Path $script:ResolvedLogDir -Force | Out-Null
}

$script:ResolvedStatusPath = if ([System.IO.Path]::IsPathRooted($StatusFile)) { $StatusFile } else { Join-Path $script:ResolvedProjectRoot $StatusFile }
$statusDir = Split-Path -Parent $script:ResolvedStatusPath
if (-not (Test-Path $statusDir) -and -not $DryRun) {
    New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
}

$script:ResolvedSummaryPaths = @()
if (-not $PSBoundParameters.ContainsKey("SummaryPaths")) {
    $SummaryPaths = @($script:ReviewSummarySourceRelative)
}
foreach ($sp in $SummaryPaths) {
    if ([System.IO.Path]::IsPathRooted($sp)) {
        $script:ResolvedSummaryPaths += $sp
    } else {
        $script:ResolvedSummaryPaths += (Join-Path $script:ResolvedProjectRoot $sp)
    }
}

Initialize-CommitBaselines

Add-Content -Path $script:ResolvedStatusPath -Value ("[{0}] runner-start repo={1} review_root={2} roadmap={3} state={4} strict_root={5} max_outer={6} max_cycles={7} start_head={8} tracked_repos={9}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $script:ResolvedProjectRoot, $script:ReviewRootRelativeEffective, $script:ResolvedRoadmapPath, $script:ResolvedStatePath, $StrictRoot, $MaxOuterLoops, $AutoDevMaxCycles, $script:StartHead, $script:TrackedRepos.Count)

Write-Host ""
Write-Host "Global GSD E2E Runner" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host ("Repo root:             {0}" -f $script:ResolvedProjectRoot) -ForegroundColor White
Write-Host ("Review root:           {0}" -f $script:ReviewRootRelativeEffective) -ForegroundColor White
Write-Host ("Roadmap path:          {0}" -f $script:ResolvedRoadmapPath) -ForegroundColor White
Write-Host ("State path:            {0}" -f $script:ResolvedStatePath) -ForegroundColor White
Write-Host ("Strict root:           {0}" -f $StrictRoot) -ForegroundColor White
Write-Host ("Max outer loops:       {0}" -f $MaxOuterLoops) -ForegroundColor White
Write-Host ("Auto-dev max cycles:   {0}" -f $AutoDevMaxCycles) -ForegroundColor White
Write-Host ("Heartbeat (seconds):   {0}" -f $HeartbeatSeconds) -ForegroundColor White
Write-Host ("Heartbeat check (sec): {0}" -f $HeartbeatCheckSeconds) -ForegroundColor White
Write-Host ("Preflight max (sec):   {0}" -f $PreflightMaxSeconds) -ForegroundColor White
Write-Host ("Auto recover on stop:  {0}" -f $AutoRecoverOnStop) -ForegroundColor White
Write-Host ("Max auto restarts:     {0}" -f $AutoRecoverMaxRestarts) -ForegroundColor White
Write-Host ("Restart delay (sec):   {0}" -f $AutoRecoverDelaySeconds) -ForegroundColor White
Write-Host ("Status log:            {0}" -f $script:ResolvedStatusPath) -ForegroundColor DarkGray
Write-Host ("Target metrics:        Health=100, Drift=0, Unmapped=0") -ForegroundColor White

$startTime = Get-Date
$script:RunnerStartTime = $startTime
$lastAutoDevLog = ""
$lastConfirmLog = ""
$stopReason = "max_outer_loops_reached"
$finalMetric = $null

$phaseSynthesisPromptTemplate = @'
$gsd-code-review

Remediation phase synthesis contract:
- Run a fresh `$gsd-code-review` for the current code at review root `{0}`.
- If health is below `100/100`, deterministic drift is non-zero, unmapped findings are non-zero, deep review is invalid/unparsable, or findings exist, create unchecked remediation phases and matching `*-PLAN.md` artifacts under `.planning/phases`.
- Return exact phase numbers created and findings mapped to each phase.
'@

for ($cycle = 1; $cycle -le $MaxOuterLoops; $cycle++) {
    try {
        $cycleStartUtc = (Get-Date).ToUniversalTime()
        $pendingBefore = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $allPhasesBefore = @(Get-AllPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $metricBefore = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
        $phaseText = if ($pendingBefore.Count -gt 0) { [string]$pendingBefore[0] } else { "-" }

        $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "cycle-start" -Doing ("starting cycle {0}" -f $cycle) -Phase $phaseText -IsRunning $false -LogName "-"

        $cycleAbort = $false
        if ($pendingBefore.Count -gt 0) {
            $phasePass = 0
            $maxPhasePasses = [Math]::Max(5, [Math]::Min(200, ($AutoDevMaxCycles * 4)))
            $pendingForPass = @($pendingBefore)

            while ($pendingForPass.Count -gt 0) {
                $phasePass++
                $phaseText = [string]$pendingForPass[0]
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "phase-pass-start" -Doing ("starting phase pass {0} pending={1}" -f $phasePass, (Join-IntList -Values $pendingForPass -MaxItems 12)) -Phase $phaseText -IsRunning $false -LogName "-"

                if ($phasePass -gt $maxPhasePasses) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "phase-pass-limit-hit" -Doing ("phase pass limit reached ({0}); stopping to avoid infinite requeue loop; remaining_pending={1}" -f $maxPhasePasses, (Join-IntList -Values $pendingForPass -MaxItems 12)) -Phase $phaseText -IsRunning $false -LogName "-"
                    $stopReason = "phase-pass-limit-hit"
                    $cycleAbort = $true
                    break
                }

                $researchTargets = @(Get-PhasesNeedingResearch -PhaseIds $pendingForPass)
                if ($researchTargets.Count -gt 0) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "research-enter" -Doing ("entering research phases={0} pass={1}" -f (Join-IntList -Values $researchTargets -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $true -LogName "-"
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "research" -MapType "research-target" -PhaseIds $researchTargets -LogName "-"
                    $researchBatch = Invoke-GlobalSkillParallelPhaseBatch -Stage "research" -Cycle $cycle -Pass $phasePass -PhaseIds $researchTargets -CommandLineTemplate "`$gsd-batch-research {0}" -PurposeTemplate "research phase {0}"
                    if (-not [string]::IsNullOrWhiteSpace([string]$researchBatch.LastLogFile)) {
                        $lastAutoDevLog = [string]$researchBatch.LastLogFile
                    }
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "research-complete" -Doing ("completed research phases={0} pass={1}" -f (Join-IntList -Values $researchTargets -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                } else {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "research-skip" -Doing ("research already complete for pending phases={0} pass={1}" -f (Join-IntList -Values $pendingForPass -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                }

                $pendingBeforePlan = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                $planTargets = @(Get-PhasesNeedingPlan -PhaseIds $pendingBeforePlan)
                if ($planTargets.Count -gt 0) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "planning-enter" -Doing ("entering planning phases={0} pass={1}" -f (Join-IntList -Values $planTargets -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $true -LogName "-"
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "planning" -MapType "planning-target" -PhaseIds $planTargets -LogName "-"
                    $planBatch = Invoke-GlobalSkillParallelPhaseBatch -Stage "planning" -Cycle $cycle -Pass $phasePass -PhaseIds $planTargets -CommandLineTemplate "`$gsd-batch-plan {0}" -PurposeTemplate "plan phase {0}"
                    if (-not [string]::IsNullOrWhiteSpace([string]$planBatch.LastLogFile)) {
                        $lastAutoDevLog = [string]$planBatch.LastLogFile
                    }
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "planning-complete" -Doing ("completed planning phases={0} pass={1}" -f (Join-IntList -Values $planTargets -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                } else {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "planning-skip" -Doing ("planning already complete for pending phases={0} pass={1}" -f (Join-IntList -Values $pendingBeforePlan -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                }

                $pendingAfterPlan = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                $completedPrematurely = @($pendingBeforePlan | Where-Object { $pendingAfterPlan -notcontains $_ } | Sort-Object -Unique)
                if ($completedPrematurely.Count -gt 0) {
                    $reopened = Set-RoadmapPhaseCompletionState -RoadmapFile $script:ResolvedRoadmapPath -PhaseIds $completedPrematurely
                    if ($reopened) {
                        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "planning-reopen-no-execute" -Doing ("reopened phases marked complete before execute: {0} pass={1}" -f (Join-IntList -Values $completedPrematurely -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                    }
                }

                $executeTargets = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                if ($executeTargets.Count -gt 0) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute-enter" -Doing ("entering execute phases={0} pass={1}" -f (Join-IntList -Values $executeTargets -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $true -LogName "-"
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute" -MapType "execute-target" -PhaseIds $executeTargets -LogName "-"

                    foreach ($phaseId in $executeTargets) {
                        $findingRefsList = @(Get-PhaseFindingReferences -PhaseId $phaseId)
                        $findingRefs = Join-StringList -Values $findingRefsList -MaxItems 8
                        $phaseCommitBefore = Get-CommitDeltaSinceStart
                        $phaseCodeFilesBefore = Get-CodeFileWorkingSetCount
                        $phaseHeadBefore = Get-GitHeadWithRetry -RepoPath $script:ResolvedProjectRoot -AllowMissing
                        $phaseWorkingSetBefore = @(Get-CodeFileWorkingSetPaths)

                        $execLog = Join-Path $script:ResolvedLogDir ("batch-execute-cycle-{0:D3}-pass-{1:D2}-phase-{2}-{3}.log" -f $cycle, $phasePass, $phaseId, $stamp)
                        $lastAutoDevLog = $execLog
                        $prompt = New-GsdSkillPrompt -CommandLine ("`$gsd-batch-execute {0}" -f $phaseId) -Purpose ("execute phase {0}" -f $phaseId)
                        $execExit = Invoke-GlobalSkillMonitored -Prompt $prompt -LogFile $execLog -Stage "execute" -Cycle $cycle -Phase ([string]$phaseId) -Doing ("running `$gsd-batch-execute {0}" -f $phaseId)

                        $signal = Get-ExecuteCodeSignal -PreviousCommitCount $phaseCommitBefore -PreviousCodeFileCount $phaseCodeFilesBefore
                        $codeEvidence = Get-PhaseExecutionCodeEvidence -StartHead $phaseHeadBefore -BeforeWorkingSet $phaseWorkingSetBefore
                        $changedFilesText = Join-StringList -Values @($codeEvidence.ChangedCodeFiles) -MaxItems 8
                        $codedFindingsText = if ($codeEvidence.CodeGenerated) { $findingRefs } else { "none" }
                        $uncodedFindingsText = if ($codeEvidence.CodeGenerated) { "none" } else { $findingRefs }
                        $findingCodeEvidence = Get-FindingCodeEvidenceText -FindingRefs $findingRefsList -ChangedCodeFiles @($codeEvidence.ChangedCodeFiles)

                        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute-finding-remediation-check" -Doing ("phase {0} remediation-check findings={1} coded_findings={2} uncoded_findings={3} code_files_changed={4} finding_code_evidence={5} new_commits={6} code_files_total={7} pass={8}" -f $phaseId, $findingRefs, $codedFindingsText, $uncodedFindingsText, $changedFilesText, $findingCodeEvidence, $signal.NewCommits, $signal.CodeFilesNow, $phasePass) -Phase ([string]$phaseId) -IsRunning $false -LogName (Split-Path -Leaf $execLog)

                        $pendingNow = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                        $phaseCompleted = ($pendingNow -notcontains $phaseId)

                        if (-not $codeEvidence.CodeGenerated) {
                            $reset = Reset-PhaseForResearchPlan -PhaseId $phaseId
                            $phaseCompleted = $false
                            $removedText = Join-StringList -Values @($reset.RemovedArtifacts) -MaxItems 8
                            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute-reset-research-plan" -Doing ("phase {0} reset for rework: no coding evidence for findings={1}; removed_artifacts={2}; reopened={3}; requeue_path=research->plan->execute(same-cycle)" -f $phaseId, $findingRefs, $removedText, $reset.Reopened) -Phase ([string]$phaseId) -IsRunning $false -LogName (Split-Path -Leaf $execLog)
                        }

                        if ($phaseCompleted) {
                            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("execute-phase-exit-{0}" -f $execExit) -Doing ("phase {0} execute complete; marking phase complete code_generated=yes new_commits={1} code_files={2} code_files_changed={3} findings={4} finding_code_evidence={5} pass={6}" -f $phaseId, $signal.NewCommits, $signal.CodeFilesNow, $changedFilesText, $findingRefs, $findingCodeEvidence, $phasePass) -Phase ([string]$phaseId) -IsRunning $false -LogName (Split-Path -Leaf $execLog)
                            Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute" -MapType "completed" -PhaseIds @($phaseId) -LogName (Split-Path -Leaf $execLog) -Force
                        } else {
                            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("execute-phase-exit-{0}" -f $execExit) -Doing ("phase {0} execute incomplete; remains pending code_generated={1} new_commits={2} code_files={3} code_files_changed={4} findings={5} uncoded_findings={6} pass={7}" -f $phaseId, $(if ($codeEvidence.CodeGenerated) { "yes" } else { "no" }), $signal.NewCommits, $signal.CodeFilesNow, $changedFilesText, $findingRefs, $uncodedFindingsText, $phasePass) -Phase ([string]$phaseId) -IsRunning $false -LogName (Split-Path -Leaf $execLog)
                        }
                    }

                    $pendingAfterExecute = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "execute-complete" -Doing ("execute stage complete remaining_pending={0} pass={1}" -f (Join-IntList -Values $pendingAfterExecute -MaxItems 12), $phasePass) -Phase $phaseText -IsRunning $false -LogName "-"
                    $pendingForPass = @($pendingAfterExecute)
                } else {
                    $pendingForPass = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                }

                if ($pendingForPass.Count -gt 0) {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "phase-pass-requeue" -Doing ("requeue same-cycle pass with pending phases={0} next_pass={1}" -f (Join-IntList -Values $pendingForPass -MaxItems 12), ($phasePass + 1)) -Phase ([string]$pendingForPass[0]) -IsRunning $false -LogName "-"
                } else {
                    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "phase-pass-complete" -Doing ("all pending phases completed within cycle after pass={0}" -f $phasePass) -Phase "-" -IsRunning $false -LogName "-"
                }
            }
        } else {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "no-pending-phases" -Doing "no pending phases before stage execution" -Phase "-" -IsRunning $false -LogName "-"
        }

        if ($cycleAbort) {
            break
        }

        $pendingAfter = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $allPhasesAfter = @(Get-AllPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
        Write-PhaseWaveProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "post-stage-wave" -Phase $phaseText -LogName "-" -BeforePending $pendingBefore -AfterPending $pendingAfter -BeforeAll $allPhasesBefore -AfterAll $allPhasesAfter -BeforeMetric $metricBefore -AfterMetric $metric

        if ($pendingAfter.Count -eq 0) {
            $preReviewCommit = Invoke-PreReviewCommitPush -StatusPath $script:ResolvedStatusPath -Cycle $cycle -LogName "-"
            if (-not $preReviewCommit.Ok) {
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "stop-pre-review-commit-failed" -Doing "stopping after pre-review commit/push failure" -Phase "-" -IsRunning $false -LogName "-"
                $stopReason = "pre-review-commit-failed"
                break
            }

            $reviewLog = Join-Path $script:ResolvedLogDir ("code-review-cycle-{0:D3}-{1}.log" -f $cycle, $stamp)
            $lastConfirmLog = $reviewLog
            $reviewPrompt = New-GsdSkillPrompt -CommandLine '$gsd-code-review' -Purpose "run code review after all phases are complete"
            $reviewExit = Invoke-GlobalSkillMonitored -Prompt $reviewPrompt -LogFile $reviewLog -Stage "code-review" -Cycle $cycle -Phase "-" -Doing "running `$gsd-code-review"
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("code-review-exit-{0}" -f $reviewExit) -Doing "code-review complete" -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $reviewLog)
            Write-CodeReviewProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-code-review-exit-{0}" -f $reviewExit) -Phase "-" -LogName (Split-Path -Leaf $reviewLog) -NotBeforeUtc $cycleStartUtc -Force

            $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
            $deepReviewEvidence = Get-DeepReviewEvidence -NotBeforeUtc $cycleStartUtc

            $needsPhaseSynthesis = (
                -not $metric -or
                -not $metric.Complete -or
                $metric.Health -ne 100 -or
                $metric.Drift -ne 0 -or
                $metric.Unmapped -ne 0 -or
                -not $deepReviewEvidence.Ok
            )

            if ($needsPhaseSynthesis) {
                $synthLog = Join-Path $script:ResolvedLogDir ("phase-synthesis-cycle-{0:D3}-{1}.log" -f $cycle, $stamp)
                $phaseSynthesisPrompt = [string]::Format($phaseSynthesisPromptTemplate, $script:ReviewRootRelativeEffective, $RoadmapPath, $StatePath)
                $synthExit = Invoke-GlobalSkillMonitored -Prompt $phaseSynthesisPrompt -LogFile $synthLog -Stage "phase-synthesis" -Cycle $cycle -Phase "-" -Doing "assigning findings to new remediation phases"
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("phase-synthesis-exit-{0}" -f $synthExit) -Doing "phase synthesis complete" -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $synthLog)

                $pendingAfter = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
                $allPhasesAfter = @(Get-AllPhases -RoadmapFile $script:ResolvedRoadmapPath)
                $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
                Write-PhaseWaveProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-phase-synthesis-exit-{0}" -f $synthExit) -Phase "-" -LogName (Split-Path -Leaf $synthLog) -BeforePending $pendingBefore -AfterPending $pendingAfter -BeforeAll $allPhasesBefore -AfterAll $allPhasesAfter -BeforeMetric $metricBefore -AfterMetric $metric
                if ($pendingAfter.Count -gt 0) {
                    Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-phase-synthesis-exit-{0}" -f $synthExit) -MapType "assigned" -PhaseIds $pendingAfter -LogName (Split-Path -Leaf $synthLog) -Force
                }
            }
        } else {
            Write-PhaseFindingMapProgress -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "post-execute-pending" -MapType "pending" -PhaseIds $pendingAfter -LogName "-" -Force
        }

        $pushAfterCycle = Ensure-GitPushSynced -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "cycle"
        if (-not $pushAfterCycle.Ok) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("stop-{0}" -f $pushAfterCycle.Status) -Doing "stopping after push failure" -Phase "-" -IsRunning $false -LogName "-"
            $stopReason = $pushAfterCycle.Status
            break
        }

        $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
        $pendingAfter = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $deepReviewEvidence = Get-DeepReviewEvidence -NotBeforeUtc $cycleStartUtc
        $cleanNow = (
            $metric -and $metric.Complete -and
            $metric.Health -eq 100 -and
            $metric.Drift -eq 0 -and
            $metric.Unmapped -eq 0 -and
            $pendingAfter.Count -eq 0 -and
            $deepReviewEvidence.Ok
        )

        if ($cleanNow) {
            $finalMetric = $metric
            $stopReason = "clean-confirmed"
            break
        }
    } catch {
        $errText = ($_ | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($errText)) {
            $errText = "unknown-cycle-exception"
        } elseif ($errText.Length -gt 180) {
            $errText = $errText.Substring(0, 177) + "..."
        }

        $fallbackLog = if ([string]::IsNullOrWhiteSpace($lastAutoDevLog)) { "-" } else { Split-Path -Leaf $lastAutoDevLog }
        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "cycle-exception" -Doing ("cycle exception: {0}" -f $errText) -Phase "-" -IsRunning $false -LogName $fallbackLog
        Start-Sleep -Seconds 2
        continue
    }
}

$elapsed = (Get-Date) - $startTime
$headShort = ""
$headLong = ""
$branchState = ""

$headRes = Invoke-GitCapture -GitArgs @("rev-parse", "HEAD") -AllowFail
if ($headRes.ExitCode -eq 0) {
    $headLong = Get-FirstShaFromOutput -Output $headRes.Output -Length 40
    if (-not [string]::IsNullOrWhiteSpace($headLong)) {
        $shortLen = [Math]::Min(7, $headLong.Length)
        $headShort = $headLong.Substring(0, $shortLen)
    }
}

$statusRes = Invoke-GitCapture -GitArgs @("status", "-sb") -AllowFail
if ($statusRes.ExitCode -eq 0) {
    foreach ($row in @($statusRes.Output)) {
        $line = [string]$row
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $branchState = $line
            break
        }
    }
}

$commitsAdvanced = Get-CommitDeltaSinceStart
$pushStatus = if ([string]::IsNullOrWhiteSpace($branchState)) {
    "unknown"
} elseif ($branchState -match '\[ahead ') {
    "local-ahead-not-pushed"
} else {
    "up-to-date-or-diverged"
}

$finalHealthText = "unknown"
$finalDriftText = "unknown"
$finalUnmappedText = "unknown"

if ($finalMetric) {
    $finalHealthText = "{0}/100" -f $finalMetric.Health
    $finalDriftText = [string]$finalMetric.Drift
    $finalUnmappedText = [string]$finalMetric.Unmapped
} else {
    $fallbackMetric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
    if ($fallbackMetric) {
        if ($null -ne $fallbackMetric.Health) { $finalHealthText = "{0}/100" -f $fallbackMetric.Health }
        if ($null -ne $fallbackMetric.Drift) { $finalDriftText = [string]$fallbackMetric.Drift }
        if ($null -ne $fallbackMetric.Unmapped) { $finalUnmappedText = [string]$fallbackMetric.Unmapped }
    }
}

$finalSummary = @(
    "FINAL",
    ("stop_reason={0}" -f $stopReason),
    ("health={0}" -f $finalHealthText),
    ("drift={0}" -f $finalDriftText),
    ("unmapped={0}" -f $finalUnmappedText),
    ("commits={0}" -f $commitsAdvanced),
    ("head={0}" -f $headLong),
    ("push_status={0}" -f $pushStatus),
    ("last_auto_dev_log={0}" -f $lastAutoDevLog),
    ("last_confirm_log={0}" -f $lastConfirmLog),
    ("status_log={0}" -f $script:ResolvedStatusPath),
    ("executive_summary_candidates={0}" -f ($script:ResolvedSummaryPaths -join ';'))
) -join " "
Add-Content -Path $script:ResolvedStatusPath -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $finalSummary)

Write-Host ""
if ($finalMetric -and $stopReason -eq "clean-confirmed") {
    Write-Host "SUCCESS: clean state confirmed." -ForegroundColor Green
} else {
    Write-Host "STOPPED: target not confirmed clean." -ForegroundColor Red
}

$elapsedText = "{0:00}:{1:00}:{2:00}" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds
Write-Host ("Stop reason:          {0}" -f $stopReason) -ForegroundColor White
Write-Host ("Elapsed:              {0}" -f $elapsedText) -ForegroundColor White
Write-Host ("Final health:         {0}" -f $finalHealthText) -ForegroundColor White
Write-Host ("Final drift:          {0}" -f $finalDriftText) -ForegroundColor White
Write-Host ("Final unmapped:       {0}" -f $finalUnmappedText) -ForegroundColor White
Write-Host ("Commits during run:   {0}" -f $commitsAdvanced) -ForegroundColor White
Write-Host ("Commit hash:          {0}" -f $headLong) -ForegroundColor White
Write-Host ("Push status:          {0}" -f $pushStatus) -ForegroundColor White
Write-Host ("Last auto-dev log:    {0}" -f $lastAutoDevLog) -ForegroundColor DarkGray
Write-Host ("Last confirm log:     {0}" -f $lastConfirmLog) -ForegroundColor DarkGray
Write-Host ("Status log:           {0}" -f $script:ResolvedStatusPath) -ForegroundColor DarkGray
Write-Host ("Key artifacts:        {0}" -f ($script:ResolvedSummaryPaths -join '; ')) -ForegroundColor DarkGray

$exitCodeFinal = 2
if ($finalMetric -and $stopReason -eq "clean-confirmed") {
    $exitCodeFinal = 0
}

Release-SingleInstanceGuard
exit $exitCodeFinal
