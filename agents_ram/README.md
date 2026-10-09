# agents_ram — local agent context store

Ephemeral-to-durable notes, blueprints, and SOWs that agents and humans use **without** bloating the main product docs. Not shipped as part of the env-doctor runtime; versioned in git for continuity across sessions.

## Conventions

| Rule | Rationale |
|------|-----------|
| One folder per initiative | `agents_ram/<slug>/` with `README.md` as the entry |
| GW-AAP alignment | Typed envelopes, boundary redaction, idempotent exports — same spirit as [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) |
| Link outward | Product truth stays in `docs/`; agents_ram holds **plans and scaffolds** until code lands |
| Issue traceability | Each initiative README lists motivating issues (GitHub, forum, internal) |

## Active initiatives

| Slug | Summary | Status |
|------|---------|--------|
| [`zenclip-bug-forensics`](zenclip-bug-forensics/README.md) | Keybind → idempotent bug card JSON + infograph PNG; zenClip forensics + hydration vectors | Blueprint / SOW |

## Search

```bash
rg -n "zenclip|agents_ram" agents_ram docs
```
