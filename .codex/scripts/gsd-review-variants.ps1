[CmdletBinding()]
param(
    [ValidateSet("capture", "list", "promote", "merge")]
    [string]$Action = "list",
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$Variant = "codex",
    [string]$RunId = "",
    [string]$SourceRoot = "docs/review",
    [string]$TargetRoot = "docs/review",
    [string[]]$MergeSources = @("codex:latest", "claude:latest"),
    [string]$ManifestNote = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-FromProject {
    param(
        [string]$Root,
        [string]$RelativeOrAbsolute
    )
    if ([System.IO.Path]::IsPathRooted($RelativeOrAbsolute)) {
        return [System.IO.Path]::GetFullPath($RelativeOrAbsolute)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $Root ($RelativeOrAbsolute -replace '/', '\')))
}

function To-RelativeUnixPath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )
    try {
        $baseFull = [System.IO.Path]::GetFullPath($BasePath)
        $targetFull = [System.IO.Path]::GetFullPath($TargetPath)
        $baseUri = New-Object System.Uri(($baseFull.TrimEnd("\") + "\"))
        $targetUri = New-Object System.Uri($targetFull)
        return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace("\", "/")
    } catch {
        return $TargetPath.Replace("\", "/")
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Clear-DirectoryContents {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )
    Ensure-Directory -Path $Destination

    $robocopyCmd = Get-Command robocopy.exe -ErrorAction SilentlyContinue
    if ($robocopyCmd) {
        & $robocopyCmd.Source $Source $Destination /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed with exit code $LASTEXITCODE (`"$Source`" -> `"$Destination`")."
        }
        return
    }

    $items = Get-ChildItem -Path $Source -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        Copy-Item -Path $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Get-LatestRunPath {
    param(
        [string]$RunsRoot,
        [string]$VariantName
    )
    $variantRoot = Join-Path $RunsRoot $VariantName
    if (-not (Test-Path $variantRoot)) { return $null }
    $runs = Get-ChildItem -Path $variantRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending
    if (-not $runs -or $runs.Count -eq 0) { return $null }
    return $runs[0].FullName
}

function Resolve-RunPath {
    param(
        [string]$RunsRoot,
        [string]$VariantName,
        [string]$RunName
    )
    if ([string]::IsNullOrWhiteSpace($RunName) -or $RunName -eq "latest") {
        return Get-LatestRunPath -RunsRoot $RunsRoot -VariantName $VariantName
    }
    $path = Join-Path (Join-Path $RunsRoot $VariantName) $RunName
    if (Test-Path $path) { return $path }
    return $null
}

function Parse-ExecutiveSummaryMetrics {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $text = Get-Content -Raw -Path $Path
    $health = $null
    $drift = $null
    $unmapped = $null
    $deepStatus = ""
    $h = [regex]::Match($text, "(?im)^\s*Health(?:\s+Score)?\s*:\s*(\d{1,3})\s*/\s*100")
    if ($h.Success) { $health = [int]$h.Groups[1].Value }
    $d = [regex]::Match($text, "(?im)Deterministic\s+Drift\s+Totals\s*:\s*.*?TOTAL\s*=\s*(\d+)")
    if ($d.Success) { $drift = [int]$d.Groups[1].Value }
    $u = [regex]::Match($text, "(?im)Unmapped\s+findings\s*:\s*(\d+)")
    if ($u.Success) { $unmapped = [int]$u.Groups[1].Value }
    $s = [regex]::Match($text, "(?im)^\s*Deep\s+Review\s+Totals\s*:\s*STATUS=([A-Z_]+)")
    if ($s.Success) { $deepStatus = [string]$s.Groups[1].Value }
    return [pscustomobject]@{
        health = $health
        drift = $drift
        unmapped = $unmapped
        deepStatus = $deepStatus
    }
}

function Parse-CodeSummaryFindingsCount {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $json = Get-Content -Raw -Path $Path | ConvertFrom-Json
        if ($json -and $json.totals -and $json.totals.PSObject.Properties["TOTAL_FINDINGS"]) {
            return [int]$json.totals.TOTAL_FINDINGS
        }
    } catch {}
    return $null
}

function Write-Manifest {
    param(
        [string]$Path,
        [hashtable]$Data
    )
    $dir = Split-Path -Parent $Path
    Ensure-Directory -Path $dir
    $json = ($Data | ConvertTo-Json -Depth 10) + "`n"
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

$resolvedProjectRoot = (Resolve-Path -Path $ProjectRoot).Path
$runsRoot = Resolve-FromProject -Root $resolvedProjectRoot -RelativeOrAbsolute "docs/review-runs"
Ensure-Directory -Path $runsRoot

switch ($Action) {
    "capture" {
        $sourcePath = Resolve-FromProject -Root $resolvedProjectRoot -RelativeOrAbsolute $SourceRoot
        if (-not (Test-Path $sourcePath)) {
            throw "Source review root not found: $sourcePath"
        }

        $effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") } else { $RunId }
        $destPath = Join-Path (Join-Path $runsRoot $Variant) $effectiveRunId
        Ensure-Directory -Path (Split-Path -Parent $destPath)
        Copy-DirectoryContents -Source $sourcePath -Destination $destPath

        $manifestPath = Join-Path $destPath "RUN-MANIFEST.json"
        Write-Manifest -Path $manifestPath -Data ([ordered]@{
                capturedUtc = (Get-Date).ToUniversalTime().ToString("o")
                variant = $Variant
                runId = $effectiveRunId
                sourceRoot = (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $sourcePath)
                note = $ManifestNote
            })

        Write-Output ("captured={0}" -f $destPath)
        break
    }

    "list" {
        $rows = New-Object System.Collections.Generic.List[object]
        $variantDirs = Get-ChildItem -Path $runsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($variantDir in $variantDirs) {
            $runDirs = Get-ChildItem -Path $variantDir.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending
            foreach ($runDir in $runDirs) {
                $summaryPath = Join-Path $runDir.FullName "EXECUTIVE-SUMMARY.md"
                $codeSummaryPath = Join-Path $runDir.FullName "layers\code-review-summary.json"
                $metrics = Parse-ExecutiveSummaryMetrics -Path $summaryPath
                $totalFindings = Parse-CodeSummaryFindingsCount -Path $codeSummaryPath
                $rows.Add([pscustomobject]@{
                        variant = $variantDir.Name
                        runId = $runDir.Name
                        capturedUtc = (Get-Item $runDir.FullName).LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
                        health = if ($metrics) { $metrics.health } else { $null }
                        drift = if ($metrics) { $metrics.drift } else { $null }
                        unmapped = if ($metrics) { $metrics.unmapped } else { $null }
                        deepStatus = if ($metrics) { $metrics.deepStatus } else { "" }
                        totalFindings = $totalFindings
                        path = (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $runDir.FullName)
                    }) | Out-Null
            }
        }

        if ($rows.Count -eq 0) {
            Write-Output "no review variants found under docs/review-runs"
        } else {
            $rows | Sort-Object variant, runId -Descending | Format-Table -AutoSize
        }
        break
    }

    "promote" {
        $sourceRunPath = Resolve-RunPath -RunsRoot $runsRoot -VariantName $Variant -RunName $RunId
        if ([string]::IsNullOrWhiteSpace([string]$sourceRunPath) -or -not (Test-Path $sourceRunPath)) {
            throw "Source run not found for variant '$Variant' run '$RunId'."
        }

        $targetPath = Resolve-FromProject -Root $resolvedProjectRoot -RelativeOrAbsolute $TargetRoot
        Ensure-Directory -Path $targetPath

        $backupId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
        $backupPath = Join-Path (Join-Path $runsRoot "_backups") ("{0}-{1}" -f $backupId, $Variant)
        Ensure-Directory -Path (Split-Path -Parent $backupPath)
        if (Test-Path $targetPath) {
            Copy-DirectoryContents -Source $targetPath -Destination $backupPath
        }

        Clear-DirectoryContents -Path $targetPath
        Copy-DirectoryContents -Source $sourceRunPath -Destination $targetPath

        Write-Output ("promoted_source={0}" -f (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $sourceRunPath))
        Write-Output ("promoted_target={0}" -f (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $targetPath))
        Write-Output ("backup={0}" -f (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $backupPath))
        break
    }

    "merge" {
        $resolvedSources = New-Object System.Collections.Generic.List[object]
        foreach ($sourceToken in @($MergeSources)) {
            if ([string]::IsNullOrWhiteSpace($sourceToken)) { continue }
            $parts = $sourceToken.Split(":")
            $sourceVariant = $parts[0]
            $sourceRunId = if ($parts.Count -ge 2) { $parts[1] } else { "latest" }
            $sourcePath = Resolve-RunPath -RunsRoot $runsRoot -VariantName $sourceVariant -RunName $sourceRunId
            if ($sourcePath) {
                $resolvedSources.Add([pscustomobject]@{
                        variant = $sourceVariant
                        runId = if ($sourceRunId) { $sourceRunId } else { "latest" }
                        path = $sourcePath
                    }) | Out-Null
            }
        }

        if ($resolvedSources.Count -eq 0) {
            throw "No merge sources could be resolved. Use -MergeSources like codex:latest,claude:latest."
        }

        $effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") } else { $RunId }
        $mergeRoot = Join-Path (Join-Path $runsRoot "merged") $effectiveRunId
        Ensure-Directory -Path $mergeRoot

        $index = @{}
        $mergedFindings = New-Object System.Collections.Generic.List[object]
        $sourceStats = New-Object System.Collections.Generic.List[object]

        foreach ($src in $resolvedSources) {
            $summaryPath = Join-Path $src.path "layers\code-review-summary.json"
            $sourceCount = 0
            if (Test-Path $summaryPath) {
                try {
                    $json = Get-Content -Raw -Path $summaryPath | ConvertFrom-Json
                    foreach ($f in @($json.findings)) {
                        $id = [string]$f.id
                        if ([string]::IsNullOrWhiteSpace($id)) {
                            $id = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($f | ConvertTo-Json -Compress)))
                        }
                        if (-not $index.ContainsKey($id)) {
                            $index[$id] = $true
                            $mergedFindings.Add($f) | Out-Null
                        }
                        $sourceCount++
                    }
                } catch {}
            }
            $sourceStats.Add([pscustomobject]@{
                    variant = $src.variant
                    runId = $src.runId
                    findingsRead = $sourceCount
                    path = (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $src.path)
                }) | Out-Null
        }

        $sev = [ordered]@{ BLOCKER = 0; HIGH = 0; MEDIUM = 0; LOW = 0 }
        foreach ($f in @($mergedFindings)) {
            $s = ([string]$f.severity).ToUpperInvariant()
            if ($sev.Contains($s)) { $sev[$s]++ }
        }
        $summary = [ordered]@{
            generatedUtc = (Get-Date).ToUniversalTime().ToString("o")
            mergedFrom = @($sourceStats)
            totals = [ordered]@{
                BLOCKER = [int]$sev.BLOCKER
                HIGH = [int]$sev.HIGH
                MEDIUM = [int]$sev.MEDIUM
                LOW = [int]$sev.LOW
                TOTAL_FINDINGS = [int]$mergedFindings.Count
            }
            findings = @($mergedFindings)
        }

        Write-Manifest -Path (Join-Path $mergeRoot "merged-findings.json") -Data $summary

        $lines = @(
            "# Merged Review Findings",
            "",
            ("Generated UTC: {0}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")),
            "",
            "## Sources"
        )
        foreach ($srcStat in @($sourceStats)) {
            $lines += ("- {0} ({1}) -> findings read={2} path={3}" -f $srcStat.variant, $srcStat.runId, $srcStat.findingsRead, $srcStat.path)
        }
        $lines += ""
        $lines += "## Totals"
        $lines += ("- BLOCKER={0} HIGH={1} MEDIUM={2} LOW={3} TOTAL={4}" -f $sev.BLOCKER, $sev.HIGH, $sev.MEDIUM, $sev.LOW, $mergedFindings.Count)
        $lines += ""
        $lines += "Use this merged output to generate remediation phases covering both review sources."
        [System.IO.File]::WriteAllText((Join-Path $mergeRoot "MERGE-SUMMARY.md"), (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))

        Write-Output ("merged={0}" -f (To-RelativeUnixPath -BasePath $resolvedProjectRoot -TargetPath $mergeRoot))
        break
    }
}
