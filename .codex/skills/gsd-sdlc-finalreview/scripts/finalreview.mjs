#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

const DEFAULTS = {
  codeScope: "generated+src",
  figmaVersion: "v8",
  specMode: "phase-ae+spec",
  confirmOnly: false,
  skipBuild: false,
  repoRoot: null,
};

const CODE_EXTENSIONS = new Set([".cs", ".ts", ".tsx", ".js", ".sql", ".ps1", ".sh"]);
const EXCLUDED_DIRS = new Set(["node_modules", "dist", "build", "bin", "obj", ".git"]);

function main() {
  const args = parseArgs(process.argv.slice(2));
  const cwd = process.cwd();
  const resolved = resolveCanonicalRoot(cwd, args.repoRoot);
  const root = resolved.selectedPath;

  const artifacts = {
    map: path.join(root, "docs", "review", "layers", "finalreview-line-map.jsonl"),
    summary: path.join(root, "docs", "review", "layers", "finalreview-summary.json"),
    report: path.join(root, "docs", "review", "FINAL-SDLC-LINE-TRACEABILITY.md"),
  };

  try {
    const baseline = args.confirmOnly ? readExistingSummary(artifacts.summary) : null;
    const inputs = resolveInputs(root, args.figmaVersion);
    const index = buildReferenceIndex(root, inputs);
    const analysis = runLineAnalysis(root, args, inputs, index, artifacts.map);
    const summary = finalizeSummary({
      root,
      args,
      resolved,
      inputs,
      analysis,
      baseline,
      summaryPath: artifacts.summary,
    });

    ensureDir(path.dirname(artifacts.summary));
    ensureDir(path.dirname(artifacts.report));
    fs.writeFileSync(artifacts.summary, JSON.stringify(summary, null, 2) + "\n", "utf8");
    fs.writeFileSync(artifacts.report, buildReportMarkdown(summary, analysis), "utf8");

    printResultLines(summary, artifacts);
    process.exit(summary.status === "passed" ? 0 : 2);
  } catch (error) {
    const fallbackSummary = buildFatalSummary({
      root,
      resolved,
      args,
      error,
      summaryPath: artifacts.summary,
    });
    ensureDir(path.dirname(artifacts.summary));
    ensureDir(path.dirname(artifacts.report));
    fs.writeFileSync(artifacts.summary, JSON.stringify(fallbackSummary, null, 2) + "\n", "utf8");
    fs.writeFileSync(
      artifacts.report,
      buildFatalReportMarkdown(fallbackSummary, error),
      "utf8",
    );
    printResultLines(fallbackSummary, artifacts);
    process.exit(2);
  }
}

function parseArgs(argv) {
  const args = { ...DEFAULTS };
  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    if (item === "--confirm-only") {
      args.confirmOnly = true;
      continue;
    }
    if (item === "--skip-build") {
      args.skipBuild = true;
      continue;
    }
    if (item.startsWith("--code-scope=")) {
      args.codeScope = item.split("=", 2)[1] || DEFAULTS.codeScope;
      continue;
    }
    if (item.startsWith("--figma-version=")) {
      args.figmaVersion = item.split("=", 2)[1] || DEFAULTS.figmaVersion;
      continue;
    }
    if (item.startsWith("--spec-mode=")) {
      args.specMode = item.split("=", 2)[1] || DEFAULTS.specMode;
      continue;
    }
    if (item === "--repo-root") {
      if (i + 1 < argv.length) {
        args.repoRoot = argv[i + 1];
        i += 1;
      }
      continue;
    }
    if (item.startsWith("--repo-root=")) {
      args.repoRoot = item.split("=", 2)[1] || null;
      continue;
    }
  }
  return args;
}

function resolveCanonicalRoot(cwd, repoRootArg) {
  const candidates = [];
  if (repoRootArg) {
    const explicitPath = resolveUserPath(cwd, repoRootArg);
    candidates.push(explicitPath);
  } else {
    candidates.push(path.resolve(cwd));
    candidates.push(path.resolve(cwd, "tech-web-chatai.2"));
  }

  const scored = [];
  for (const candidate of uniqueArray(candidates)) {
    if (!dirExists(candidate)) {
      continue;
    }
    const label = normalizeCandidateLabel(cwd, candidate);
    const score = scoreRoot(candidate);
    scored.push({ label, path: candidate, score });
  }

  if (scored.length === 0) {
    throw new Error("No valid root candidates found.");
  }

  scored.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }
    return a.label.localeCompare(b.label);
  });

  const candidateScores = {};
  for (const item of scored) {
    candidateScores[item.label] = item.score;
  }

  return {
    selectedLabel: scored[0].label,
    selectedPath: scored[0].path,
    candidateScores,
  };
}

function scoreRoot(root) {
  let score = 0;
  if (fileExists(path.join(root, ".planning", "ROADMAP.md"))) score += 1;
  if (fileExists(path.join(root, ".planning", "STATE.md"))) score += 1;
  if (dirExists(path.join(root, "docs", "spec"))) score += 1;
  if (dirExists(path.join(root, "docs", "review"))) score += 1;
  if (dirExists(path.join(root, "design", "figma"))) score += 1;
  if (dirExists(path.join(root, "generated"))) score += 1;
  if (dirExists(path.join(root, "src"))) score += 1;
  if (dirExists(path.join(root, "db"))) score += 1;
  return score;
}

function resolveInputs(root, figmaVersion) {
  const figmaRoot = path.join(root, "design", "figma", figmaVersion, "src");
  const figmaScreenDir = path.join(figmaRoot, "components", "screens");
  const figmaAnalysisDir = path.join(figmaRoot, "_analysis");

  const phaseDocs = [
    path.join(root, "docs", "sdlc", "docs", "Phase_A_Intake_Requirements.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_B_Specification_Architecture_Pack.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_C_UI_Prototyping_Figma_Full_Stack_Generation.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_D_Blueprint.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_D_Alignment_Report.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_D_Acceptance_Criteria.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_D_Business_Design_Approval.md"),
    path.join(root, "docs", "sdlc", "docs", "Phase_E_Contract_Freeze.md"),
  ];

  const specDocs = [
    path.join(root, "docs", "spec", "ui-contract.md"),
    path.join(root, "docs", "spec", "openapi.yaml"),
    path.join(root, "docs", "spec", "apitospmap.md"),
    path.join(root, "docs", "spec", "db-plan.md"),
    path.join(root, "docs", "spec", "test-plan.md"),
    path.join(root, "docs", "spec", "ci-gates.md"),
    path.join(root, "docs", "spec", "remote-agent.md"),
    path.join(root, "docs", "spec", "openclaw-remote-agent-spec.md"),
  ];

  const phaseDetailDirs = [
    path.join(root, "docs", "phases", "phase-c"),
    path.join(root, "docs", "phases", "phase-d"),
    path.join(root, "docs", "phases", "phase-e"),
  ];

  const missingInputs = [];
  if (!dirExists(figmaRoot)) {
    missingInputs.push({
      type: "figma-root",
      path: relativeTo(root, figmaRoot),
    });
  }

  for (const p of phaseDocs) {
    if (!fileExists(p)) {
      missingInputs.push({ type: "phase-doc", path: relativeTo(root, p) });
    }
  }
  for (const p of specDocs) {
    if (!fileExists(p)) {
      missingInputs.push({ type: "spec-doc", path: relativeTo(root, p) });
    }
  }
  for (const d of phaseDetailDirs) {
    if (!dirExists(d)) {
      missingInputs.push({ type: "phase-dir", path: relativeTo(root, d) });
    }
  }

  const figmaScreens = dirExists(figmaScreenDir)
    ? listFilesRecursive(figmaScreenDir, (filePath) => filePath.endsWith(".tsx"))
    : [];
  const figmaAnalysisDocs = dirExists(figmaAnalysisDir)
    ? listFilesRecursive(figmaAnalysisDir, (filePath) => filePath.endsWith(".md"))
    : [];
  const phaseDetailDocs = phaseDetailDirs.flatMap((dirPath) =>
    dirExists(dirPath) ? listFilesRecursive(dirPath, (fp) => fp.endsWith(".md") || fp.endsWith(".yaml") || fp.endsWith(".yml")) : [],
  );

  const specDirDocs = dirExists(path.join(root, "docs", "spec"))
    ? listFilesRecursive(path.join(root, "docs", "spec"), (fp) => fp.endsWith(".md") || fp.endsWith(".yaml") || fp.endsWith(".yml") || fp.endsWith(".json"))
    : [];

  const allSpecFiles = uniqueArray([...phaseDocs, ...specDocs, ...phaseDetailDocs, ...specDirDocs]).filter(fileExists);
  const allFigmaFiles = uniqueArray([...figmaScreens, ...figmaAnalysisDocs]).filter(fileExists);

  return {
    figmaRoot,
    figmaVersion,
    figmaScreens,
    figmaAnalysisDocs,
    phaseDocs,
    specDocs,
    phaseDetailDirs,
    allSpecFiles,
    allFigmaFiles,
    missingInputs,
    preferredRefs: {
      figmaFallback: firstExisting([
        path.join(figmaRoot, "_analysis", "01-screen-inventory.md"),
        path.join(figmaRoot, "_analysis", "04-navigation-routing.md"),
        figmaScreens[0] || null,
      ]),
      figmaApi: firstExisting([
        path.join(figmaRoot, "_analysis", "06-api-contracts.md"),
        path.join(figmaRoot, "_analysis", "08-business-logic-services.md"),
        figmaScreens[0] || null,
      ]),
      figmaData: firstExisting([
        path.join(figmaRoot, "_analysis", "05-data-types.md"),
        path.join(figmaRoot, "_analysis", "08-business-logic-services.md"),
        figmaScreens[0] || null,
      ]),
      figmaInfra: firstExisting([
        path.join(figmaRoot, "_analysis", "17-technical-architecture.md"),
        path.join(figmaRoot, "_analysis", "13-security-compliance.md"),
        figmaScreens[0] || null,
      ]),
      specFallback: firstExisting([
        path.join(root, "docs", "spec", "ui-contract.md"),
        path.join(root, "docs", "spec", "openapi.yaml"),
      ]),
      specOpenApi: firstExisting([
        path.join(root, "docs", "spec", "openapi.yaml"),
        path.join(root, "docs", "phases", "phase-e", "02_openapi_final.yaml"),
      ]),
      specApiMap: firstExisting([
        path.join(root, "docs", "spec", "apitospmap.md"),
        path.join(root, "docs", "phases", "phase-e", "03_api_sp_map.md"),
      ]),
      specDbPlan: firstExisting([
        path.join(root, "docs", "spec", "db-plan.md"),
        path.join(root, "docs", "phases", "phase-e", "04_db_plan.md"),
      ]),
      specUiContract: firstExisting([
        path.join(root, "docs", "spec", "ui-contract.md"),
        path.join(root, "docs", "phases", "phase-e", "01_ui_contract_final.md"),
      ]),
      specCi: firstExisting([
        path.join(root, "docs", "spec", "ci-gates.md"),
        path.join(root, "docs", "phases", "phase-e", "06_ci_gates.md"),
      ]),
      specTest: firstExisting([
        path.join(root, "docs", "spec", "test-plan.md"),
        path.join(root, "docs", "phases", "phase-e", "05_test_plan.md"),
      ]),
      phaseA: path.join(root, "docs", "sdlc", "docs", "Phase_A_Intake_Requirements.md"),
      phaseB: path.join(root, "docs", "sdlc", "docs", "Phase_B_Specification_Architecture_Pack.md"),
      phaseC: firstExisting([
        path.join(root, "docs", "sdlc", "docs", "Phase_C_UI_Prototyping_Figma_Full_Stack_Generation.md"),
        path.join(root, "docs", "phases", "phase-c", "03_component_specs.md"),
      ]),
      phaseD: firstExisting([
        path.join(root, "docs", "sdlc", "docs", "Phase_D_Blueprint.md"),
        path.join(root, "docs", "phases", "phase-d", "02_ui_contract_route_inventory.md"),
      ]),
      phaseE: firstExisting([
        path.join(root, "docs", "sdlc", "docs", "Phase_E_Contract_Freeze.md"),
        path.join(root, "docs", "phases", "phase-e", "09_final_alignment_summary.md"),
      ]),
      remoteAgent: firstExisting([
        path.join(root, "docs", "spec", "remote-agent.md"),
        path.join(root, "docs", "spec", "openclaw-remote-agent-spec.md"),
      ]),
    },
  };
}

function buildReferenceIndex(root, inputs) {
  const figmaByToken = new Map();
  const specByToken = new Map();
  const openApiRouteTokens = new Set();

  for (const screenFile of inputs.figmaScreens) {
    const rel = relativeTo(root, screenFile);
    for (const token of tokenize(rel).concat(tokensFromIdentifier(path.basename(screenFile, path.extname(screenFile))))) {
      addToTokenMap(figmaByToken, token, rel);
    }
  }
  for (const analysisFile of inputs.figmaAnalysisDocs) {
    const rel = relativeTo(root, analysisFile);
    for (const token of tokenize(rel)) {
      addToTokenMap(figmaByToken, token, rel);
    }
  }

  for (const specFile of inputs.allSpecFiles) {
    const rel = relativeTo(root, specFile);
    const content = safeReadText(specFile);
    for (const token of tokenize(rel).concat(tokenize(content.slice(0, 20000)))) {
      addToTokenMap(specByToken, token, rel);
    }
  }

  const openApiPath = inputs.preferredRefs.specOpenApi;
  if (openApiPath && fileExists(openApiPath)) {
    const lines = safeReadText(openApiPath).split(/\r?\n/);
    const routePattern = /^\s*(\/[A-Za-z0-9{}._/\-]+):\s*$/;
    for (const line of lines) {
      const match = routePattern.exec(line);
      if (!match) {
        continue;
      }
      for (const token of tokenize(match[1])) {
        openApiRouteTokens.add(token);
      }
    }
  }

  return {
    figmaByToken,
    specByToken,
    openApiRouteTokens,
  };
}

function runLineAnalysis(root, args, inputs, index, mapPath) {
  const codeFiles = discoverCodeFiles(root, args.codeScope);
  ensureDir(path.dirname(mapPath));
  const mapHasher = crypto.createHash("sha256");
  const mapRows = [];

  let totalExecutableLines = 0;
  let mappedLines = 0;
  let unmappedLines = 0;
  const unmappedSamples = [];
  const categoryCounts = {};

  for (const absPath of codeFiles) {
    const relPath = relativeTo(root, absPath);
    const ext = path.extname(absPath).toLowerCase();
    const lines = extractExecutableLines(safeReadText(absPath), ext);

    for (const line of lines) {
      totalExecutableLines += 1;
      const category = classifyCategory(relPath, line.text, ext);
      categoryCounts[category] = (categoryCounts[category] || 0) + 1;

      const mapping = mapLine({
        root,
        relPath,
        ext,
        lineText: line.text,
        category,
        inputs,
        index,
      });

      if (mapping.mapped) {
        mappedLines += 1;
      } else {
        unmappedLines += 1;
        if (unmappedSamples.length < 200) {
          unmappedSamples.push({
            file: relPath,
            line: line.line,
            category,
            text: line.text.slice(0, 240),
          });
        }
      }

      const record = {
        file: relPath,
        line: line.line,
        lang: ext.replace(".", ""),
        category,
        mapped: mapping.mapped,
        figma_refs: mapping.figmaRefs,
        spec_refs: mapping.specRefs,
        mapping_path: mapping.mappingPath,
      };
      const row = JSON.stringify(record);
      mapRows.push(row);
      mapHasher.update(row + "\n");
    }
  }
  fs.writeFileSync(mapPath, mapRows.join("\n") + (mapRows.length ? "\n" : ""), "utf8");

  const mapHash = mapHasher.digest("hex");
  const coveragePercent =
    totalExecutableLines === 0
      ? 0
      : Number(((mappedLines / totalExecutableLines) * 100).toFixed(6));

  const driftTotal = detectDriftTotal(root);
  const pendingRemediation = countPendingRemediation(root);
  const missingInputCount = inputs.missingInputs.length;

  const gates = {
    coverage_100: totalExecutableLines > 0 && mappedLines === totalExecutableLines,
    unmapped_0: unmappedLines === 0,
    drift_0: driftTotal === 0,
    pending_0: pendingRemediation === 0,
    missing_inputs_0: missingInputCount === 0,
  };

  const pass =
    gates.coverage_100 &&
    gates.unmapped_0 &&
    gates.drift_0 &&
    gates.pending_0 &&
    gates.missing_inputs_0;

  let health = 100;
  if (!pass) {
    if (missingInputCount > 0 || totalExecutableLines === 0) health -= 40;
    if (driftTotal > 0) health -= 25;
    if (pendingRemediation > 0) health -= 20;
    if (unmappedLines > 0) health -= 15;
    if (coveragePercent < 100) health -= 10;
  }
  health = Math.max(0, Math.min(100, health));

  const findings = [];
  if (missingInputCount > 0) {
    findings.push({
      id: "FINALREVIEW-BLOCKER-MISSING-INPUTS",
      severity: "BLOCKER",
      message: "Missing authoritative Figma/spec inputs required for final review.",
      evidence: inputs.missingInputs,
    });
  }
  if (totalExecutableLines === 0) {
    findings.push({
      id: "FINALREVIEW-BLOCKER-NO-EXECUTABLE-LINES",
      severity: "BLOCKER",
      message: "No executable lines were discovered in configured code scope.",
      evidence: [{ code_scope: args.codeScope }],
    });
  }
  if (unmappedLines > 0 || coveragePercent < 100) {
    findings.push({
      id: "FINALREVIEW-HIGH-UNMAPPED-LINES",
      severity: "HIGH",
      message: "Executable lines missing deterministic figma/spec mapping.",
      evidence: unmappedSamples.slice(0, 50),
    });
  }
  if (driftTotal > 0) {
    findings.push({
      id: "FINALREVIEW-HIGH-DRIFT",
      severity: "HIGH",
      message: "Deterministic drift total is non-zero.",
      evidence: [{ drift_total: driftTotal }],
    });
  }
  if (pendingRemediation > 0) {
    findings.push({
      id: "FINALREVIEW-HIGH-PENDING-REMEDIATION",
      severity: "HIGH",
      message: "Pending remediation phases remain.",
      evidence: [{ pending_remediation: pendingRemediation }],
    });
  }

  return {
    codeFileCount: codeFiles.length,
    totalExecutableLines,
    mappedLines,
    unmappedLines,
    coveragePercent,
    driftTotal,
    pendingRemediation,
    mapHash,
    categoryCounts,
    gates,
    pass,
    health,
    findings,
    unmappedSamples,
  };
}

function finalizeSummary({ root, args, resolved, inputs, analysis, baseline, summaryPath }) {
  const commitSha = detectCommitSha(root);
  const now = new Date().toISOString();

  const hashInput = {
    version: 1,
    commit_sha: commitSha,
    code_scope: args.codeScope,
    line_policy: "executable-only",
    figma_version: args.figmaVersion,
    spec_mode: args.specMode,
    total_executable_lines: analysis.totalExecutableLines,
    mapped_lines: analysis.mappedLines,
    unmapped_lines: analysis.unmappedLines,
    coverage_percent: analysis.coveragePercent,
    drift_total: analysis.driftTotal,
    pending_remediation: analysis.pendingRemediation,
    map_hash: analysis.mapHash,
    category_counts: analysis.categoryCounts,
  };
  const summaryHash = sha256(stableJSONString(hashInput));

  let status = analysis.pass ? "passed" : "failed";
  let stopReason = analysis.pass ? "SUCCESS_FINALREVIEW_GATES_MET" : inferFailureReason(analysis);
  const confirmation = {
    mode: args.confirmOnly,
  };

  if (args.confirmOnly) {
    if (!baseline) {
      status = "failed";
      stopReason = "FINALREVIEW_PARSE_FAILURE";
      confirmation.error = "Baseline summary missing for confirm-only run.";
    } else {
      const baselineCommit = baseline.commit_sha || "";
      const baselineHash = baseline.summary_hash || "";
      const commitUnchanged = baselineCommit === commitSha;
      const hashMatch = baselineHash === summaryHash;
      confirmation.baseline_commit_sha = baselineCommit;
      confirmation.baseline_summary_hash = baselineHash;
      confirmation.current_commit_sha = commitSha;
      confirmation.current_summary_hash = summaryHash;
      confirmation.commit_unchanged = commitUnchanged;
      confirmation.summary_hash_match = hashMatch;

      if (!commitUnchanged || !hashMatch) {
        status = "failed";
        stopReason = "FINALREVIEW_CONFIRMATION_MISMATCH";
      } else if (analysis.pass) {
        status = "passed";
        stopReason = "SUCCESS_FINALREVIEW_CONFIRMATION_MATCH";
      } else {
        status = "failed";
        stopReason = inferFailureReason(analysis);
      }
    }
  }

  return {
    generated_utc: now,
    status,
    stop_reason: stopReason,
    confirm_only: args.confirmOnly,
    health: status === "passed" ? 100 : analysis.health,
    drift_total: analysis.driftTotal,
    unmapped_lines: analysis.unmappedLines,
    coverage_percent: analysis.coveragePercent,
    pending_remediation: analysis.pendingRemediation,
    commit_sha: commitSha,
    summary_hash: summaryHash,
    map_hash: analysis.mapHash,
    line_policy: "executable-only",
    code_scope: args.codeScope,
    figma_version: args.figmaVersion,
    spec_mode: args.specMode,
    repo_root: relativeTo(process.cwd(), root),
    canonical_root: resolved.selectedLabel,
    candidate_scores: resolved.candidateScores,
    metrics: {
      code_file_count: analysis.codeFileCount,
      total_executable_lines: analysis.totalExecutableLines,
      mapped_lines: analysis.mappedLines,
      unmapped_lines: analysis.unmappedLines,
      coverage_percent: analysis.coveragePercent,
      drift_total: analysis.driftTotal,
      pending_remediation: analysis.pendingRemediation,
      health: status === "passed" ? 100 : analysis.health,
    },
    gates: analysis.gates,
    findings: analysis.findings,
    references: {
      figma_root: relativeTo(root, inputs.figmaRoot),
      figma_screen_count: inputs.figmaScreens.length,
      figma_analysis_count: inputs.figmaAnalysisDocs.length,
      missing_inputs: inputs.missingInputs,
      spec_file_count: inputs.allSpecFiles.length,
      phase_docs: inputs.phaseDocs.map((p) => relativeTo(root, p)).filter((p) =>
        fileExists(path.join(root, p)),
      ),
      spec_docs: inputs.specDocs.map((p) => relativeTo(root, p)).filter((p) =>
        fileExists(path.join(root, p)),
      ),
    },
    artifacts: {
      map_path: relativeTo(root, path.join(root, "docs", "review", "layers", "finalreview-line-map.jsonl")),
      summary_path: relativeTo(root, summaryPath),
      report_path: relativeTo(root, path.join(root, "docs", "review", "FINAL-SDLC-LINE-TRACEABILITY.md")),
    },
    confirmation,
  };
}

function inferFailureReason(analysis) {
  if (!analysis.gates.missing_inputs_0 || analysis.totalExecutableLines === 0) {
    return "FINALREVIEW_PARSE_FAILURE";
  }
  return "FINALREVIEW_UNMAPPED";
}

function buildReportMarkdown(summary, analysis) {
  const lines = [];
  lines.push("# FINAL SDLC Line Traceability Report");
  lines.push("");
  lines.push(`Generated: ${summary.generated_utc}`);
  lines.push(`Status: ${summary.status}`);
  lines.push(`Stop Reason: ${summary.stop_reason}`);
  lines.push("");
  lines.push("## Metrics");
  lines.push("");
  lines.push(`- Health: ${summary.health}/100`);
  lines.push(`- Coverage Percent: ${summary.coverage_percent}`);
  lines.push(`- Total Executable Lines: ${summary.metrics.total_executable_lines}`);
  lines.push(`- Mapped Lines: ${summary.metrics.mapped_lines}`);
  lines.push(`- Unmapped Lines: ${summary.unmapped_lines}`);
  lines.push(`- Deterministic Drift Total: ${summary.drift_total}`);
  lines.push(`- Pending Remediation: ${summary.pending_remediation}`);
  lines.push(`- Commit SHA: ${summary.commit_sha}`);
  lines.push(`- Summary Hash: ${summary.summary_hash}`);
  lines.push("");
  lines.push("## Scope");
  lines.push("");
  lines.push(`- Code Scope: ${summary.code_scope}`);
  lines.push(`- Line Policy: ${summary.line_policy}`);
  lines.push(`- Figma Baseline: ${summary.references.figma_root}`);
  lines.push(`- Spec Mode: ${summary.spec_mode}`);
  lines.push(`- Canonical Root: ${summary.canonical_root}`);
  lines.push("");
  lines.push("## Gate Status");
  lines.push("");
  for (const [gate, value] of Object.entries(summary.gates)) {
    lines.push(`- ${gate}: ${value ? "PASS" : "FAIL"}`);
  }
  lines.push("");
  lines.push("## Findings");
  lines.push("");
  if (!summary.findings.length) {
    lines.push("- None");
  } else {
    for (const finding of summary.findings) {
      lines.push(`- ${finding.id} (${finding.severity}): ${finding.message}`);
    }
  }
  lines.push("");
  lines.push("## Unmapped Samples");
  lines.push("");
  if (!analysis.unmappedSamples.length) {
    lines.push("- None");
  } else {
    for (const sample of analysis.unmappedSamples.slice(0, 50)) {
      lines.push(`- ${sample.file}:${sample.line} [${sample.category}] ${sample.text}`);
    }
  }
  lines.push("");
  lines.push("## Confirmation");
  lines.push("");
  lines.push(`- Confirm Only Mode: ${summary.confirm_only}`);
  if (summary.confirmation && summary.confirmation.mode) {
    lines.push(`- Baseline Commit SHA: ${summary.confirmation.baseline_commit_sha || "n/a"}`);
    lines.push(`- Current Commit SHA: ${summary.confirmation.current_commit_sha || "n/a"}`);
    lines.push(`- Baseline Summary Hash: ${summary.confirmation.baseline_summary_hash || "n/a"}`);
    lines.push(`- Current Summary Hash: ${summary.confirmation.current_summary_hash || "n/a"}`);
    lines.push(`- Commit Unchanged: ${Boolean(summary.confirmation.commit_unchanged)}`);
    lines.push(`- Summary Hash Match: ${Boolean(summary.confirmation.summary_hash_match)}`);
  }
  lines.push("");
  return lines.join("\n") + "\n";
}

function buildFatalSummary({ root, resolved, args, error, summaryPath }) {
  const now = new Date().toISOString();
  const commitSha = detectCommitSha(root);
  const msg = String(error && error.message ? error.message : error);
  const hashInput = {
    version: 1,
    commit_sha: commitSha,
    error: msg,
    code_scope: args.codeScope,
    figma_version: args.figmaVersion,
    spec_mode: args.specMode,
  };
  const summaryHash = sha256(stableJSONString(hashInput));
  return {
    generated_utc: now,
    status: "failed",
    stop_reason: "FINALREVIEW_PARSE_FAILURE",
    confirm_only: args.confirmOnly,
    health: 0,
    drift_total: 0,
    unmapped_lines: 0,
    coverage_percent: 0,
    pending_remediation: 0,
    commit_sha: commitSha,
    summary_hash: summaryHash,
    line_policy: "executable-only",
    code_scope: args.codeScope,
    figma_version: args.figmaVersion,
    spec_mode: args.specMode,
    canonical_root: resolved ? resolved.selectedLabel : ".",
    candidate_scores: resolved ? resolved.candidateScores : {},
    findings: [
      {
        id: "FINALREVIEW-BLOCKER-PARSE",
        severity: "BLOCKER",
        message: msg,
        evidence: [{ summary_path: relativeTo(root, summaryPath) }],
      },
    ],
  };
}

function buildFatalReportMarkdown(summary, error) {
  return [
    "# FINAL SDLC Line Traceability Report",
    "",
    `Generated: ${summary.generated_utc}`,
    "Status: failed",
    `Stop Reason: ${summary.stop_reason}`,
    "",
    "## Error",
    "",
    "```",
    String(error && error.stack ? error.stack : error),
    "```",
    "",
  ].join("\n");
}

function printResultLines(summary, artifacts) {
  console.log(`FINALREVIEW_STATUS=${summary.status}`);
  console.log(`FINALREVIEW_STOP_REASON=${summary.stop_reason}`);
  console.log(`FINALREVIEW_HEALTH=${summary.health}`);
  console.log(`FINALREVIEW_DRIFT_TOTAL=${summary.drift_total}`);
  console.log(`FINALREVIEW_UNMAPPED_LINES=${summary.unmapped_lines}`);
  console.log(`FINALREVIEW_COVERAGE_PERCENT=${summary.coverage_percent}`);
  console.log(`FINALREVIEW_PENDING_REMEDIATION=${summary.pending_remediation}`);
  console.log(`FINALREVIEW_COMMIT_SHA=${summary.commit_sha}`);
  console.log(`FINALREVIEW_SUMMARY_HASH=${summary.summary_hash}`);
  console.log(`FINALREVIEW_SUMMARY_PATH=${toPosixPath(artifacts.summary)}`);
  console.log(`FINALREVIEW_REPORT_PATH=${toPosixPath(artifacts.report)}`);
  console.log(`FINALREVIEW_MAP_PATH=${toPosixPath(artifacts.map)}`);
}

function discoverCodeFiles(root, codeScope) {
  const scopes = [];
  if (codeScope === "generated+src" || !codeScope) {
    scopes.push(path.join(root, "generated"));
    scopes.push(path.join(root, "src"));
  } else {
    for (const token of codeScope.split("+")) {
      const trimmed = token.trim();
      if (trimmed) {
        scopes.push(path.join(root, trimmed));
      }
    }
  }

  const discovered = [];
  for (const scope of uniqueArray(scopes)) {
    if (!dirExists(scope)) {
      continue;
    }
    const files = listFilesRecursive(scope, (filePath) => CODE_EXTENSIONS.has(path.extname(filePath).toLowerCase()));
    discovered.push(...files);
  }
  return uniqueArray(discovered).sort((a, b) => relativeTo(root, a).localeCompare(relativeTo(root, b)));
}

function extractExecutableLines(content, ext) {
  const lines = content.split(/\r?\n/);
  const cfg = commentConfig(ext);
  const state = {
    inBlock: false,
    processedFirstLine: false,
  };
  const result = [];

  for (let i = 0; i < lines.length; i += 1) {
    const rawLine = lines[i];
    const cleaned = stripComments(rawLine, cfg, state);
    if (!cleaned) {
      continue;
    }
    result.push({ line: i + 1, text: cleaned });
  }
  return result;
}

function commentConfig(ext) {
  switch (ext) {
    case ".cs":
    case ".ts":
    case ".tsx":
    case ".js":
      return { lineComment: "//", blockStart: "/*", blockEnd: "*/", shebang: false };
    case ".sql":
      return { lineComment: "--", blockStart: "/*", blockEnd: "*/", shebang: false };
    case ".ps1":
      return { lineComment: "#", blockStart: "<#", blockEnd: "#>", shebang: false };
    case ".sh":
      return { lineComment: "#", blockStart: null, blockEnd: null, shebang: true };
    default:
      return { lineComment: "//", blockStart: "/*", blockEnd: "*/", shebang: false };
  }
}

function stripComments(line, cfg, state) {
  if (cfg.shebang && !state.processedFirstLine) {
    state.processedFirstLine = true;
    if (line.startsWith("#!")) {
      return line.trim();
    }
  } else {
    state.processedFirstLine = true;
  }

  let working = line;

  while (true) {
    if (state.inBlock) {
      const endIdx = cfg.blockEnd ? working.indexOf(cfg.blockEnd) : -1;
      if (endIdx === -1) {
        working = "";
        break;
      }
      working = working.slice(endIdx + cfg.blockEnd.length);
      state.inBlock = false;
      continue;
    }

    if (cfg.blockStart && cfg.blockEnd) {
      const blockStartIdx = working.indexOf(cfg.blockStart);
      const lineCommentIdx = cfg.lineComment ? findLineCommentIndex(working, cfg.lineComment) : -1;
      if (blockStartIdx !== -1 && (lineCommentIdx === -1 || blockStartIdx < lineCommentIdx)) {
        const before = working.slice(0, blockStartIdx);
        const after = working.slice(blockStartIdx + cfg.blockStart.length);
        const blockEndIdx = after.indexOf(cfg.blockEnd);
        if (blockEndIdx === -1) {
          working = before;
          state.inBlock = true;
          break;
        }
        working = before + after.slice(blockEndIdx + cfg.blockEnd.length);
        continue;
      }
    }
    break;
  }

  if (cfg.lineComment) {
    const commentIdx = findLineCommentIndex(working, cfg.lineComment);
    if (commentIdx >= 0) {
      working = working.slice(0, commentIdx);
    }
  }

  return working.trim();
}

function findLineCommentIndex(line, marker) {
  if (marker === "//") {
    let idx = line.indexOf("//");
    while (idx !== -1) {
      const prev = idx > 0 ? line[idx - 1] : "";
      if (prev !== ":" && prev !== "/" && prev !== "\\") {
        return idx;
      }
      idx = line.indexOf("//", idx + 2);
    }
    return -1;
  }
  if (marker === "#") {
    if (line.startsWith("#!")) {
      return -1;
    }
    return line.indexOf("#");
  }
  return line.indexOf(marker);
}

function classifyCategory(relPath, lineText, ext) {
  const p = relPath.toLowerCase();
  const text = lineText.toLowerCase();

  if (ext === ".sql") {
    if (/create\s+(or\s+alter\s+)?procedure|\busp_[a-z0-9_]+/i.test(lineText)) {
      return "db_proc";
    }
    return "db_schema";
  }
  if (ext === ".ps1" || ext === ".sh") {
    return "infra_script";
  }
  if (ext === ".cs") {
    if (p.includes("controller")) return "backend_route";
    if (p.includes("/services/") || p.includes("service")) return "backend_service";
    return "backend_service";
  }
  if (ext === ".ts" || ext === ".tsx" || ext === ".js") {
    if (/\b(fetch|axios|apiclient|httpclient)\b|\/api\//i.test(text)) {
      return "frontend_api_call";
    }
    return "frontend_ui";
  }
  return "code";
}

function mapLine({ root, relPath, ext, lineText, category, inputs, index }) {
  const figmaRefs = [];
  const specRefs = [];
  const mappingPath = [];
  const tokens = new Set([...tokenize(relPath), ...tokenize(lineText)]);

  const addFigmaByTokens = () => {
    const refs = collectRefsFromTokenMap(index.figmaByToken, tokens, 3);
    if (refs.length) {
      figmaRefs.push(...refs);
      mappingPath.push("figma:token-match");
    }
  };
  const addSpecByTokens = () => {
    const refs = collectRefsFromTokenMap(index.specByToken, tokens, 3);
    if (refs.length) {
      specRefs.push(...refs);
      mappingPath.push("spec:token-match");
    }
  };

  switch (category) {
    case "frontend_ui": {
      addFigmaByTokens();
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specUiContract));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseC));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseD));
      mappingPath.push("category:frontend_ui");
      break;
    }
    case "frontend_api_call": {
      addFigmaByTokens();
      pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaApi));
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specOpenApi));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specApiMap));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseE));
      mappingPath.push("category:frontend_api_call");
      break;
    }
    case "backend_route": {
      addFigmaByTokens();
      pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaApi));
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specOpenApi));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specApiMap));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseD));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseE));
      if (intersectsTokenSet(tokens, index.openApiRouteTokens)) {
        mappingPath.push("rule:openapi-route-token");
      }
      mappingPath.push("category:backend_route");
      break;
    }
    case "backend_service": {
      addFigmaByTokens();
      pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaApi));
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specApiMap));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.remoteAgent));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseE));
      mappingPath.push("category:backend_service");
      break;
    }
    case "db_proc":
    case "db_schema": {
      addFigmaByTokens();
      pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaData));
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specDbPlan));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specApiMap));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseE));
      mappingPath.push(`category:${category}`);
      break;
    }
    case "infra_script": {
      addFigmaByTokens();
      pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaInfra));
      addSpecByTokens();
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specCi));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specTest));
      pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseE));
      mappingPath.push("category:infra_script");
      break;
    }
    default: {
      addFigmaByTokens();
      addSpecByTokens();
      mappingPath.push("category:code");
      break;
    }
  }

  pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseA));
  pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.phaseB));

  if (figmaRefs.length === 0) {
    pushIfPresent(figmaRefs, relativeIfPresent(root, inputs.preferredRefs.figmaFallback));
    if (figmaRefs.length) mappingPath.push("fallback:figma");
  }
  if (specRefs.length === 0) {
    pushIfPresent(specRefs, relativeIfPresent(root, inputs.preferredRefs.specFallback));
    if (specRefs.length) mappingPath.push("fallback:spec");
  }

  const normalizedFigma = uniqueArray(figmaRefs).sort();
  const normalizedSpec = uniqueArray(specRefs).sort();
  const mapped = normalizedFigma.length > 0 && normalizedSpec.length > 0;

  return {
    mapped,
    figmaRefs: normalizedFigma,
    specRefs: normalizedSpec,
    mappingPath: uniqueArray(mappingPath),
  };
}

function detectDriftTotal(root) {
  const parityPath = path.join(root, "docs", "review", "layers", "deterministic-parity-run.json");
  if (fileExists(parityPath)) {
    try {
      const json = JSON.parse(fs.readFileSync(parityPath, "utf8"));
      if (json && json.summary && Number.isFinite(json.summary.totalMismatches)) {
        return Number(json.summary.totalMismatches);
      }
    } catch {
      // ignore and fall through
    }
  }

  const summaryPath = path.join(root, "docs", "review", "EXECUTIVE-SUMMARY.md");
  if (fileExists(summaryPath)) {
    const text = safeReadText(summaryPath);
    const match = /Deterministic Drift Totals:.*TOTAL=(\d+)/.exec(text);
    if (match) {
      return Number(match[1]);
    }
  }
  return 0;
}

function countPendingRemediation(root) {
  const roadmapPath = path.join(root, ".planning", "ROADMAP.md");
  if (!fileExists(roadmapPath)) {
    return 0;
  }
  const text = safeReadText(roadmapPath);
  const matches = text.match(/^- \[ \]\s+\*\*Phase\s+\d+:/gim);
  return matches ? matches.length : 0;
}

function detectCommitSha(root) {
  const result = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status === 0) {
    return String(result.stdout || "").trim();
  }
  return "UNKNOWN";
}

function readExistingSummary(summaryPath) {
  if (!fileExists(summaryPath)) {
    return null;
  }
  try {
    const data = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
    return data && typeof data === "object" ? data : null;
  } catch {
    return null;
  }
}

function collectRefsFromTokenMap(tokenMap, tokens, limit) {
  const refs = [];
  for (const token of tokens) {
    const bucket = tokenMap.get(token);
    if (!bucket) {
      continue;
    }
    for (const ref of bucket) {
      refs.push(ref);
      if (refs.length >= limit) {
        return uniqueArray(refs);
      }
    }
  }
  return uniqueArray(refs);
}

function intersectsTokenSet(tokens, rhsSet) {
  for (const token of tokens) {
    if (rhsSet.has(token)) return true;
  }
  return false;
}

function addToTokenMap(map, token, ref) {
  if (!token || token.length < 3) {
    return;
  }
  if (!map.has(token)) {
    map.set(token, new Set());
  }
  map.get(token).add(ref);
}

function tokensFromIdentifier(name) {
  const normalized = name.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[_\-]+/g, " ");
  return tokenize(normalized);
}

function tokenize(value) {
  if (!value) return [];
  const set = new Set();
  const parts = String(value).toLowerCase().split(/[^a-z0-9]+/);
  for (const part of parts) {
    if (part.length >= 3) {
      set.add(part);
    }
  }
  return Array.from(set);
}

function listFilesRecursive(rootDir, includeFile) {
  const results = [];
  if (!dirExists(rootDir)) {
    return results;
  }
  const stack = [rootDir];
  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true }).sort((a, b) =>
      a.name.localeCompare(b.name),
    );
    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (EXCLUDED_DIRS.has(entry.name.toLowerCase())) {
          continue;
        }
        stack.push(fullPath);
      } else if (entry.isFile()) {
        if (includeFile(fullPath)) {
          results.push(fullPath);
        }
      }
    }
  }
  return results.sort((a, b) => a.localeCompare(b));
}

function stableJSONString(value) {
  return JSON.stringify(sortDeep(value));
}

function sortDeep(value) {
  if (Array.isArray(value)) {
    return value.map(sortDeep);
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort()) {
      out[key] = sortDeep(value[key]);
    }
    return out;
  }
  return value;
}

function sha256(input) {
  return crypto.createHash("sha256").update(String(input)).digest("hex");
}

function normalizeCandidateLabel(cwd, candidatePath) {
  const rel = relativeTo(cwd, candidatePath);
  return rel === "" ? "." : rel;
}

function relativeTo(base, target) {
  const rel = path.relative(base, target);
  if (!rel || rel === ".") {
    return ".";
  }
  return toPosixPath(rel);
}

function toPosixPath(value) {
  return String(value).replaceAll("\\", "/").replaceAll(path.sep, "/");
}

function safeReadText(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return "";
  }
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function fileExists(filePath) {
  try {
    return fs.statSync(filePath).isFile();
  } catch {
    return false;
  }
}

function dirExists(dirPath) {
  try {
    return fs.statSync(dirPath).isDirectory();
  } catch {
    return false;
  }
}

function uniqueArray(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function firstExisting(candidates) {
  for (const candidate of candidates) {
    if (candidate && fileExists(candidate)) {
      return candidate;
    }
  }
  return null;
}

function pushIfPresent(arr, value) {
  if (value) {
    arr.push(value);
  }
}

function relativeIfPresent(root, absPath) {
  if (!absPath || !fileExists(absPath)) {
    return null;
  }
  return relativeTo(root, absPath);
}

function resolveUserPath(cwd, userPath) {
  if (!userPath) {
    return path.resolve(cwd);
  }
  const text = String(userPath);
  const winMatch = /^([A-Za-z]):[\\/](.*)$/.exec(text);
  if (winMatch) {
    const drive = winMatch[1].toLowerCase();
    const tail = winMatch[2].replaceAll("\\", "/");
    const wslPath = `/mnt/${drive}/${tail}`;
    return path.resolve(wslPath);
  }
  if (path.isAbsolute(text)) {
    return path.resolve(text);
  }
  return path.resolve(cwd, text);
}

main();
