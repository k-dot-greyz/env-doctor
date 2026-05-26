/**
 * Security-focused scenarios: untrusted .env-doctor.conf and credential surfaces.
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { expect, test } from "@playwright/test";

const CANONICAL_SCRIPT = join(__dirname, "..", "env-doctor.sh");

function runDoctorIn(cwd: string, args: string[]) {
  return execFileSync("bash", [join(cwd, "env-doctor.sh"), ...args], {
    cwd,
    encoding: "utf8",
  });
}

function fixtureWithConf(conf: string): string {
  const dir = mkdtempSync(join(tmpdir(), "env-doctor-sec-"));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(CANONICAL_SCRIPT));
  writeFileSync(join(dir, ".env-doctor.conf"), conf);
  writeFileSync(join(dir, "pyproject.toml"), "[project]\n");
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", "sec@users.noreply.github.com"], {
    cwd: dir,
  });
  execFileSync("git", ["config", "user.name", "sec-test"], { cwd: dir });
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", "sec"], { cwd: dir });
  return dir;
}

test("rejects shell metacharacters in ENV_DOCTOR_PYTHON_DEPS import names", () => {
  const dir = fixtureWithConf("ENV_DOCTOR_PYTHON_DEPS='os;evil'");
  try {
    const out = runDoctorIn(dir, ["--json", "-q"]);
    expect(out).toContain("invalid import name");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("flags mock credentials in .env (agent must not treat as production-ready)", () => {
  const dir = mkdtempSync(join(tmpdir(), "env-doctor-mock-env-"));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(CANONICAL_SCRIPT));
  writeFileSync(join(dir, ".env"), "API_KEY=mock-key\n");
  writeFileSync(join(dir, "env.example"), "API_KEY=\n");
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", "sec@users.noreply.github.com"], {
    cwd: dir,
  });
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", "env"], { cwd: dir });
  try {
    const out = runDoctorIn(dir, ["--json", "-q"]);
    expect(out.toLowerCase()).toContain("placeholder");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
