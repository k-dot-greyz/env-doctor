# zenClip Bug Forensics — Whitepaper (draft)

**Version:** 0.1.0  
**Status:** Blueprint — implementation per [tasks.md](tasks.md)  
**Schema:** `zenclip-bugcard/1` (WIP)

---

## 1. Executive summary

Support and engineering teams lose time when bug reports lack **repro context**, **version fingerprints**, and **ground-truth checks** (e.g. “does the GitHub API work while the UI does not?”). Users lose time when reporting requires many manual fields and unreliable shortcuts.

**zenClip** is a forensics-first capture layer: one keybind (or CLI) produces:

1. An **idempotent JSON bug card** — canonical, redacted, machine-ingestible.
2. A **companion infograph PNG** — human-glance multimodal summary; optional embedded card chunk (WIP).
3. **Forum-ready markdown** — aligned with Cursor’s public bug template and [reporting guidance](https://cursor.com/help/troubleshooting/reporting-bugs).

Design principle: **80/20 on the hot path** — sync only what triage needs in under ~500ms; everything else is parallel, time-boxed, or async.

---

## 2. Problem statement

### 2.1 Motivating incident (Cursor × GitHub labels)

Users cannot reliably **create or apply labels** on PRs/issues from Cursor’s GitHub UI. Keyboard shortcuts are inconsistent. Workarounds (github.com, `gh` CLI) work, which suggests **integration/UI** failure rather than auth — but reporters rarely include that matrix, so issues bounce for clarification.

### 2.2 General class

Any **visual integration bug** in the IDE shares the same failure mode:

- High friction to report.
- Low signal (no Request ID, no console tail, no API vs UI comparison).
- Duplicate forum posts from repeated keybind panic clicks.

zenClip targets this class first; the label bug is the **reference scenario** for acceptance tests.

---

## 3. Goals and non-goals

### 3.1 Goals

| ID | Goal |
|----|------|
| G1 | **One action** from user to “good enough” report (clipboard + on-disk bundle). |
| G2 | **Idempotent** `report_id` for the same incident; updates merge by revision. |
| G3 | **Typed hydration** via named vectors with timeouts and partial success. |
| G4 | **Redaction by default** — no tokens, credentials, or home paths in card or PNG. |
| G5 | **GW-AAP-compatible** envelopes — same record types as env-doctor where possible. |
| G6 | **Multimodal export** — JSON + PNG + markdown from one compile pass. |

### 3.2 Non-goals (v0)

- Replacing Cursor’s in-app bug reporter or Salesforce intake.
- Continuous background telemetry or session recording.
- Automatic forum posting (user pastes or attaches).
- Full video capture (P2 optional only).

---

## 4. The 80/20 capture ladder

### P0 — synchronous (≤ ~500ms)

Must complete before the user sees “Captured”:

- Trigger metadata (command id, timestamp UTC).
- UI focus hint (editor URI, panel id if available).
- Cursor/OS fingerprint (About block or subset).
- Git workspace slice: root, branch, short SHA, dirty count.
- Last *N* user commands (bounded list, not full telemetry).
- Primary screenshot (downscaled).
- Optional single-line user note (Enter to skip).

### P1 — parallel (≤ ~3s total, per-vector timeouts)

Best-effort; failures recorded in `hydration.vectors_failed`:

- Request ID / agent bc-id when surface is chat/agent.
- DevTools console **errors only** (tail).
- Output channels: GitHub, GitHub Pull Request, Log (Window) — filtered tails.
- GitHub auth host + login boolean (sanitized).
- Entity context: PR/issue id when derivable.
- **Ground truth:** labels via `gh` API when available.
- Optional `env-doctor.sh --json -q` when run inside a repo.

### P2 — async / on demand

Full logs, HAR, extension dumps, screen recording. Linked by `artifact_ref`; never blocks P0.

---

## 5. Idempotent bug card

### 5.1 Identity

`report_id` is derived from a **canonical hash** of stable fields (`identity_core`), excluding volatile bytes (screenshot, timestamps):

```
report_id = "zc_" + base32url( SHA-256( canonical_json( identity_core ) ) )[0:22]
```

Repeated capture with the same core facts **updates** `revision` and merges new vectors; it does not fork a new id.

**Pseudonymity:** Optional `--anonymous` salts `identity_core` so repeat captures do not merge and `report_id` does not fingerprint the same repo/issue on a public forum. See [TRUST_TOUCHPOINTS.md](TRUST_TOUCHPOINTS.md) §4.3.

### 5.2 Single source of truth

The **JSON card** is authoritative. The PNG is a **rendered view**. Forum markdown is a **projection**. Embedded PNG metadata chunk (WIP) is a convenience transport, not a second schema.

### 5.3 Record model

Hydration results use env-doctor-compatible rows:

`section` | `pass` | `warn` | `fail` | `info` | `status`

This allows one harness to consume both `env-doctor/1` and `zenclip-bugcard/1` streams in CI or agent tooling.

---

## 6. Infograph PNG (multimodal context dump)

**Purpose:** Let a human triage in &lt;10s without opening JSON.

**Layout (v0 wireframe):**

```
┌─────────────────────────────────────────────────────────────┐
│ TITLE · severity · report_id · UTC                          │
├──────────────┬─────────────────────┬────────────────────────┤
│ Repro 1-3    │ Screenshot          │ Build / OS / Git         │
│ (commands)   │ (primary)           │ Request ID / privacy     │
├──────────────┴─────────────────────┴────────────────────────┤
│ Signal matrix (e.g. UI vs github.com vs gh)                 │
├─────────────────────────────────────────────────────────────┤
│ Footer: short hash · optional QR to bundle path               │
└─────────────────────────────────────────────────────────────┘
```

**WIP:** PNG `tEXt` / `zTXt` chunk `zenclip:card` holding gzip+base64 of minimal card subset (≤64KB). Full card remains in sidecar JSON.

---

## 7. Signal vs noise policy

1. **Filter at source** — log tails: errors/warnings only; allowlisted substrings per vector.
2. **Cap rows** — max ~30 records per vector; overflow → artifact blob + SHA-256.
3. **Deduplicate** — identical stack lines collapsed with count.
4. **Explicit gaps** — `null` + `vectors_failed` beats silent omission.
5. **Two-channel output** — machines read `records[]`; humans read markdown/PNG.

---

## 8. Threat and privacy

Treat host IDE state, log tails, and screenshots as **sensitive**. Apply redaction **before** hashing `identity_core` for share-safe ids.

| Data | Policy |
|------|--------|
| Tokens in URLs/logs | Strip (reuse env-doctor URL redaction patterns) |
| `.env` values | Never collect |
| Full chat content | Never in v0; Request ID only |
| Screenshots | May contain secrets — user warning on first use; optional blur regions (future) |

See ARCHITECTURE §6 and [TRUST_TOUCHPOINTS.md](TRUST_TOUCHPOINTS.md) for trust boundaries, consent touchpoints, and ship gates.

---

## 9. Success metrics (v1)

| Metric | Target |
|--------|--------|
| P0 latency (p95) | &lt; 500ms on dev laptop |
| User steps to forum-ready paste | 1 keybind + optional one-liner |
| Triage questions avoided | “version?” “repro?” “API works?” pre-filled |
| Duplicate forum threads | Same `report_id` within 24h detectable |

---

## 10. References

- env-doctor GW-AAP: [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md), [`CONTRIBUTING.md`](../../CONTRIBUTING.md) §2.5 State Hydration
- Cursor bug template: forum Bug Reports category; [Reporting a bug](https://cursor.com/help/troubleshooting/reporting-bugs)
- Prior art in conversation: forum JSON bundle + label UX matrix annex

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| 0.1.0 | 2026-10-08 | Initial whitepaper in agents_ram |
