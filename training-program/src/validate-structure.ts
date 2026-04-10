/**
 * validate-structure.ts
 *
 * Walks the training-program/ directory tree and checks structural completeness:
 * - All 10 module directories exist and contain required files
 * - All 5 POC directories exist and contain required files
 * - reference/ and interview-prep/ directories exist
 * - schedule.md exists
 *
 * Usage:
 *   npx ts-node src/validate-structure.ts
 *   # or from training-program/:
 *   npx ts-node src/validate-structure.ts
 */

import * as fs from "fs";
import * as path from "path";

// ─── Configuration ────────────────────────────────────────────────────────────

/** Resolve paths relative to the training-program/ root */
const PROGRAM_ROOT = path.resolve(__dirname, "..");

const REQUIRED_MODULE_FILES = [
  "theory.md",
  "problem-statements.md",
  "interview-prep.md",
  "assessment.md",
];

const REQUIRED_POC_FILES = [
  "README.md",
  "validate.sh",
];

const MODULE_DIRS = [
  "01-azure-app-service",
  "02-azure-sql-containers",
  "03-auth-apim",
  "04-devops-fundamentals",
  "05-cicd-pipelines",
  "06-release-strategies",
  "07-terraform-basics",
  "08-terraform-advanced",
  "09-azure-infra-terraform",
  "10-security-compliance",
];

const POC_DIRS = [
  "poc1-app-sql-networking",
  "poc2-ci-pipeline-compute",
  "poc3-cicd-slots-aks",
  "poc4-security-governance",
  "poc5-3tier-gitops-capstone",
];

const TOP_LEVEL_REQUIRED = [
  "schedule.md",
  "reference",
  "interview-prep",
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

interface ValidationResult {
  passed: boolean;
  errors: string[];
  warnings: string[];
}

function checkExists(filePath: string): boolean {
  return fs.existsSync(filePath);
}

function checkFileNonEmpty(filePath: string): boolean {
  if (!checkExists(filePath)) return false;
  const stat = fs.statSync(filePath);
  if (stat.isDirectory()) return true; // directories are "non-empty" by existence
  return stat.size > 0;
}

// ─── Validators ───────────────────────────────────────────────────────────────

function validateModules(result: ValidationResult): void {
  const modulesRoot = path.join(PROGRAM_ROOT, "modules");

  if (!checkExists(modulesRoot)) {
    result.errors.push(`Missing directory: modules/`);
    return;
  }

  for (const moduleDir of MODULE_DIRS) {
    const modulePath = path.join(modulesRoot, moduleDir);

    if (!checkExists(modulePath)) {
      result.errors.push(`Missing module directory: modules/${moduleDir}/`);
      continue;
    }

    for (const requiredFile of REQUIRED_MODULE_FILES) {
      const filePath = path.join(modulePath, requiredFile);
      if (!checkExists(filePath)) {
        result.warnings.push(
          `Missing file (not yet created): modules/${moduleDir}/${requiredFile}`
        );
      } else if (!checkFileNonEmpty(filePath)) {
        result.warnings.push(
          `Empty file: modules/${moduleDir}/${requiredFile}`
        );
      }
    }
  }
}

function validatePOCs(result: ValidationResult): void {
  const pocsRoot = path.join(PROGRAM_ROOT, "pocs");

  if (!checkExists(pocsRoot)) {
    result.errors.push(`Missing directory: pocs/`);
    return;
  }

  for (const pocDir of POC_DIRS) {
    const pocPath = path.join(pocsRoot, pocDir);

    if (!checkExists(pocPath)) {
      result.errors.push(`Missing POC directory: pocs/${pocDir}/`);
      continue;
    }

    for (const requiredFile of REQUIRED_POC_FILES) {
      const filePath = path.join(pocPath, requiredFile);
      if (!checkExists(filePath)) {
        result.warnings.push(
          `Missing file (not yet created): pocs/${pocDir}/${requiredFile}`
        );
      } else if (!checkFileNonEmpty(filePath)) {
        result.warnings.push(`Empty file: pocs/${pocDir}/${requiredFile}`);
      }
    }
  }
}

function validateTopLevel(result: ValidationResult): void {
  for (const item of TOP_LEVEL_REQUIRED) {
    const itemPath = path.join(PROGRAM_ROOT, item);
    if (!checkExists(itemPath)) {
      // schedule.md is a file; reference/ and interview-prep/ are dirs
      if (item.endsWith(".md")) {
        result.warnings.push(`Missing file (not yet created): ${item}`);
      } else {
        result.errors.push(`Missing directory: ${item}/`);
      }
    }
  }
}

function validateSrcFiles(result: ValidationResult): void {
  const srcRoot = path.join(PROGRAM_ROOT, "src");
  const requiredSrcFiles = ["types.ts", "validate-structure.ts"];

  if (!checkExists(srcRoot)) {
    result.errors.push(`Missing directory: src/`);
    return;
  }

  for (const file of requiredSrcFiles) {
    const filePath = path.join(srcRoot, file);
    if (!checkExists(filePath)) {
      result.errors.push(`Missing src file: src/${file}`);
    }
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

function validate(): void {
  console.log("=".repeat(60));
  console.log("Training Program Structure Validator");
  console.log(`Root: ${PROGRAM_ROOT}`);
  console.log("=".repeat(60));

  const result: ValidationResult = {
    passed: true,
    errors: [],
    warnings: [],
  };

  validateSrcFiles(result);
  validateTopLevel(result);
  validateModules(result);
  validatePOCs(result);

  // ── Report ──────────────────────────────────────────────────────────────────

  if (result.warnings.length > 0) {
    console.log("\n⚠  Warnings (content not yet created — expected during scaffolding):");
    for (const w of result.warnings) {
      console.log(`   • ${w}`);
    }
  }

  if (result.errors.length > 0) {
    console.log("\n✗  Errors (structural problems that must be fixed):");
    for (const e of result.errors) {
      console.log(`   • ${e}`);
    }
    result.passed = false;
  }

  console.log("\n" + "─".repeat(60));

  if (result.passed && result.errors.length === 0) {
    console.log(
      `✓  Structure validation PASSED  (${result.warnings.length} warning(s))`
    );
  } else {
    console.log(
      `✗  Structure validation FAILED  (${result.errors.length} error(s), ${result.warnings.length} warning(s))`
    );
    process.exit(1);
  }
}

validate();
