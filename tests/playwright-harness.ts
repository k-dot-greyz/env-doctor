/**
 * Playwright harness — constructor-injected paths and Python 3.14 floor stub.
 * Mirrors tests/helpers.sh _setup_test_python314 for CI hosts without native 3.14.
 */
import { chmodSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = join(__dirname, "..");
const canonicalScript = join(repoRoot, "env-doctor.sh");

let pythonStubDir: string | null = null;
let defaultGitConfigPath: string | null = null;

export const harnessDefaults = {
  fixturePrefix: process.env.HARNESS_FIXTURE_PREFIX ?? "env-doctor-pw",
  gitUserName: process.env.HARNESS_GIT_USER_NAME ?? "env-doctor-agent",
  gitUserEmail: process.env.HARNESS_GIT_USER_EMAIL ?? "agent@users.noreply.github.com",
  markerBasename: process.env.HARNESS_MARKER_BASENAME ?? "HACKED_FILE",
  nextCmd: process.env.HARNESS_NEXT_CMD ?? "dinit auth",
  githubHttpsRemote:
    process.env.HARNESS_GITHUB_HTTPS_REMOTE ?? "https://github.com/example/acme.git",
};

function ensurePython314Stub(): string {
  if (pythonStubDir) {
    return pythonStubDir;
  }
  pythonStubDir = mkdtempSync(join(tmpdir(), "env-doctor-py314-stub-"));
  const stubPath = join(pythonStubDir, "python3.14");
  writeFileSync(
    stubPath,
    [
      "#!/usr/bin/env bash",
      'if [[ "${1:-}" == "--version" ]]; then',
      '  echo "Python 3.14.0"',
      "  exit 0",
      "fi",
      'if [[ "${1:-}" == "-m" && "${2:-}" == "venv" ]]; then',
      '  rm -rf "${@:3}" 2>/dev/null || true',
      '  if python3 -m venv "${@:3}" 2>/dev/null; then',
      "    exit 0",
      "  fi",
      "  exit 1",
      "fi",
      'exec python3 "$@"',
      "",
    ].join("\n"),
  );
  chmodSync(stubPath, 0o755);
  return pythonStubDir;
}

function isolatedGitConfig(): string {
  if (process.env.HARNESS_GIT_CONFIG_GLOBAL) {
    return process.env.HARNESS_GIT_CONFIG_GLOBAL;
  }
  if (!defaultGitConfigPath) {
    const dir = mkdtempSync(join(tmpdir(), "env-doctor-git-config-"));
    defaultGitConfigPath = join(dir, "config");
    writeFileSync(defaultGitConfigPath, "");
  }
  return defaultGitConfigPath;
}

export function harnessEnv(extra: Record<string, string> = {}): NodeJS.ProcessEnv {
  const stubDir = ensurePython314Stub();
  return {
    ...process.env,
    PATH: `${stubDir}:${process.env.PATH ?? ""}`,
    GIT_CONFIG_GLOBAL: isolatedGitConfig(),
    GIT_CONFIG_SYSTEM: "/dev/null",
    ...extra,
  };
}

export type DoctorRun = {
  stdout: string;
  stderr: string;
  code: number | null;
};

export function runDoctor(
  cwd: string,
  args: string[],
  env: Record<string, string> = {},
): DoctorRun {
  const script = join(cwd, "env-doctor.sh");
  const result = spawnSync("bash", [script, ...args], {
    cwd,
    encoding: "utf8",
    env: harnessEnv(env),
  });
  return {
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
    code: result.status,
  };
}

export function runCanonicalDoctor(args: string[], env: Record<string, string> = {}): DoctorRun {
  const result = spawnSync("bash", [canonicalScript, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    env: harnessEnv(env),
  });
  return {
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
    code: result.status,
  };
}
