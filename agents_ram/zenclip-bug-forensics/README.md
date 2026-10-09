# zenClip bug forensics harness

**Track:** Motivated by Cursor IDE GitHub PR/issue **label UI** gaps (cannot create/apply labels reliably from UI; shortcuts inconsistent). Generalized into a reusable **bug-report automation** stack.

## Documents

| Doc | Purpose |
|-----|---------|
| [WHITEPAPER.md](WHITEPAPER.md) | Problem, goals, 80/20 capture ladder, idempotency, multimodal infograph |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, hydration vectors, schemas, threat boundaries, repo scaffold |
| [tasks.md](tasks.md) | Statement of work — phased implementation checklist |
| [TRUST_TOUCHPOINTS.md](TRUST_TOUCHPOINTS.md) | Trust touchpoint audit (consent, egress, gates) |
| [schemas/zenclip-bugcard-1.schema.json](schemas/zenclip-bugcard-1.schema.json) | Draft JSON Schema for the bug card companion |
| [examples/sample-bugcard.json](examples/sample-bugcard.json) | Illustrative card (not a live capture) |

## Relationship to env-doctor

- **env-doctor** = environment truth (phases, `env-doctor/1` JSON).
- **zenClip** = incident truth (`zenclip-bugcard/1` JSON) at the moment of failure.
- Optional vector `env.doctor_snapshot` invokes env-doctor read-only during P1 hydration.

## Agent quickstart

1. Read WHITEPAPER §3 (80/20) before implementing collectors.
2. Implement against ARCHITECTURE §5 scaffold paths.
3. Execute work from `tasks.md` in phase order; do not skip redaction/tests in Phase 1.
