# gsd-runner-codex.ps1
# Global GSD phase runner for Codex CLI with SDLC continuous improvement loop.

param(
    [string]$ProjectPath = "",
    [int]$StartPhase = 0,
    [int]$EndPhase = 0,
    [switch]$SkipResearch,
    [switch]$SkipPlanning,
    [switch]$PrepareOnly,
    [switch]$UseWaveParallel,
    [switch]$DryRun,
    [switch]$ContinuousImprovement,
    [int]$TargetScore = 100,
    [int]$MaxIterations = 5,
    [switch]$StopOnNoImprovement,
    [int]$PrepTimeout = 45,
    [int]$ExecuteTimeout = 60,
    [int]$ReviewTimeout = 60,
    [int]$VerifyTimeout = 20,
    [string]$PrepModel = "gpt-5.3-codex-extra-high",
    [string]$ExecuteModel = "gpt-5.3-codex-high",
    [string]$ReviewModel = "gpt-5.3-codex-extra-high",
    [int]$MaxParallel = 3
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $line = "=" * 70
    Write-Host ""
    Write-Host $line -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host $line -ForegroundColor $Color
    Write-Host ""
}

function Find-GsdProjectRoot {
    param([string]$StartDir)
    $current = if ($StartDir) { (Resolve-Path $StartDir -ErrorAction SilentlyContinue).Path } else { (Get-Location).Path }
    if (-not $current) { return $null }

    while ($current) {
        if (Test-Path (Join-Path $current ".planning\ROADMAP.md")) { return $current }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $null
}

$projectRoot = Find-GsdProjectRoot $ProjectPath
if (-not $projectRoot) {
    Write-Host "ERROR: No GSD project found. Missing .planning/ROADMAP.md" -ForegroundColor Red
    exit 1
}

$projectName = Split-Path $projectRoot -Leaf
$logFile = Join-Path $projectRoot ".planning\execution-log-codex.txt"
$agentOutputDir = Join-Path $projectRoot ".planning\agent-output"
if (-not (Test-Path $agentOutputDir)) { New-Item -Path $agentOutputDir -ItemType Directory -Force | Out-Null }

$GsdHome = Join-Path $env:USERPROFILE ".codex"
$GsdCommandsDir = Join-Path $GsdHome "commands\gsd"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Host $entry -ForegroundColor $Color
    Add-Content -Path $logFile -Value $entry
}

function Resolve-CodexCommand {
    $cmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $vscodeExtRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
    if (Test-Path $vscodeExtRoot) {
        $candidates = Get-ChildItem -Path $vscodeExtRoot -Directory -Filter "openai.chatgpt-*" -ErrorAction SilentlyContinue |
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
    if (-not $CodexExePath) { return $false }

    $codexDir = Split-Path $CodexExePath -Parent
    if (-not (($env:Path -split ';') -contains $codexDir)) {
        $env:Path = "$env:Path;$codexDir"
    }
    return $true
}

function Get-PendingPhases {
    $roadmap = Get-Content (Join-Path $projectRoot ".planning\ROADMAP.md") -Raw
    $pending = @()
    foreach ($m in [regex]::Matches($roadmap, '- \[ \] \*\*Phase (\d+)')) { $pending += [int]$m.Groups[1].Value }
    return ($pending | Sort-Object -Unique)
}

function Get-AllPhases {
    $roadmap = Get-Content (Join-Path $projectRoot ".planning\ROADMAP.md") -Raw
    $all = @()
    foreach ($m in [regex]::Matches($roadmap, '- \[.\] \*\*Phase (\d+)')) { $all += [int]$m.Groups[1].Value }
    return ($all | Sort-Object -Unique)
}

function Test-PhaseCheckedInRoadmap {
    param([int]$PhaseNum)
    $roadmap = Get-Content (Join-Path $projectRoot ".planning\ROADMAP.md") -Raw
    return ($roadmap -match "- \[[xX]\] \*\*Phase $PhaseNum\b")
}

function Get-PhaseDir {
    param([int]$PhaseNum)
    $padded = $PhaseNum.ToString("00")
    $phaseRoot = Join-Path $projectRoot ".planning\phases"
    $dirs = Get-ChildItem -Path $phaseRoot -Directory -Filter "${padded}-*" -ErrorAction SilentlyContinue
    if ($dirs) { return $dirs[0].Name }
    return $null
}

function Test-PhaseHasResearch {
    param([int]$PhaseNum)
    $dir = Get-PhaseDir $PhaseNum
    if (-not $dir) { return $false }
    $research = Get-ChildItem -Path (Join-Path $projectRoot ".planning\phases\$dir") -Filter "*RESEARCH.md" -ErrorAction SilentlyContinue
    return ($research -and $research.Count -gt 0)
}

function Test-PhaseHasPlans {
    param([int]$PhaseNum)
    $dir = Get-PhaseDir $PhaseNum
    if (-not $dir) { return $false }
    $plans = Get-ChildItem -Path (Join-Path $projectRoot ".planning\phases\$dir") -Filter "*-PLAN.md" -ErrorAction SilentlyContinue
    return ($plans -and $plans.Count -gt 0)
}

function Get-PhasePlanCount {
    param([int]$PhaseNum)
    $dir = Get-PhaseDir $PhaseNum
    if (-not $dir) { return 0 }
    $plans = Get-ChildItem -Path (Join-Path $projectRoot ".planning\phases\$dir") -Filter "*-PLAN.md" -ErrorAction SilentlyContinue
    if ($plans) { return $plans.Count }
    return 0
}

function Get-PhaseSummaryCount {
    param([int]$PhaseNum)
    $dir = Get-PhaseDir $PhaseNum
    if (-not $dir) { return 0 }
    $summaries = Get-ChildItem -Path (Join-Path $projectRoot ".planning\phases\$dir") -Filter "*-SUMMARY.md" -ErrorAction SilentlyContinue
    if ($summaries) { return $summaries.Count }
    return 0
}

function Test-PhaseComplete {
    param([int]$PhaseNum)
    $planCount = Get-PhasePlanCount $PhaseNum
    if ($planCount -gt 0) {
        $summaryCount = Get-PhaseSummaryCount $PhaseNum
        if ($summaryCount -ge $planCount) { return $true }
    }
    return (Test-PhaseCheckedInRoadmap $PhaseNum)
}

function Resolve-AtPath {
    param([string]$RawPath)
    $p = $RawPath.Trim()
    if ($p.StartsWith("~")) { $p = $p.Replace("~", $env:USERPROFILE) }
    if ($p -match '^[A-Za-z]:[\\/]') { return $p }
    return (Join-Path $projectRoot $p)
}

function Expand-FileContext {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $pattern = '(?m)@(?<filepath>[A-Za-z]:[\\/][^\s<>`"' + "'" + ']+|~[^\s<>`"' + "'" + ']+|\.planning[\\/][^\s<>`"' + "'" + ']+|[^\s<>`"' + "'" + ']+\.md)'
    return [regex]::Replace($Text, $pattern, {
        param($match)
        $raw = $match.Groups['filepath'].Value
        $full = Resolve-AtPath $raw
        if (-not (Test-Path $full)) { return $match.Value }
        $item = Get-Item $full -ErrorAction SilentlyContinue
        if (-not $item -or $item.PSIsContainer -or $item.Length -gt 300000) { return $match.Value }
        $content = Get-Content $full -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return $match.Value }
        return "`n--- FILE: $raw ---`n$content`n--- END FILE ---`n"
    })
}

function Resolve-GsdCommandPrompt {
    param([string]$Prompt)
    if ($Prompt -notmatch '^\s*/gsd:([a-z0-9-]+)\s*(.*)$') { return $Prompt }

    $name = $Matches[1]
    $args = $Matches[2]
    $path = Join-Path $GsdCommandsDir "$name.md"
    if (-not (Test-Path $path)) {
        Write-Log "    [PROMPT] Missing command file: $path (passing command as plain text)" "Yellow"
        return $Prompt
    }

    $doc = Get-Content $path -Raw
    $doc = $doc.Replace('$ARGUMENTS', $args)

    return @"
Execute this GSD command exactly as written.

<COMMAND_NAME>
/gsd:$name $args
</COMMAND_NAME>

<COMMAND_DOC>
$doc
</COMMAND_DOC>
"@
}

function New-ResolvedPromptFile {
    param([string]$Prompt, [string]$Label)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safe = $Label -replace '[^a-zA-Z0-9_-]', '_'
    $path = Join-Path $agentOutputDir "${safe}-${timestamp}.prompt"

    $resolved = Resolve-GsdCommandPrompt $Prompt
    $expanded = Expand-FileContext $resolved
    Set-Content -Path $path -Value $expanded -Encoding UTF8 -Force
    return $path
}

function Get-LatestTextLine {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $lines = Get-Content $Path -Tail 40 -ErrorAction SilentlyContinue
    if (-not $lines) { return $null }
    $candidate = $null
    foreach ($line in $lines) {
        if ($line -and $line.Trim()) { $candidate = $line.Trim() }
    }
    return $candidate
}

function Build-CodexExecCommand {
    param([string]$PromptFile, [string]$Model)
    $cmd = "type `"$PromptFile`" | `"$script:CodexExe`" exec - --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check --cd `"$projectRoot`""
    if ($Model) { $cmd += " -m $Model" }
    return $cmd
}

function Invoke-CodexWithTimeout {
    param(
        [string]$Prompt,
        [int]$TimeoutMinutes,
        [string]$Label,
        [string]$Model = ""
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safe = $Label -replace '[^a-zA-Z0-9_-]', '_'
    $outFile = Join-Path $agentOutputDir "${safe}-${timestamp}.stdout"
    $errFile = Join-Path $agentOutputDir "${safe}-${timestamp}.stderr"

    $promptFile = New-ResolvedPromptFile -Prompt $Prompt -Label $Label
    $cmd = Build-CodexExecCommand -PromptFile $promptFile -Model $Model

    Write-Log "    [RUN] $Label (timeout=${TimeoutMinutes}m)" "DarkCyan"

    $procStart = Get-Date
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -NoNewWindow -PassThru -WorkingDirectory $projectRoot -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $deadline = $procStart.AddMinutes($TimeoutMinutes)
    $lastBeat = $procStart
    $lastTail = ""
    $spin = @('|','/','-','\\')
    $si = 0

    while (-not $proc.HasExited) {
        if ((Get-Date) -gt $deadline) {
            Write-Log "    [TIMEOUT] $Label exceeded ${TimeoutMinutes}m" "Red"
            try { $proc.Kill(); $proc.WaitForExit(5000) } catch {}
            $elapsed = [math]::Round(((Get-Date) - $procStart).TotalMinutes, 1)
            return @{ Success = $false; TimedOut = $true; ExitCode = -1; Duration = $elapsed; OutFile = $outFile; ErrFile = $errFile }
        }

        if (((Get-Date) - $lastBeat).TotalSeconds -ge 8) {
            $elapsed = [math]::Round(((Get-Date) - $procStart).TotalMinutes, 1)
            $tail = Get-LatestTextLine $outFile
            if (-not $tail) { $tail = Get-LatestTextLine $errFile }

            if ($tail -and $tail -ne $lastTail) {
                $lastTail = $tail
                Write-Host ("    [{0}] {1} {2}m | {3}" -f $spin[$si % $spin.Count], $Label, $elapsed, $tail) -ForegroundColor DarkGray
            } else {
                Write-Host ("    [{0}] {1} {2}m" -f $spin[$si % $spin.Count], $Label, $elapsed) -ForegroundColor DarkGray
            }

            $si++
            $lastBeat = Get-Date
        }

        Start-Sleep -Seconds 2
    }

    try { $proc.WaitForExit(5000) } catch {}
    $duration = [math]::Round(((Get-Date) - $procStart).TotalMinutes, 1)
    $exitCode = $proc.ExitCode
    $success = ($exitCode -eq 0)

    # Some Windows codex.exe runs return empty/null exit code despite valid output.
    # Fall back to stdout content to avoid false failures.
    $missingExit = ($null -eq $exitCode -or [string]::IsNullOrWhiteSpace([string]$exitCode))
    if ($missingExit) {
        $outSize = if (Test-Path $outFile) { (Get-Item $outFile).Length } else { 0 }
        if ($outSize -gt 0) {
            $success = $true
            $exitCode = 0
            Write-Log "    [RUN] $Label had missing exit code; stdout ${outSize} bytes, treating as success" "Yellow"
        }
    }

    if ($success) {
        Write-Log "    [DONE] $Label in ${duration}m" "Green"
    } else {
        Write-Log "    [FAIL] $Label exit $exitCode after ${duration}m" "Red"
        if (Test-Path $errFile) {
            $tailErr = Get-Content $errFile -Tail 3 -ErrorAction SilentlyContinue
            if ($tailErr) { foreach ($line in $tailErr) { Write-Log "      $line" "DarkRed" } }
        }
    }

    return @{ Success = $success; TimedOut = $false; ExitCode = $exitCode; Duration = $duration; OutFile = $outFile; ErrFile = $errFile }
}

function Get-ReviewHealthScore {
    $summaryPath = Join-Path $projectRoot "docs\review\EXECUTIVE-SUMMARY.md"
    if (-not (Test-Path $summaryPath)) {
        Write-Log "    [REVIEW] EXECUTIVE-SUMMARY.md not found" "Red"
        return $null
    }

    $content = Get-Content $summaryPath -Raw

    $score = $null
    $grade = "?"
    if ($content -match 'Health[:\s]+(\d+)\s*/\s*100\s*\(Grade[:\s]+([A-F][+-]?)\)') {
        $score = [int]$Matches[1]
        $grade = $Matches[2]
    } elseif ($content -match 'Health[:\s]+(\d+)\s*/\s*100') {
        $score = [int]$Matches[1]
    } elseif ($content -match '(\d+)\s*/\s*100') {
        $score = [int]$Matches[1]
    }

    if ($null -eq $score) {
        Write-Log "    [REVIEW] Could not parse health score" "Red"
        return $null
    }

    $blockers = 0; $high = 0; $medium = 0; $low = 0
    if ($content -match 'BLOCKER\s*\|\s*(\d+)') { $blockers = [int]$Matches[1] }
    if ($content -match 'HIGH\s*\|\s*(\d+)') { $high = [int]$Matches[1] }
    if ($content -match 'MEDIUM\s*\|\s*(\d+)') { $medium = [int]$Matches[1] }
    if ($content -match 'LOW\s*\|\s*(\d+)') { $low = [int]$Matches[1] }

    # Alternate markdown/table variants with bold labels: | **BLOCKER** | 1 |
    if ($blockers -eq 0 -and $content -match '(?i)\|\s*\*{0,2}BLOCKER\*{0,2}\s*\|\s*(\d+)\s*\|') { $blockers = [int]$Matches[1] }
    if ($high -eq 0 -and $content -match '(?i)\|\s*\*{0,2}HIGH\*{0,2}\s*\|\s*(\d+)\s*\|') { $high = [int]$Matches[1] }
    if ($medium -eq 0 -and $content -match '(?i)\|\s*\*{0,2}MEDIUM\*{0,2}\s*\|\s*(\d+)\s*\|') { $medium = [int]$Matches[1] }
    if ($low -eq 0 -and $content -match '(?i)\|\s*\*{0,2}LOW\*{0,2}\s*\|\s*(\d+)\s*\|') { $low = [int]$Matches[1] }

    # Executive summary "Severity Totals: Blocker=1 | High=2 | Medium=2 | Low=0"
    if (($blockers + $high + $medium + $low) -eq 0) {
        if ($content -match '(?is)Severity\s+Totals\s*:\s*.*?Blocker\s*=\s*(\d+).*?High\s*=\s*(\d+).*?Medium\s*=\s*(\d+).*?Low\s*=\s*(\d+)') {
            $blockers = [int]$Matches[1]
            $high = [int]$Matches[2]
            $medium = [int]$Matches[3]
            $low = [int]$Matches[4]
        }
    }

    return @{
        Score = $score
        Grade = $grade
        Blockers = $blockers
        High = $high
        Medium = $medium
        Low = $low
        Total = ($blockers + $high + $medium + $low)
    }
}

function Test-StopCondition {
    param([hashtable]$Health, [hashtable]$PreviousHealth)

    if ($null -eq $Health) {
        return @{ Stop = $false; Reason = "Health not parseable yet" }
    }

    if ($Health.Score -ge $TargetScore -and $Health.Blockers -eq 0 -and $Health.High -eq 0) {
        return @{ Stop = $true; Reason = "Passing review: score=$($Health.Score), blockers=0, high=0" }
    }

    if ($StopOnNoImprovement -and $PreviousHealth) {
        if ($Health.Score -le $PreviousHealth.Score) {
            return @{ Stop = $true; Reason = "No improvement: $($PreviousHealth.Score) -> $($Health.Score)" }
        }
    }

    return @{ Stop = $false; Reason = "Needs remediation: score=$($Health.Score), blockers=$($Health.Blockers), high=$($Health.High)" }
}

function Show-ExecutionPlan {
    param([int[]]$Phases)
    Write-Banner "Execution Plan" "Yellow"
    foreach ($phase in $Phases) {
        $dir = Get-PhaseDir $phase
        $dirLabel = if ($dir) { $dir } else { "(no directory)" }

        if (Test-PhaseComplete $phase) {
            Write-Host "  Phase $phase ($dirLabel): complete" -ForegroundColor DarkGray
            continue
        }

        $steps = @()
        if (-not $SkipPlanning) {
            if (-not $SkipResearch -and -not (Test-PhaseHasResearch $phase)) { $steps += "research" }
            if (-not (Test-PhaseHasPlans $phase)) { $steps += "plan" }
        }
        if (-not $PrepareOnly) { $steps += "execute"; $steps += "verify" }

        if ($steps.Count -eq 0) {
            Write-Host "  Phase $phase ($dirLabel): no action" -ForegroundColor DarkGray
        } else {
            Write-Host "  Phase $phase ($dirLabel): $($steps -join ' -> ')" -ForegroundColor White
        }
    }
}

function Get-PrepPipelineEntry {
    param([int]$PhaseNum)

    $steps = @()
    $commands = @()

    if (-not $SkipResearch -and -not (Test-PhaseHasResearch $PhaseNum)) {
        $pf = New-ResolvedPromptFile -Prompt "/gsd:batch-research $PhaseNum" -Label "prep-research-phase-$PhaseNum"
        $commands += Build-CodexExecCommand -PromptFile $pf -Model $PrepModel
        $steps += "research"
    }

    if (-not (Test-PhaseHasPlans $PhaseNum)) {
        $pf = New-ResolvedPromptFile -Prompt "/gsd:batch-plan $PhaseNum" -Label "prep-plan-phase-$PhaseNum"
        $commands += Build-CodexExecCommand -PromptFile $pf -Model $PrepModel
        $steps += "plan"
    }

    if ($commands.Count -eq 0) { return $null }

    return @{
        Phase = $PhaseNum
        Steps = $steps
        Command = ($commands -join " && ")
    }
}

function Invoke-ParallelPreparation {
    param([int[]]$Phases)

    if ($SkipPlanning) {
        Write-Log "  [PREP] Skipped (-SkipPlanning)" "DarkGray"
        return @{ Prepared = 0; Failed = 0 }
    }

    $entries = @()
    foreach ($p in $Phases) {
        if (Test-PhaseComplete $p) { continue }
        $entry = Get-PrepPipelineEntry -PhaseNum $p
        if ($entry) { $entries += $entry }
    }

    if ($entries.Count -eq 0) {
        Write-Log "  [PREP] All phases already prepared" "DarkGray"
        return @{ Prepared = 0; Failed = 0 }
    }

    Write-Log "  [PREP] Starting $($entries.Count) phase prep pipelines in parallel (max $MaxParallel)" "Yellow"

    $active = @()
    $queue = [System.Collections.ArrayList]::new()
    foreach ($e in $entries) { [void]$queue.Add($e) }

    $prepared = 0
    $failed = 0

    while ($queue.Count -gt 0 -or @($active | Where-Object { -not $_.Process.HasExited }).Count -gt 0) {
        while ($queue.Count -gt 0 -and @($active | Where-Object { -not $_.Process.HasExited }).Count -lt $MaxParallel) {
            $entry = $queue[0]
            $queue.RemoveAt(0)

            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $out = Join-Path $agentOutputDir "prep-phase-$($entry.Phase)-${timestamp}.stdout"
            $err = Join-Path $agentOutputDir "prep-phase-$($entry.Phase)-${timestamp}.stderr"

            Write-Log "    [PREP] Launch phase $($entry.Phase): $($entry.Steps -join ' -> ')" "White"
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $entry.Command -NoNewWindow -PassThru -WorkingDirectory $projectRoot -RedirectStandardOutput $out -RedirectStandardError $err
            $active += @{
                Process = $proc
                Phase = $entry.Phase
                Steps = $entry.Steps
                Start = Get-Date
                OutFile = $out
                ErrFile = $err
            }
        }

        foreach ($run in @($active)) {
            if (-not $run.Process.HasExited) {
                $elapsed = ((Get-Date) - $run.Start).TotalMinutes
                if ($elapsed -ge $PrepTimeout) {
                    Write-Log "    [PREP] TIMEOUT phase $($run.Phase) after $([math]::Round($elapsed,1))m" "Red"
                    try { $run.Process.Kill() } catch {}
                }
                continue
            }

            $dur = [math]::Round(((Get-Date) - $run.Start).TotalMinutes, 1)
            $exit = $run.Process.ExitCode

            if ($exit -eq 0 -or (Test-PhaseHasPlans $run.Phase)) {
                Write-Log "    [PREP] Phase $($run.Phase) ready in ${dur}m" "Green"
                $prepared++
            } else {
                Write-Log "    [PREP] Phase $($run.Phase) failed (exit $exit)" "Red"
                $failed++
            }

            $active = @($active | Where-Object { $_ -ne $run })
        }

        Start-Sleep -Seconds 3
    }

    return @{ Prepared = $prepared; Failed = $failed }
}

function Invoke-SequentialExecution {
    param([int[]]$Phases)

    if ($PrepareOnly) {
        Write-Log "  [EXEC] Skipped (-PrepareOnly)" "DarkGray"
        return @{ Executed = 0; Failed = 0 }
    }

    $execSkill = if ($UseWaveParallel) { "/gsd:execute-phase" } else { "/gsd:batch-execute" }
    Write-Log "  [EXEC] Sequential phase execution via $execSkill" "Yellow"

    $executed = 0
    $failed = 0

    foreach ($p in $Phases) {
        if (Test-PhaseComplete $p) {
            Write-Log "    [EXEC] Phase $p already complete" "DarkGray"
            continue
        }

        if (-not (Test-PhaseHasPlans $p)) {
            Write-Log "    [EXEC] Phase $p skipped (no PLAN files)" "Yellow"
            $failed++
            continue
        }

        $res = Invoke-CodexWithTimeout -Prompt "$execSkill $p" -TimeoutMinutes $ExecuteTimeout -Label "execute-phase-$p" -Model $ExecuteModel
        if (-not $res.Success) {
            $failed++
            continue
        }

        $executed++
        Write-Log "    [EXEC] Phase $p execution complete" "Green"    }

    return @{ Executed = $executed; Failed = $failed }
}

function Invoke-FullReview {
    param([int]$Iteration)
    return Invoke-CodexWithTimeout -Prompt "/gsd:sdlc-review" -TimeoutMinutes $ReviewTimeout -Label "sdlc-review-iter-$Iteration" -Model $ReviewModel
}

 $script:CodexExe = Resolve-CodexCommand
if (-not $script:CodexExe) {
    Write-Host "ERROR: codex CLI not found." -ForegroundColor Red
    exit 1
}
[void](Ensure-CodexOnPath -CodexExePath $script:CodexExe)
Write-Log "Using codex: $script:CodexExe" "DarkGray"

$preflight = Invoke-CodexWithTimeout -Prompt "Reply with exactly: ok" -TimeoutMinutes 2 -Label "preflight"
if (-not $preflight.Success) {
    Write-Host "ERROR: preflight failed. Run 'codex login'." -ForegroundColor Red
    exit 1
}

$allPhases = Get-AllPhases
if ($allPhases.Count -eq 0) {
    Write-Host "ERROR: No phases found in .planning/ROADMAP.md" -ForegroundColor Red
    exit 1
}

if ($StartPhase -eq 0 -and $EndPhase -eq 0) {
    $pending = Get-PendingPhases
    if ($pending.Count -gt 0) {
        $StartPhase = $pending[0]
        $EndPhase = $pending[-1]
    } else {
        $StartPhase = $allPhases[0]
        $EndPhase = $allPhases[-1]
    }
}

$targetPhases = @($allPhases | Where-Object { $_ -ge $StartPhase -and $_ -le $EndPhase })
if ($targetPhases.Count -eq 0) {
    Write-Host "ERROR: No phases in selected range." -ForegroundColor Red
    exit 1
}

Write-Banner "GSD Codex SDLC Runner"
Write-Host "  Project: $projectName" -ForegroundColor White
Write-Host "  Root:    $projectRoot" -ForegroundColor DarkGray
Write-Host "  Range:   $StartPhase-$EndPhase" -ForegroundColor White
Write-Host "  Phases:  $($targetPhases -join ', ')" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Show-ExecutionPlan -Phases $targetPhases
    exit 0
}

$stats = @{
    Reviews = 0
    PrepReady = 0
    PrepFailed = 0
    ExecDone = 0
    ExecFailed = 0
}

$previousHealth = $null
$previousPending = @()
$iteration = 0
$stopReason = "Max iterations reached"

while ($iteration -lt $MaxIterations) {
    $iteration++
    Write-Banner "SDLC Iteration $iteration" "Magenta"

    $pendingNow = Get-PendingPhases
    if ($StartPhase -gt 0 -or $EndPhase -gt 0) {
        $pendingNow = @($pendingNow | Where-Object { $_ -ge $StartPhase -and $_ -le $EndPhase })
    }

    if ($pendingNow.Count -gt 0) {
        Write-Log "  [PHASES] Pending phases before review: $($pendingNow -join ', ')" "Cyan"

        $prep = Invoke-ParallelPreparation -Phases $pendingNow
        $stats.PrepReady += $prep.Prepared
        $stats.PrepFailed += $prep.Failed

        $exec = Invoke-SequentialExecution -Phases $pendingNow
        $stats.ExecDone += $exec.Executed
        $stats.ExecFailed += $exec.Failed
    } else {
        Write-Log "  [PHASES] No pending phases before review" "DarkGray"
    }

    $review = Invoke-FullReview -Iteration $iteration
    $stats.Reviews++
    if (-not $review.Success) {
        $stopReason = "SDLC review failed on iteration $iteration"
        break
    }

    Start-Sleep -Seconds 2
    $health = Get-ReviewHealthScore
    if ($health) {
        Write-Log "  [HEALTH] Score=$($health.Score) Grade=$($health.Grade) | Blocker=$($health.Blockers) High=$($health.High) Med=$($health.Medium) Low=$($health.Low)" "White"
    }

    $pendingAfter = Get-PendingPhases
    if ($StartPhase -gt 0 -or $EndPhase -gt 0) {
        $pendingAfter = @($pendingAfter | Where-Object { $_ -ge $StartPhase -and $_ -le $EndPhase })
    }
    if ($pendingAfter.Count -gt 0) {
        Write-Log "  [PHASES] Pending phases after review: $($pendingAfter -join ', ')" "Yellow"
    } else {
        Write-Log "  [PHASES] No pending phases after review" "Green"
    }

    $healthy = ($health -and $health.Score -ge $TargetScore)
    if ($healthy -and $pendingAfter.Count -eq 0) {
        $stopReason = "Success: health=$($health.Score)/100 with no pending phases"
        Write-Log "  [STOP] $stopReason" "Green"
        break
    }

    if ($StopOnNoImprovement -and $previousHealth -and $health) {
        $sameScore = ($health.Score -le $previousHealth.Score)
        $samePending = ((($pendingAfter | Sort-Object) -join ',') -eq (($previousPending | Sort-Object) -join ','))
        if ($sameScore -and $samePending) {
            $stopReason = "No improvement: score $($previousHealth.Score) -> $($health.Score), pending unchanged"
            Write-Log "  [STOP] $stopReason" "Yellow"
            break
        }
    }

    if (($pendingNow.Count -eq 0) -and ($pendingAfter.Count -eq 0) -and ($health -and $health.Score -lt $TargetScore)) {
        $stopReason = "No pending phases exist but health remains below target ($($health.Score)/100)"
        Write-Log "  [STOP] $stopReason" "Yellow"
        break
    }

    $previousHealth = $health
    $previousPending = $pendingAfter
}
$totalDuration = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Banner "Run Complete"
Write-Host "  Reviews run:      $($stats.Reviews)" -ForegroundColor White
Write-Host "  Prep ready:       $($stats.PrepReady)" -ForegroundColor White
Write-Host "  Prep failures:    $($stats.PrepFailed)" -ForegroundColor $(if ($stats.PrepFailed -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Phases executed:  $($stats.ExecDone)" -ForegroundColor White
Write-Host "  Exec failures:    $($stats.ExecFailed)" -ForegroundColor $(if ($stats.ExecFailed -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Stop reason:      $stopReason" -ForegroundColor Yellow
Write-Host "  Duration:         ${totalDuration}m" -ForegroundColor White
Write-Host "  Log:              $logFile" -ForegroundColor DarkGray




