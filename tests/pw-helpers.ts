/**
 * Playwright CLI harness helpers — mirror bash run_doctor (isolated git config, non-throwing exit).
 */
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export type DoctorRun = {
  stdout: string;
  stderr: string;
  status: number | null;
};

export function runDoctorScript(
  scriptPath: string,
  args: string[],
  cwd: string,
  env: NodeJS.ProcessEnv = {},
): DoctorRun {
  const cfgDir = mkdtempSync(join(tmpdir(), "env-doctor-git-config-"));
  const cfgFile = join(cfgDir, "config");
  writeFileSync(cfgFile, "");
  try {
    const result = spawnSync("bash", [scriptPath, ...args], {
      cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        ...env,
        GIT_CONFIG_GLOBAL: cfgFile,
        GIT_CONFIG_SYSTEM: "/dev/null",
      },
    });
    return {
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
      status: result.status,
    };
  } finally {
    rmSync(cfgDir, { recursive: true, force: true });
  }
}

/** Combined stdout+stderr (env-doctor mixes human output across both). */
export function runDoctorOutput(
  scriptPath: string,
  args: string[],
  cwd: string,
  env?: NodeJS.ProcessEnv,
): string {
  const { stdout, stderr } = runDoctorScript(scriptPath, args, cwd, env);
  return stdout + stderr;
}
