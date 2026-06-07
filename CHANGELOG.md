# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-08

### Added
- Enterprise-grade safe configuration loading (`_load_config`) replacing `source` with a line-by-line KEY=value allowlist parser.
- Added `--unsafe-source-config` opt-in flag for dynamic shell logic configs, strictly guarded by ownership and permission checks.
- Added `--yes` / `-y` flag to gate mutating Tier 2 package installations behind explicit user consent.
- Added robust `ERR` and `EXIT` trap handling (`_error_trap`) to guarantee a clean typed error message or valid JSON envelope on unexpected failure.
- Extended secret redaction to cover GitLab `glpat-` tokens, generic `ssh://user:pass@` URLs, `x-oauth-basic`, and any generic `://user:pass@` schemes.
- Hardened JSON output with a control character escaping helper (`_escape_json_string`) to prevent JSON envelope breakage.
- Added comprehensive, dependency-free test suite (`tests/run.sh`) covering security boundaries, redactions, JSON validity, and exit codes.
- Added `.github/workflows/ci.yml` CI pipeline running shellcheck and the test suite on Ubuntu and macOS.
- Added detailed threat model documentation (`docs/THREAT_MODEL.md`).

### Changed
- Removed all `eval` statements from the codebase, invoking tools directly with explicit version-arg arrays.
- Validated all CLI arguments at the boundary (e.g. `--tier` must be an integer 0-3, `--brand` length/charset caps).

## [1.0.0] - 2026-06-08

### Added
- Strictly typed JSON output mode (`--json` / `-j`) conforming to the `env-doctor/1` schema.
- Automatic credential and token redaction from git remote URLs to prevent security leaks.
- Home directory path rewriting (`$HOME` -> `~`) in output records to protect user privacy.
- Dynamic configuration injection via `.env-doctor.conf` (with `.env-doctor.conf.example` template).
- Version flag (`--version` / `-v`).
- Graceful degradation with command timeouts and safe fallbacks for external dependencies.
- Detailed architecture and design documentation under the **GlitchWorks Agnostic Architecture Protocol (GW-AAP)**.

### Changed
- Refactored the core script to be 100% generic, stripping all proprietary heuristics, hardcoded paths, and site-specific knowledge.
- Submodule scan is now off by default for fast, CI-friendly runs (opt-in with `--with-submodules`).
- Simplified submodule classification to core vs other submodules.

### Removed
- Removed all site-specific profile auto-detection and custom profile overrides.
- Removed hardcoded local AI stack checks (LM Studio, `lms` CLI, and custom tasks).
