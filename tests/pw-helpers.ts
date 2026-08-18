/**
 * Shared Playwright harness helpers — mirrors tests/helpers.sh python3.14 stub.
 */
import { chmodSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

let python314StubDir: string | null = null;

/** Prepends a python3.14 stub (reports 3.14.0) so hosts with only 3.12 pass the 3.14 floor. */
export function doctorProcessEnv(extra: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  if (!python314StubDir) {
    python314StubDir = mkdtempSync(join(tmpdir(), "env-doctor-py314-stub-"));
    const stubPath = join(python314StubDir, "python3.14");
    writeFileSync(
      stubPath,
      `#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
  echo "Python 3.14.0"
  exit 0
fi
if [[ "\${1:-}" == "-m" && "\${2:-}" == "venv" ]]; then
  rm -rf "\${@:3}" 2>/dev/null || true
  if python3 -m venv "\${@:3}" 2>/dev/null; then
    exit 0
  fi
  rm -rf "\${@:3}" 2>/dev/null || true
  if command -v virtualenv &>/dev/null; then
    virtualenv "\${@:3}" --quiet 2>/dev/null
    exit $?
  fi
  exit 1
fi
exec python3 "$@"
`,
    );
    chmodSync(stubPath, 0o755);
  }
  return {
    ...process.env,
    PATH: `${python314StubDir}:${process.env.PATH ?? ""}`,
    ...extra,
  };
}
