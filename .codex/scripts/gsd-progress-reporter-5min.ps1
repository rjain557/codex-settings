param(
    [Parameter(Mandatory = $true)][string]$StatusLog,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [int]$IntervalSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LatestCycleLine {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }

    $lines = @(Get-Content -Path $Path -Tail 500)
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = [string]$lines[$i]
        if ($line -match 'cycle=\d+') {
            return $line
        }
    }

    return $null
}

function Get-MatchOrUnknown {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $m = [regex]::Match($Text, $Pattern)
    if ($m.Success -and $m.Groups.Count -gt 1) {
        return [string]$m.Groups[1].Value
    }

    return "unknown"
}

function Format-ProgressLine {
    param([string]$StatusLine)

    if ([string]::IsNullOrWhiteSpace($StatusLine)) {
        return "[{0}] cycle=unknown stage=waiting active_phase=unknown phase_counts(completed=unknown,in_progress=unknown,pending=unknown) current(h=unknown,d=unknown,u=unknown) commits=unknown action=unknown" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $cycle = Get-MatchOrUnknown -Text $StatusLine -Pattern 'cycle=(\d+)'
    $stage = Get-MatchOrUnknown -Text $StatusLine -Pattern 'stage=([^\s]+)'
    $phaseRaw = Get-MatchOrUnknown -Text $StatusLine -Pattern 'phase=([^\s]+)'
    $completed = Get-MatchOrUnknown -Text $StatusLine -Pattern 'completed=(\d+)'
    $inProgress = Get-MatchOrUnknown -Text $StatusLine -Pattern 'in_progress=(\d+)'
    $pending = Get-MatchOrUnknown -Text $StatusLine -Pattern 'pending=(\d+)'
    $health = Get-MatchOrUnknown -Text $StatusLine -Pattern 'current\(h=([^,]+),d='
    $drift = Get-MatchOrUnknown -Text $StatusLine -Pattern 'current\(h=[^,]+,d=([^,]+),u='
    $unmapped = Get-MatchOrUnknown -Text $StatusLine -Pattern 'current\(h=[^,]+,d=[^,]+,u=([^)]+)\)'
    $commits = Get-MatchOrUnknown -Text $StatusLine -Pattern 'commits=(\d+)'
    $doing = Get-MatchOrUnknown -Text $StatusLine -Pattern 'doing="([^"]+)"'

    $activePhase = switch -Regex ($phaseRaw) {
        '^\d+$' { "Phase $phaseRaw"; break }
        '^-$' { "n/a"; break }
        default { $phaseRaw; break }
    }

    if ($doing.Length -gt 160) {
        $doing = $doing.Substring(0, 157) + "..."
    }

    return "[{0}] cycle={1} stage={2} active_phase={3} phase_counts(completed={4},in_progress={5},pending={6}) current(h={7},d={8},u={9}) commits={10} action={11}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $cycle, $stage, $activePhase, $completed, $inProgress, $pending, $health, $drift, $unmapped, $commits, $doing
}

$parent = Split-Path -Parent $OutFile
if (-not (Test-Path $parent)) {
    New-Item -Path $parent -ItemType Directory -Force | Out-Null
}

Add-Content -Path $OutFile -Value ("[{0}] progress-reporter-start interval_seconds={1} status_log={2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $IntervalSeconds, $StatusLog)

while ($true) {
    $latest = Get-LatestCycleLine -Path $StatusLog
    $report = Format-ProgressLine -StatusLine $latest
    Add-Content -Path $OutFile -Value $report
    Start-Sleep -Seconds $IntervalSeconds
}
