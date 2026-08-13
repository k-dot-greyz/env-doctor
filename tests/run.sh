#!/usr/bin/env bash
# tests/run.sh — Dependency-free test suite for env-doctor.
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/smoke.sh"
bash "$SCRIPT_DIR/security.sh"
