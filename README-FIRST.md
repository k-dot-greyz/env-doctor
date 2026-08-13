# Welcome to the Env Doctor Field Kit

Thank you for purchasing the Env Doctor Field Kit. Local environment drift is one of the single largest sinks of engineering time, and this kit is designed to eliminate that friction for you, your team, and your AI coding agents.

This kit contains everything you need to audit, standardize, and auto-heal your local development environments.

## What is in this Field Kit?

- **env-doctor.sh**: The core single-file, zero-dependency environment discovery and progressive initialization CLI tool.
- **.env-doctor.conf.example**: A fully documented configuration template to customize the checks for your specific projects.
- **QUICKSTART.md**: A step-by-step guide to get up and running in under 60 seconds.
- **SAFETY.md**: A detailed breakdown of our safety model, trust boundaries, and credential redaction rules.
- **INSTALL.md**: Direct installation instructions for local, global, or raw curl installations.
- **CHANGELOG.md**: Full version history and release notes.
- **LICENSE**: The GNU General Public License v3.0 (GPL-3.0).
- **docs/**: Full architectural designs, threat models, and UX audits.
- **templates/**: Reusable integration templates for AI agents (AGENTS.md), pre-commit hooks, and GitHub Actions.
- **examples/**: Real-world human-readable and JSON output samples generated directly from the tool.
- **support/**: Intake forms for custom environment audits and custom check requests.

## Our Trust Promise

Env Doctor is built for developers who care deeply about security, privacy, and simplicity. We operate under a strict local-first trust model:

1. **Zero Telemetry**: Env Doctor does not track, collect, or report any usage data.
2. **No Cloud Required**: All core diagnostics run entirely on your local machine.
3. **No DRM or License Servers**: No activation keys, no background phoning home, and no licensing servers.
4. **Inspectable Source**: Written in clean, pure Bash. You can read, modify, and audit every single line of code.
5. **Safe Failures**: All mutations (such as package installations or virtual environment creation) require explicit opt-in flags (--init) and user consent (--yes).

## Next Steps

To get started immediately, open **QUICKSTART.md** and run your first environment audit in under 60 seconds.

For any questions, custom integration requests, or support, please check the forms under the **support/** directory.
