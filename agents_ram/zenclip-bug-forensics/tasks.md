# zenClip bug forensics — Statement of Work (implementation tasks)

**Initiative:** `agents_ram/zenclip-bug-forensics`  
**Motivating issue:** Cursor IDE — GitHub PR/issue label UI / shortcuts (forum bug; use as acceptance scenario)  
**Blueprint:** [WHITEPAPER.md](WHITEPAPER.md) · [ARCHITECTURE.md](ARCHITECTURE.md)

**Branch naming (when coding):** `greyzxcursor/zenclip-<phase>-8fc4`

---

## Phase 0 — Decisions and scaffold (blocking)

| ID | Task | Done | Notes |
|----|------|------|-------|
| 0.1 | **ADR-001:** Choose MVP runtime (bash+jq vs Node) | [ ] | Default: bash+jq + jq for canonical JSON; Node only for render if needed |
| 0.2 | Create `zenclip/` tree per ARCHITECTURE §5 | [ ] | README, `bin/zenclip`, `lib/`, `schemas/` |
| 0.3 | Copy/link `zenclip-bugcard-1.schema.json` into `zenclip/schemas/` | [ ] | Single source: agents_ram copy until package split |
| 0.4 | Add `zenclip --help` and version stub | [ ] | `ZENCLIP_VERSION=0.1.0` |
| 0.5 | Document privacy warning in `zenclip/README.md` | [ ] | Screenshots may contain secrets |
| 0.6 | First-run consent + `~/.zenclip` `0700` store policy | [ ] | TRUST_TOUCHPOINTS §4.1–4.2 |

**Exit criteria:** Empty CLI runs; schema validates against fixture `{}` with documented required fields.

---

## Phase 1 — Core pipe (idempotent card, no PNG)

| ID | Task | Done | Notes |
|----|------|------|-------|
| 1.1 | Implement `lib/redact.sh` (git URL tokens, `ghp_`, home path truncation) | [ ] | Align with env-doctor `_redact_git_url` behavior |
| 1.2 | Implement P0 vectors: `host.os`, `git.workspace` | [ ] | No network |
| 1.3 | Implement `lib/canonicalize.jq` → `identity_core` | [ ] | Stable key ordering |
| 1.4 | Implement `report_id` = `zc_` + base32url(sha256)[0:22] | [ ] | Document in WHITEPAPER |
| 1.5 | Implement `zenclip compile` → `zenclip-bugcard.json` | [ ] | Schema `zenclip-bugcard/1` |
| 1.6 | Idempotent merge: same `report_id` bumps `revision` | [ ] | Test fixture |
| 1.7 | Emit `exports/forum_post.md` from `templates/forum_cursor.md.tmpl` | [ ] | Maps forum bot template fields |
| 1.8 | Tests: `tests/zenclip/compile-idempotency.sh` | [ ] | Use `tests/helpers.sh` pattern |
| 1.9 | Tests: `tests/zenclip/redact-secrets.sh` | [ ] | Hostile URL fixtures |
| 1.10 | env-doctor snapshot **off by default**; projection allowlist if enabled | [ ] | TRUST_TOUCHPOINTS §4.6 |
| 1.11 | Forum template footer: "Before you post" | [ ] | TRUST_TOUCHPOINTS §7 |

**Exit criteria:** `zenclip compile --fixture tests/zenclip/fixtures/labels-ui.bundle.json` produces stable `report_id` across two runs.

---

## Phase 2 — Hydration orchestrator (P1 vectors)

| ID | Task | Done | Notes |
|----|------|------|-------|
| 2.1 | `zenclip hydrate` with per-vector timeout and `vectors_failed[]` | [ ] | `max_parallel=6` |
| 2.2 | Vector `github.auth` (sanitized `gh auth status`) | [ ] | Graceful if `gh` missing |
| 2.3 | Vector `github.labels_api` (`gh pr view` / `gh issue view` JSON) | [ ] | Powers label matrix |
| 2.4 | Vector `env.doctor_snapshot` | [ ] | `bash env-doctor.sh --json -q` when present |
| 2.5 | Bug-class preset `github.labels_ui` | [ ] | Auto title suggestion |
| 2.6 | Record cap + overflow artifact blobs with sha256 | [ ] | ARCHITECTURE §7 policy |
| 2.7 | Tests: `tests/zenclip/vector-github-auth.sh` with stubbed `gh` | [ ] | GIT_CONFIG_GLOBAL isolation |
| 2.8 | Fixture: full label-bug hydrated bundle | [ ] | For compile regression |

**Exit criteria:** Hydrated bundle includes pass/fail rows for UI vs API matrix when `gh` stub returns labels.

---

## Phase 3 — Capture + snap (CLI hot path)

| ID | Task | Done | Notes |
|----|------|------|-------|
| 3.1 | `zenclip capture` — P0 to `capture.bundle.json` | [ ] | screenshot optional flag `--no-screen` |
| 3.2 | Screenshot downscale (ImageMagick or `ffmpeg` — detect tool) | [ ] | Max width 1280 |
| 3.3 | `zenclip snap` = capture + hydrate + compile + print paths | [ ] | Single command |
| 3.4 | Store layout under `~/.zenclip/reports/<report_id>/` | [ ] | ARCHITECTURE §4.3 |
| 3.5 | Clipboard export (Linux: `wl-copy` / `xclip` detection) | [ ] | Best-effort |
| 3.6 | **ADR-003:** PNG `tEXt` embed minimal card | [ ] | Optional; skip if >64KB |
| 3.7 | Clipboard: forum markdown only (paths in toast) | [ ] | TRUST_TOUCHPOINTS §4.4 |
| 3.8 | Delete transient bundle by default; `--keep-bundle` | [ ] | TRUST_TOUCHPOINTS §4.2 |
| 3.9 | Implement ship gates G1–G6 in TRUST_TOUCHPOINTS §5 | [ ] | Block release until pass |

**Exit criteria:** `zenclip snap --class github.labels_ui` on dev machine produces card + forum md in &lt;5s (P1 best-effort).

---

## Phase 4 — Infograph renderer

| ID | Task | Done | Notes |
|----|------|------|-------|
| 4.1 | HTML template per WHITEPAPER §6 wireframe | [ ] | `zenclip/render/template.html` |
| 4.2 | `zenclip-render` via Playwright (reuse `playwright.config.ts`) | [ ] | ADR-002 |
| 4.3 | Wire `zenclip compile --png` to renderer | [ ] | Output `zenclip-bugcard.png` |
| 4.4 | Visual regression: snapshot test on fixture card | [ ] | Tolerate font variance |
| 4.5 | Label matrix icons ✅❌➖ from hydration records | [ ] | Reference scenario |

**Exit criteria:** PNG readable at 100% zoom; `report_id` in header matches JSON.

---

## Phase 5 — IDE integration (optional v1)

| ID | Task | Done | Notes |
|----|------|------|-------|
| 5.1 | Spike: VS Code extension command calling `zenclip snap` | [ ] | Separate repo OK |
| 5.2 | Vectors `cursor.*`, `logs.*` via extension API | [ ] | Requires extension |
| 5.3 | Default keybind documentation only in env-doctor repo | [ ] | Until extension ships |
| 5.4 | Submit **reference bug report** using zenClip output for label UI issue | [ ] | Dogfood |

**Exit criteria:** One real forum post generated by tool (user submits).

---

## Phase 6 — Hardening and docs

| ID | Task | Done | Notes |
|----|------|------|-------|
| 6.1 | Promote TRUST_TOUCHPOINTS → `zenclip/docs/THREAT_MODEL.md` at code ship | [ ] | Extend with code-specific vectors |
| 6.2 | CI job: run `tests/zenclip/*.sh` | [ ] | Add to `.github/workflows/ci.yml` |
| 6.3 | Link from `docs/FOLLOW_UPS.md` or `docs/README.md` | [ ] | agents_ram pointer |
| 6.4 | CHANGELOG entry when `zenclip/` CLI ships | [ ] | |
| 6.5 | Close loop: json `next_cmd` pattern from env-doctor #27 | [ ] | Optional `zenclip` envelope field |

---

## Dependencies graph (suggested order)

```text
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
                └──────────────┴──────────────┘
                      (2 can parallel 1.8 fixtures)
```

---

## Acceptance test — label UI scenario

Manual/automated checklist for the motivating bug:

1. Open PR in Cursor GitHub view with label UI broken.
2. Run `zenclip snap --class github.labels_ui --note "cannot create label from UI"`.
3. Card contains:
   - [ ] `bug_class` = `github.labels_ui`
   - [ ] `cursor.build` or explicit “unavailable” in `vectors_failed`
   - [ ] `github.labels_api` pass when `gh` works
   - [ ] `forum_post.md` with Steps / Expected / Actual sections filled
   - [ ] PNG shows label matrix row
4. Paste forum markdown to clipboard without hand-editing version block.

---

## Out of scope (explicit)

- Salesforce API integration
- Automatic Cursor forum POST
- Windows/macOS screenshot parity before Linux MVP (track as follow-up issues)

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| 0.1.0 | 2026-10-08 | Initial SOW in agents_ram |
