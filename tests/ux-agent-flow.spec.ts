/**
 * Agent / cold-boot UX flows for env-doctor (CLI harness via Playwright).
 *
 * User stories (priority):
 * 1. Agent runs read-only discovery with machine-readable JSON before touching the repo.
 * 2. Agent on generic repo must not spam submodule init hints unless --with-submodules.
 * 3. Agent opts into submodule scan explicitly with --with-submodules.
 * 4. Agent uses dry-run init to preview tier actions without mutation.
 * 5. Agent sees dinit auth blocker when HTTPS GitHub remote is detected (human mode).
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { expect, test } from "@playwright/test";

import { runDoctorOutput } from "./pw-helpers";

const repoRoot = join(__dirname, "..");
const canonicalScript = join(repoRoot, "env-doctor.sh");
const fixturePrefix = process.env.HARNESS_FIXTURE_PREFIX ?? "env-doctor-pw";
const gitUserName = process.env.HARNESS_GIT_USER_NAME ?? "env-doctor-agent";
const gitUserEmail = process.env.HARNESS_GIT_USER_EMAIL ?? "agent@users.noreply.github.com";
const githubHttpsRemote =
  process.env.HARNESS_GITHUB_HTTPS_REMOTE ?? "https://github.com/example/acme.git";
const nextCmd = process.env.HARNESS_NEXT_CMD ?? "dinit auth";

function runDoctor(cwd: string, args: string[], env: NodeJS.ProcessEnv = {}) {
  return runDoctorOutput(join(cwd, "env-doctor.sh"), args, cwd, env);
}

function seedRepo(name: string, setup: (dir: string) => void): string {
  const dir = mkdtempSync(join(tmpdir(), `${fixturePrefix}-${name}-`));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(canonicalScript));
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", gitUserEmail], { cwd: dir });
  execFileSync("git", ["config", "user.name", gitUserName], { cwd: dir });
  setup(dir);
  execFileSync("git", ["add", "-A"], { cwd: dir });
  execFileSync("git", ["commit", "-q", "-m", "seed"], { cwd: dir });
  return dir;
}

test.describe("agent cold-boot flows", () => {
  test("US-1: JSON discovery is parseable and reports ok/issues", () => {
    const dir = seedRepo("json", () => {});
    try {
      const out = runDoctor(dir, ["--json", "-q"]);
      const body = JSON.parse(out) as {
        ok: boolean;
        issues: number;
        warnings: number;
        results: unknown[];
      };
      expect(Array.isArray(body.results)).toBe(true);
      expect(typeof body.ok).toBe("boolean");
      expect(body.issues).toBeGreaterThanOrEqual(0);
      expect(body.warnings).toBeGreaterThanOrEqual(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("US-2: generic repo skips submodule scan unless opted in", () => {
    const dir = seedRepo("generic", () => {});
    try {
      const out = runDoctor(dir, ["--json", "-q"]);
      expect(out).toContain("scan skipped");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("US-3: --with-submodules runs submodule scan", () => {
    const dir = seedRepo("submodules", (root) => {
      mkdirSync(join(root, "vendor", "demo"), { recursive: true });
      writeFileSync(
        join(root, ".gitmodules"),
        `[submodule "vendor/demo"]\n\tpath = vendor/demo\n\turl = https://github.com/example/demo.git\n`,
      );
    });
    try {
      const out = runDoctor(dir, ["--with-submodules", "--json", "-q"]);
      expect(out).not.toContain("scan skipped");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("US-4: dry-run init advertises planned actions only", () => {
    const dir = seedRepo("dry", (root) => {
      writeFileSync(join(root, "pyproject.toml"), "[project]\n");
    });
    try {
      const out = runDoctor(dir, ["-it0n"]);
      expect(out.toLowerCase()).toContain("dry-run");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("US-5: HTTPS GitHub origin surfaces dinit auth blocker in human mode", () => {
    const dir = seedRepo("https-auth", (root) => {
      execFileSync("git", ["remote", "add", "origin", githubHttpsRemote], { cwd: root });
    });
    try {
      const out = runDoctor(dir, []);
      expect(out).toContain("blocker:");
      expect(out).toContain(nextCmd);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
