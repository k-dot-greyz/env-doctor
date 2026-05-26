# Test coverage decision log — env-doctor (2026-05-26)

## Target repo

`k-dot-greyz/env-doctor` (`dex/09-repos/env-doctor` in dev-master). Prior automation run covered `perplexity-batch-exporter`; this run rotates to env-doctor per automation memory.

## Attack surface (scoped)

| Surface | Risk | Coverage |
|---------|------|----------|
| `.env-doctor.conf` sourced at bootstrap | Arbitrary shell if attacker controls repo | Documented trust model; tests use benign `BRAND` only |
| `ENV_DOCTOR_PYTHON_DEPS` → `python -c import …` | Command injection via malicious conf | **Fix:** allow only `[a-zA-Z_][a-zA-Z0-9_]*`; tests assert rejection |
| `--init` / submodule update | Unintended clone or network | Dry-run `-it0n` test; generic profile skips submodule scan |
| MCP `~/.cursor/mcp.json` grep | False positives / missed placeholders | Test with isolated `HOME` + `CHANGE_ME` pattern |
| `.env` vs `env.example` | Leaked mock keys in “ready” env | Test warns on `mock-key` |
| Profile auto-detect | Wrong tier/init hints for agents | JSON tests for generic vs dev-master-shaped trees |

**Deferred (not isolated in this PR):** full `git submodule update` network behavior, LM Studio HTTP calls, `gh auth` — environment-dependent; documented as manual/CI optional.

## Tests added

| File | Role |
|------|------|
| `tests/run.sh` | Deterministic bash integration harness (fixtures via temp git repos) |
| `tests/helpers.sh` | Fixture factory + assertions |
| `tests/ux-agent-flow.spec.ts` | Playwright CLI harness — agent cold-boot user stories |
| `tests/security-config.spec.ts` | Playwright — conf injection + mock `.env` |
| `package.json` / `playwright.config.ts` | `npm test` = bash + Playwright |

## Impact vs cost

- **Impact:** High for agents and CI — env-doctor is the first command in `AGENTS.md` cold boot; JSON/submodule/profile mistakes waste agent tokens or trigger unsafe init.
- **Cost:** Low — tests use temp dirs, no network; runtime ~10–20s with Playwright install on first run.
- **Speed:** Bash suite alone is sufficient for PR gates; Playwright adds duplicate coverage of UX stories with better story documentation.

## Validation

```bash
cd dex/09-repos/env-doctor
bash tests/run.sh
npm install && npm test
```

## Follow-ups

- CI workflow in env-doctor repo on push (bash-only job for fork-friendly runs).
- JSON escaping audit (`_jline` / `printf`) — tracked in UX_AUDIT.md.
- Sync submodule pointer in dev-master after merge to env-doctor `main`.
