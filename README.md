# env-doctor

Bash **environment discovery** and optional **progressive init** for any git repository. Zero extra dependencies for the read-only pass.

Designed and implemented in accordance with the **GlitchWorks Agnostic Architecture Protocol (GW-AAP)**. It operates as a pure, decoupled data pipeline with a strictly typed JSON output seam, dynamic configuration injection, and graceful degradation.

Canonical implementation: `env-doctor.sh` in this repository.

## Quick Start

```bash
git clone https://github.com/greyz/env-doctor.git
cd env-doctor
bash env-doctor.sh --help
```

Optional repo-local config: **`.env-doctor.conf`** in the target repository root (see `docs/README.md` in this repo for variables).

## Architecture (GW-AAP Compliance)

This tool is built on the core tenets of the GlitchWorks Agnostic Architecture Protocol:

1. **Zero Hardcoding**: All site-specific heuristics and paths are stripped from the domain logic. Everything is driven by injected configuration.
2. **Polymorphism by Default**: Checks are driven dynamically. Optional checks are toggled and configured via `.env-doctor.conf`.
3. **Open Piping**: Features a strictly typed JSON output mode (`--json`) that emits a versioned, structured stream of environment records.
4. **Boundary Validation**: Sourced configuration files and git outputs are validated and scrubbed. Embedded credentials (tokens, user/passwords) in git URLs are automatically redacted to protect the edge.
5. **Graceful Degradation**: Every external call (git, docker, package managers) is wrapped with timeouts and safe fallbacks to prevent runtime hangs or crashes.
6. **Agnostic Telemetry**: Output emitters (`_pass`, `_warn`, `_fail`, `_info`) are decoupled from the display interface, allowing seamless routing to either human-readable console output or machine-readable JSON pipes.

## Documentation

- [`docs/README.md`](docs/README.md) — flags, config, quickstart
- [`docs/PLAYBOOK.md`](docs/PLAYBOOK.md) — Git hooks, CI/CD, and AI-agent integration playbook
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — phases, JSON schema, design
- [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) — threat model, trust boundaries, mitigations
- [`docs/UX_AUDIT.md`](docs/UX_AUDIT.md) — reusability notes

## License

Licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [`LICENSE`](LICENSE) for details.
