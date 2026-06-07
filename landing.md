# env-doctor: The Ultimate Environment Audit & Progressive Init Tool

Stop wasting engineering hours debugging broken local developer environments. **env-doctor** is a lightweight, single-file Bash script that audits, validates, and progressively initializes local developer environments for any git repository.

Built in strict compliance with the **GlitchWorks Agnostic Architecture Protocol (GW-AAP)**, `env-doctor` is fast, secure, and 100% config-driven.

---

## Why env-doctor?

- **Zero Dependencies**: Pure Bash/Zsh. Runs instantly on macOS, Linux, and WSL.
- **Strictly Typed JSON Pipe**: Emits versioned JSON records (`--json`), making it perfect for CI/CD pipelines, pre-commit hooks, and AI coding agents.
- **Hardened Boundary Security**: Automatically redacts sensitive tokens, API keys, and credentials from git URLs, and rewrites local file paths (`$HOME` -> `~`) to protect developer privacy.
- **Progressive Initialization**: Don't just find problems—fix them. Supports tiered progressive setup (virtual environments, submodules, dev tools, and Docker compose).
- **Graceful Degradation**: Built-in command timeouts and safe fallbacks ensure the script never hangs or panics.

---

## Buy the Premium Bundle

`env-doctor` is open-source under the **GPL-3.0 License**. You can view, modify, and distribute the code freely.

**So why buy the Premium Bundle?**

When you purchase `env-doctor`, you are buying **convenience, trust, premium documentation, and professional support**:

1. **Vetted Release Zip**: Access to signed, production-ready releases with verified SHA256 checksums.
2. **The Setup Playbook**: A comprehensive, step-by-step guide (`docs/PLAYBOOK.md`) to embedding `env-doctor` into team workflows, pre-commit hooks, native Git hooks, CI/CD pipelines (GitHub Actions, GitLab CI), and AI coding agent environments.
3. **Enterprise Security & Architecture**: Full access to our Threat Model (`docs/THREAT_MODEL.md`) and GW-AAP Architecture Spec (`docs/ARCHITECTURE.md`) to satisfy compliance and security teams.
4. **Priority Support**: Direct access to the core maintainers for custom check development and integration troubleshooting.
5. **Lifetime Updates**: Get notified of new checks, security patches, and features first.

### Pricing
- **Single Developer License**: $19 (Vetted zip + Setup Playbook)
- **Team License (Up to 10 devs)**: $99 (Vetted zip + Setup Playbook + Priority Email Support)
- **Enterprise License**: $299 (Vetted zip + Setup Playbook + Custom Check Development + 1-on-1 Integration Call)

[👉 Buy Now on Gumroad / Lemon Squeezy]
[👉 Support the project on GitHub Sponsors]
