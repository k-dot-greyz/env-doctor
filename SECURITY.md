# Security Policy

Vulnerability reporting for **env-doctor**.

## Supported Versions

Security fixes land on the default branch (currently `main`).

## Threat Model

For a comprehensive analysis of trust boundaries, threat vectors, and mitigations implemented in `env-doctor`, please refer to our [Threat Model](docs/THREAT_MODEL.md).

## Reporting a Vulnerability

**Do not** open a public issue for undisclosed security problems (credentials, sensitive data exposure, or supply-chain issues in code or workflows maintained here).

Please report any security vulnerabilities by contacting the maintainers directly or opening a private security advisory on GitHub.

### What to Include

- Short description and impact.
- Steps to reproduce or a proof-of-concept.
- Affected areas (paths, workflows, tags).

We will coordinate disclosure when we can; there is no guaranteed response-time SLA.

## Scope

- **In Scope:** This repository's own code, configuration, and GitHub Actions.
- **Out of Scope:** Third-party packages and upstream projects — use their reporting channels.

## Good Faith

Security research is welcome when lawful and non-destructive. See [LICENSE](./LICENSE).
