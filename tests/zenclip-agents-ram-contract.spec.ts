/**
 * Playwright contract for agents_ram/zenclip-bug-forensics (merged PR #41).
 *
 * US-AR1: Blueprint markdown links resolve within repo (agent cold-boot DX).
 * US-AR2: Sample bugcard has no literal secret-shaped substrings (forum egress).
 * US-AR3: TRUST_TOUCHPOINTS implementation gates reference executable tests.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

import { expect, test } from "@playwright/test";

const repoRoot = join(__dirname, "..");
const zenclipRoot = join(repoRoot, "agents_ram", "zenclip-bug-forensics");
const validator = join(repoRoot, "tests", "zenclip", "lib", "validate_bugcard.py");
const sampleCard = join(zenclipRoot, "examples", "sample-bugcard.json");

const SECRET_LIKE = [
  /ghp_[A-Za-z0-9]{20,}/,
  /github_pat_[A-Za-z0-9_]{20,}/,
  /sk_live_[A-Za-z0-9]{10,}/,
];

const linkRe = /\]\(([^)]+)\)/g;

function resolveMarkdownLinks(mdPath: string): string[] {
  const text = readFileSync(mdPath, "utf8");
  const dir = dirname(mdPath);
  const broken: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = linkRe.exec(text)) !== null) {
    const target = m[1].trim();
    if (
      target.startsWith("http://") ||
      target.startsWith("https://") ||
      target.startsWith("#") ||
      target.startsWith("mailto:")
    ) {
      continue;
    }
    const normalized = target.replace(/^\.\//, "");
    const abs = join(dir, normalized.split("#")[0]);
    if (!existsSync(abs)) {
      broken.push(`${target} (from ${mdPath})`);
    }
  }
  return broken;
}

test.describe("agents_ram zenclip blueprint contracts", () => {
  test("US-AR1: zenclip README and ARCHITECTURE relative links resolve", () => {
    const files = [
      join(zenclipRoot, "README.md"),
      join(zenclipRoot, "ARCHITECTURE.md"),
      join(zenclipRoot, "TRUST_TOUCHPOINTS.md"),
    ];
    const allBroken = files.flatMap(resolveMarkdownLinks);
    expect(allBroken, `broken links: ${allBroken.join("; ")}`).toEqual([]);
  });

  test("US-AR2: sample bugcard passes validator + export policy", () => {
    const out = execFileSync("python3", [validator, sampleCard, "--policy"], {
      encoding: "utf8",
    });
    expect(out.trim()).toContain("OK");
    const raw = readFileSync(sampleCard, "utf8");
    for (const pat of SECRET_LIKE) {
      expect(raw).not.toMatch(pat);
    }
  });

  test("US-AR3: TRUST_TOUCHPOINTS gates cite zenclip test artifacts", () => {
    const trust = readFileSync(join(zenclipRoot, "TRUST_TOUCHPOINTS.md"), "utf8");
    expect(trust).toContain("tests/zenclip/redact-secrets.sh");
    expect(trust).toMatch(/G5|env-doctor projection/);
  });
});
