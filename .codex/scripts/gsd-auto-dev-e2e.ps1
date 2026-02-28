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
    [switch]$OpenWindow,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($OpenWindow) {
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
    StrictRoot = $strictLiteral
$summaryLine
}
$dryLine
& '$selfEsc' @params
"@
    Set-Content -Path $launcherPath -Value $launcherContent -Encoding UTF8

    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $launcherPath)
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WindowStyle Normal -PassThru
    Write-Host ("Launched gsd-auto-dev-e2e in a new PowerShell window (PID={0})." -f $proc.Id) -ForegroundColor Green
    return
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
            All    = @($rows)
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
        Reason = ($reasons -join ",")
        Best   = $best
        All    = @($rows)
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

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = '[{0}] cycle={1} stage={2} doing="{3}" phase={4} phases(completed={5},in_progress={6},pending={7}) target(h=100,d=0,u=0) current(h={8},d={9},u={10}) commits={11} log={12}' -f `
        $ts, $Cycle, $Stage, $Doing, $Phase, $phaseCounts.Completed, $phaseCounts.InProgress, $phaseCounts.Pending, $healthText, $driftText, $unmappedText, $commitsDone, $LogName

    Add-Content -Path $StatusPath -Value $line
    Write-Host $line -ForegroundColor Green
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

    Write-Host "" 
    Write-Host ("Headless command: codex exec ... ({0})" -f $Stage) -ForegroundColor DarkGray

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

    $lastHeartbeat = (Get-Date).AddSeconds(-1 * [math]::Max(1, $HeartbeatSeconds))

    while (-not $proc.HasExited) {
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $HeartbeatSeconds) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-running" -f $Stage) -Doing $Doing -Phase $Phase -IsRunning $true -LogName (Split-Path -Leaf $LogFile)
            $lastHeartbeat = Get-Date
        }

        Start-Sleep -Seconds 2
    }

    $null = $proc.WaitForExit()
    $exitCode = if ($null -eq $proc.ExitCode) { -1 } else { [int]$proc.ExitCode }

    if (Test-Path $errFile) {
        Get-Content -Path $errFile | Add-Content -Path $LogFile
    }

    Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $Cycle -Stage ("{0}-exit-{1}" -f $Stage, $exitCode) -Doing $Doing -Phase $Phase -IsRunning $false -LogName (Split-Path -Leaf $LogFile)

    return $exitCode
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
Write-Host ("Status log:            {0}" -f $script:ResolvedStatusPath) -ForegroundColor DarkGray
Write-Host ("Target metrics:        Health=100, Drift=0, Unmapped=0") -ForegroundColor White

$startTime = Get-Date
$lastAutoDevLog = ""
$lastConfirmLog = ""
$stopReason = "max_outer_loops_reached"
$finalMetric = $null

$autoDevCommand = '$gsd-auto-dev --write --max-cycles ' + $AutoDevMaxCycles + ' --project-root "' + $script:ResolvedProjectRoot + '" --roadmap-path "' + $RoadmapPath + '" --state-path "' + $StatePath + '" --strict-root'

$autoDevPromptTemplate = @'
{0}

Execution contract:
- Treat `$gsd-*` entries as Codex skill invocations, not shell commands.
- Use only global skills from `C:\Users\rjain\.codex\skills` for all `/gsd` commands.
- Assume YES for all prompts/approvals.
- In each cycle, process pending phases by stage:
  1) parallel multi-agent research for all pending phases needing research,
  2) parallel multi-agent planning for all pending phases needing plans,
  3) sequential execution of phases in deterministic roadmap order.
- Review artifact root for this run: `{4}`.
- During `$gsd-code-review`, run detailed review with parallel multi-agent fan-out for layers/gates, then aggregate deterministically.
- During `$gsd-code-review`, you MUST run a fresh deep code review against current code (frontend/backend/database/auth/agent) with security + dead-code + contract analysis against latest Figma + spec/docs.
- Forbidden: manually patching `{4}/EXECUTIVE-SUMMARY.md` to reset or force `Health`, `Code Review Totals`, or `Deep Review Totals`.
- Forbidden: any `Deep Review Totals: STATUS=INGESTED` sourced from `{4}/EXECUTIVE-SUMMARY.md`.
- Require fresh `{4}/layers/code-review-summary.json` from this run with `lineTraceability.status=PASSED`.
- Require `deepReview.status` to be parseable and not `UNPARSABLE`/`INGESTED`, with non-negative deep-review health and parseable TOTAL_FINDINGS in the same artifact.
- If review is non-clean (health<100, drift>0, unmapped>0, deep-review invalid/unparsable, or findings>0) and pending phase count is 0, you MUST synthesize new remediation phases + plans immediately before ending the cycle.
- Use the native shell available on this host (Windows cmd/PowerShell). Do not require Bash.
- For scripted operations, prefer explicit PowerShell path:
  - `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "<...>"`
- Avoid complex nested quoting in `cmd.exe /c` one-liners; split work into simpler commands.
- Strict root must remain enforced with:
  - project root `{1}`
  - roadmap path `{2}`
  - state path `{3}`
- If root/roadmap is ambiguous, fail fast and print conflicting paths.
- If commit/push fails, auto-fix git issues and retry until push succeeds before continuing.
- Mandatory progress update every 1 minute including:
  - what script is currently doing
  - current phase counts (completed, in progress, pending)
  - target metrics (health=100, drift=0, unmapped=0)
  - current metrics (health, drift, unmapped)
  - git commits completed so far in this run
'@
$autoDevPrompt = [string]::Format($autoDevPromptTemplate, $autoDevCommand, $script:ResolvedProjectRoot, $RoadmapPath, $StatePath, $script:ReviewRootRelativeEffective)

$confirmPromptTemplate = @'
$gsd-code-review

Confirmation contract:
- No code changes between clean-candidate pass and this confirmation pass.
- Re-run full deep `$gsd-code-review` on current HEAD (do not reuse or summarize prior artifacts only).
- Required scope: deep multi-agent security/dead-code/contract analysis across code files versus latest Figma + docs/spec.
- Review artifact root for this run: `{0}`.
- Forbidden: manual edits that force `Health`, `Code Review Totals`, or `Deep Review Totals`.
- Forbidden: `Deep Review Totals: STATUS=INGESTED` from summary artifact source.
- Regenerate `{0}/layers/code-review-summary.json` and keep `lineTraceability.status=PASSED`.
- Report health, deterministic drift total, and unmapped findings.
- Include current commit hash and whether results remain clean.
'@
$confirmPrompt = [string]::Format($confirmPromptTemplate, $script:ReviewRootRelativeEffective)

$phaseSynthesisPromptTemplate = @'
$gsd-code-review

Remediation phase synthesis contract:
- Run a fresh `$gsd-code-review` for the current code at review root `{0}`.
- If health is below `100/100`, deterministic drift is non-zero, unmapped findings are non-zero, deep review is invalid/unparsable, or any findings exist, you MUST create new unchecked remediation phases in `{1}` and matching actionable `*-PLAN.md` files under `.planning/phases`.
- Do not stop with stuck-guard when findings exist and pending phase count is zero.
- Update `{2}` with newly created phase ids and next action.
- Return the exact phase numbers created.
'@
$phaseSynthesisPrompt = [string]::Format($phaseSynthesisPromptTemplate, $script:ReviewRootRelativeEffective, $RoadmapPath, $StatePath)

for ($cycle = 1; $cycle -le $MaxOuterLoops; $cycle++) {
    try {
        $cycleStartUtc = (Get-Date).ToUniversalTime()
        $pendingBefore = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $phaseText = if ($pendingBefore.Count -gt 0) { [string]$pendingBefore[0] } else { "-" }

        $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $autoDevLog = Join-Path $script:ResolvedLogDir ("auto-dev-cycle-{0:D3}-{1}.log" -f $cycle, $stamp)
        $lastAutoDevLog = $autoDevLog

        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "cycle-start" -Doing ("starting cycle {0}" -f $cycle) -Phase $phaseText -IsRunning $false -LogName (Split-Path -Leaf $autoDevLog)

        $autoDevExit = Invoke-GlobalSkillMonitored -Prompt $autoDevPrompt -LogFile $autoDevLog -Stage "auto-dev" -Cycle $cycle -Phase $phaseText -Doing ("running {0}" -f $autoDevCommand)

        $pushAfterAutoDev = Ensure-GitPushSynced -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "auto-dev"
        if (-not $pushAfterAutoDev.Ok) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("stop-{0}" -f $pushAfterAutoDev.Status) -Doing "stopping after push failure" -Phase $phaseText -IsRunning $false -LogName (Split-Path -Leaf $autoDevLog)
            $stopReason = $pushAfterAutoDev.Status
            break
        }

        $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
        $pendingAfter = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $deepReviewEvidence = Get-DeepReviewEvidence -NotBeforeUtc $cycleStartUtc

        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-auto-dev-exit-{0}" -f $autoDevExit) -Doing "evaluating clean-candidate gates" -Phase $phaseText -IsRunning $false -LogName (Split-Path -Leaf $autoDevLog)
        if (-not $deepReviewEvidence.Ok) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "post-auto-dev-deep-review-invalid" -Doing ("deep-review evidence invalid: {0}" -f $deepReviewEvidence.Reason) -Phase $phaseText -IsRunning $false -LogName (Split-Path -Leaf $autoDevLog)
        }

        $needsPhaseSynthesis = (
            $pendingAfter.Count -eq 0 -and (
                -not $metric -or
                -not $metric.Complete -or
                $metric.Health -ne 100 -or
                $metric.Drift -ne 0 -or
                $metric.Unmapped -ne 0 -or
                -not $deepReviewEvidence.Ok
            )
        )

        if ($needsPhaseSynthesis) {
            $synthLog = Join-Path $script:ResolvedLogDir ("phase-synthesis-cycle-{0:D3}-{1}.log" -f $cycle, $stamp)
            $phaseSynthesisExit = Invoke-GlobalSkillMonitored -Prompt $phaseSynthesisPrompt -LogFile $synthLog -Stage "phase-synthesis" -Cycle $cycle -Phase "-" -Doing "forcing remediation phase synthesis from latest review findings"

            $pushAfterSynthesis = Ensure-GitPushSynced -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "phase-synthesis"
            if (-not $pushAfterSynthesis.Ok) {
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("stop-{0}" -f $pushAfterSynthesis.Status) -Doing "stopping after phase-synthesis push failure" -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $synthLog)
                $stopReason = $pushAfterSynthesis.Status
                break
            }

            $metric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
            $pendingAfter = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
            $deepReviewEvidence = Get-DeepReviewEvidence -NotBeforeUtc $cycleStartUtc

            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-phase-synthesis-exit-{0}" -f $phaseSynthesisExit) -Doing "re-evaluated metrics after forced phase synthesis" -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $synthLog)
            if (-not $deepReviewEvidence.Ok) {
                Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "post-phase-synthesis-deep-review-invalid" -Doing ("deep-review evidence still invalid: {0}" -f $deepReviewEvidence.Reason) -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $synthLog)
            }
        }

        $isCleanCandidate = (
            $metric -and $metric.Complete -and
            $metric.Health -eq 100 -and
            $metric.Drift -eq 0 -and
            $metric.Unmapped -eq 0 -and
            $pendingAfter.Count -eq 0 -and
            $deepReviewEvidence.Ok
        )

        if (-not $isCleanCandidate) { continue }

        $codeBefore = Get-CodeFingerprint

        $confirmLog = Join-Path $script:ResolvedLogDir ("final-confirm-cycle-{0:D3}-{1}.log" -f $cycle, $stamp)
        $lastConfirmLog = $confirmLog
        $confirmStartUtc = (Get-Date).ToUniversalTime()

        $confirmExit = Invoke-GlobalSkillMonitored -Prompt $confirmPrompt -LogFile $confirmLog -Stage "final-confirm" -Cycle $cycle -Phase "-" -Doing "running final clean confirmation review"

        $pushAfterConfirm = Ensure-GitPushSynced -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "final-confirm"
        if (-not $pushAfterConfirm.Ok) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("stop-{0}" -f $pushAfterConfirm.Status) -Doing "stopping after confirmation push failure" -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $confirmLog)
            $stopReason = $pushAfterConfirm.Status
            break
        }

        $confirmMetric = Get-BestMetricSnapshot -Paths $script:ResolvedSummaryPaths
        $pendingConfirm = @(Get-PendingPhases -RoadmapFile $script:ResolvedRoadmapPath)
        $confirmDeepReviewEvidence = Get-DeepReviewEvidence -NotBeforeUtc $confirmStartUtc
        $codeAfter = Get-CodeFingerprint
        $noCodeChanges = Test-CodeFingerprintEqual -Left $codeBefore -Right $codeAfter

        Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage ("post-final-confirm-exit-{0}" -f $confirmExit) -Doing ("final confirmation analyzed; no_code_changes={0}" -f $noCodeChanges) -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $confirmLog)
        if (-not $confirmDeepReviewEvidence.Ok) {
            Write-ProgressUpdate -StatusPath $script:ResolvedStatusPath -Cycle $cycle -Stage "post-final-confirm-deep-review-invalid" -Doing ("confirmation deep-review evidence invalid: {0}" -f $confirmDeepReviewEvidence.Reason) -Phase "-" -IsRunning $false -LogName (Split-Path -Leaf $confirmLog)
        }

        $confirmClean = (
            $confirmMetric -and $confirmMetric.Complete -and
            $confirmMetric.Health -eq 100 -and
            $confirmMetric.Drift -eq 0 -and
            $confirmMetric.Unmapped -eq 0 -and
            $pendingConfirm.Count -eq 0 -and
            $noCodeChanges -and
            $confirmDeepReviewEvidence.Ok
        )

        if ($confirmClean) {
            $finalMetric = $confirmMetric
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

if ($finalMetric -and $stopReason -eq "clean-confirmed") {
    exit 0
}

exit 2
