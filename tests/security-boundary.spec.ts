/**
 * Security-focused scenarios: untrusted .env-doctor.conf, argv injection, credentials.
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { expect, test } from "@playwright/test";

import { runDoctorOutput, runDoctorScript } from "./pw-helpers";

const repoRoot = join(__dirname, "..");
const canonicalScript = join(repoRoot, "env-doctor.sh");
const fixturePrefix = process.env.HARNESS_FIXTURE_PREFIX ?? "env-doctor-sec";
const markerBasename = process.env.HARNESS_MARKER_BASENAME ?? "HACKED_FILE";
const gitUserName = process.env.HARNESS_GIT_USER_NAME ?? "sec-test";
const gitUserEmail = process.env.HARNESS_GIT_USER_EMAIL ?? "sec@users.noreply.github.com";

function runDoctorIn(cwd: string, args: string[]) {
  return runDoctorOutput(join(cwd, "env-doctor.sh"), args, cwd);
}

function fixtureWithConf(conf: string, extra?: (dir: string) => void): string {
  const dir = mkdtempSync(join(tmpdir(), `${fixturePrefix}-`));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(canonicalScript));
  writeFileSync(join(dir, ".env-doctor.conf"), conf);
  writeFileSync(join(dir, "pyproject.toml"), "[project]\n");
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", gitUserEmail], { cwd: dir });
  execFileSync("git", ["config", "user.name", gitUserName], { cwd: dir });
  extra?.(dir);
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", "sec"], { cwd: dir });
  return dir;
}

test("rejects shell metacharacters in ENV_DOCTOR_PYTHON_DEPS", () => {
  const dir = fixtureWithConf("ENV_DOCTOR_PYTHON_DEPS='os;evil'");
  try {
    const out = runDoctorIn(dir, ["--json", "-q"]);
    expect(out).toContain("unsafe characters");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects invalid Python import names in ENV_DOCTOR_PYTHON_DEPS", () => {
  const dir = fixtureWithConf("ENV_DOCTOR_PYTHON_DEPS='os,123evil'");
  try {
    const out = runDoctorIn(dir, ["--json", "-q"]);
    expect(out).toContain("invalid import name");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("blocks malicious config commands in safe-parse mode", () => {
  const dir = fixtureWithConf(`BRAND=safe\ntouch ${markerBasename}`);
  try {
    runDoctorIn(dir, ["--quiet"]);
    expect(existsSync(join(dir, markerBasename))).toBe(false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("flags mock credentials in .env (agent must not treat as production-ready)", () => {
  const dir = mkdtempSync(join(tmpdir(), `${fixturePrefix}-mock-env-`));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(canonicalScript));
  writeFileSync(join(dir, ".env"), "API_KEY=mock-key\n");
  writeFileSync(join(dir, "env.example"), "API_KEY=\n");
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", gitUserEmail], { cwd: dir });
  execFileSync("git", ["config", "user.name", gitUserName], { cwd: dir });
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", "env"], { cwd: dir });
  try {
    const out = runDoctorIn(dir, ["--json", "-q"]);
    expect(out.toLowerCase()).toContain("placeholder");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects --brand argv injection", () => {
  const dir = fixtureWithConf("");
  try {
    const { status } = runDoctorScript(join(dir, "env-doctor.sh"), ["--brand", "evil;rm"], dir);
    expect(status).not.toBe(0);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
