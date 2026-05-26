/**
 * Agent / cold-boot UX flows for env-doctor (CLI harness via Playwright).
 *
 * User stories (priority):
 * 1. Agent runs read-only discovery with machine-readable JSON before touching the repo.
 * 2. Agent on generic repo must not spam submodule init hints unless --with-submodules.
 * 3. Agent on dev-master-shaped tree gets submodule scan by default.
 * 4. Agent uses dry-run init to preview tier actions without mutation.
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { expect, test } from "@playwright/test";

const CANONICAL_SCRIPT = join(__dirname, "..", "env-doctor.sh");

function runDoctor(cwd: string, args: string[], env: NodeJS.ProcessEnv = {}) {
  const script = join(cwd, "env-doctor.sh");
  return execFileSync("bash", [script, ...args], {
    cwd,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

function seedRepo(name: string, setup: (dir: string) => void): string {
  const dir = mkdtempSync(join(tmpdir(), `env-doctor-pw-${name}-`));
  writeFileSync(join(dir, "env-doctor.sh"), readFileSync(CANONICAL_SCRIPT));
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["config", "user.email", "agent@users.noreply.github.com"], {
    cwd: dir,
  });
  execFileSync("git", ["config", "user.name", "env-doctor-agent"], { cwd: dir });
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

  test("US-3: dev-master-shaped repo enables submodule scan by default", () => {
    const dir = seedRepo("devmaster", (root) => {
      mkdirSync(join(root, "dex", "09-repos", "demo"), { recursive: true });
      writeFileSync(
        join(root, ".gitmodules"),
        `[submodule "dex/09-repos/demo"]\n\tpath = dex/09-repos/demo\n\turl = https://github.com/example/demo.git\n`,
      );
    });
    try {
      const out = runDoctor(dir, ["--json", "-q"]);
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
});
