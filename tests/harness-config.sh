#!/usr/bin/env bash
# tests/harness-config.sh — Configurable harness constructor (no hardcoded runtime values).
# Override any HARNESS_* variable before sourcing to customize a test run.

_harness_script_dir() {
  cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd
}

init_harness() {
  local script_dir
  script_dir="$(_harness_script_dir)"

  HARNESS_REPO_ROOT="${HARNESS_REPO_ROOT:-$(cd "${script_dir}/.." && pwd)}"
  HARNESS_SCRIPT="${HARNESS_SCRIPT:-${HARNESS_REPO_ROOT}/env-doctor.sh}"
  HARNESS_FIXTURE_PREFIX="${HARNESS_FIXTURE_PREFIX:-env-doctor}"
  HARNESS_GIT_USER_NAME="${HARNESS_GIT_USER_NAME:-env-doctor-test}"
  HARNESS_GIT_USER_EMAIL="${HARNESS_GIT_USER_EMAIL:-test@users.noreply.github.com}"
  HARNESS_MARKER_BASENAME="${HARNESS_MARKER_BASENAME:-HACKED_FILE}"
  HARNESS_REDACT_TOKEN="${HARNESS_REDACT_TOKEN:-ghp_1234567890abcdefghijklmnopqrstuv}"
  HARNESS_REDACT_GLPAT="${HARNESS_REDACT_GLPAT:-glpat-abcdefghijklmnopqrst}"
  HARNESS_EXPECTED_VERSION="${HARNESS_EXPECTED_VERSION:-}"

  if [[ -z "$HARNESS_EXPECTED_VERSION" && -f "$HARNESS_SCRIPT" ]]; then
    HARNESS_EXPECTED_VERSION="$(
      grep -m1 '^ENV_DOCTOR_VERSION=' "$HARNESS_SCRIPT" | cut -d'"' -f2
    )"
  fi

  export HARNESS_REPO_ROOT HARNESS_SCRIPT HARNESS_FIXTURE_PREFIX
  export HARNESS_GIT_USER_NAME HARNESS_GIT_USER_EMAIL HARNESS_MARKER_BASENAME
  export HARNESS_REDACT_TOKEN HARNESS_REDACT_GLPAT HARNESS_EXPECTED_VERSION
}
