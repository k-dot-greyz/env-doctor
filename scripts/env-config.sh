#!/usr/bin/env bash
# env-config.sh — Install login/boot hooks for env-doctor read-only audit.
# Licensed under GPL-3.0 — (c) 2026 greyZ
#
# Usage:
#   ENV_DOCTOR_REPO=/path/to/repo bash scripts/env-config.sh install
#   bash scripts/env-config.sh uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${ENV_DOCTOR_REPO:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_DOCTOR="${REPO_ROOT}/env-doctor.sh"
PROFILE_MARKER_START="# >>> env-doctor boot audit >>>"
PROFILE_MARKER_END="# <<< env-doctor boot audit <<<"
SYSTEMD_UNIT="${HOME}/.config/systemd/user/env-doctor-audit.service"
AUDIT_THROTTLE_SECS=86400

_usage() {
  cat <<EOF
Usage: ENV_DOCTOR_REPO=/path/to/repo bash scripts/env-config.sh <install|uninstall>
EOF
}

_install_profile_snippet() {
  local target block installed=false
  block="${PROFILE_MARKER_START}
# Read-only env-doctor audit (throttled to once per day; no mutations)
if [[ -x \"${ENV_DOCTOR}\" ]]; then
  _ed_stamp=\"\${XDG_CACHE_HOME:-\$HOME/.cache}/env-doctor/last-boot-audit\"
  _ed_now=\$(date +%s 2>/dev/null || echo 0)
  _ed_last=0
  [[ -f \"\$_ed_stamp\" ]] && _ed_last=\$(cat \"\$_ed_stamp\" 2>/dev/null || echo 0)
  if (( _ed_now - _ed_last > ${AUDIT_THROTTLE_SECS} )); then
    mkdir -p \"\$(dirname \"\$_ed_stamp\")\" 2>/dev/null || true
    \"${ENV_DOCTOR}\" --json --quiet >/dev/null 2>&1 || true
    date +%s >\"\$_ed_stamp\" 2>/dev/null || true
  fi
fi
${PROFILE_MARKER_END}"
  for target in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$target" ]] || continue
    if grep -qF "$PROFILE_MARKER_START" "$target" 2>/dev/null; then
      echo "  boot audit already in $(basename "$target")"
      installed=true
      continue
    fi
    printf '\n%s\n' "$block" >>"$target"
    echo "  installed boot audit in $(basename "$target")"
    installed=true
  done
  if [[ "$installed" == false ]]; then
    target="$HOME/.bashrc"
    touch "$target"
    printf '\n%s\n' "$block" >>"$target"
    echo "  installed boot audit in $(basename "$target") (created)"
    installed=true
  fi
  [[ "$installed" == true ]]
}

_uninstall_profile_snippet() {
  local target tmp
  for target in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$target" ]] || continue
    if ! grep -qF "$PROFILE_MARKER_START" "$target" 2>/dev/null; then
      continue
    fi
    tmp="$(mktemp)"
    awk -v start="$PROFILE_MARKER_START" -v end="$PROFILE_MARKER_END" '
      $0 == start { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$target" >"$tmp"
    cat "$tmp" >"$target"
    rm -f "$tmp"
    echo "  removed boot audit from $(basename "$target")"
  done
}

_install_systemd_unit() {
  command -v systemctl &>/dev/null || return 0
  mkdir -p "$(dirname "$SYSTEMD_UNIT")"
  cat >"$SYSTEMD_UNIT" <<EOF
[Unit]
Description=env-doctor read-only environment audit
After=default.target

[Service]
Type=oneshot
# Audit exit code 1 means checks failed (expected); 0 means all passed.
ExecStart=${ENV_DOCTOR} --json --quiet
SuccessExitStatus=0 1
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable env-doctor-audit.service 2>/dev/null || true
  echo "  installed systemd user unit: env-doctor-audit.service"
}

_uninstall_systemd_unit() {
  command -v systemctl &>/dev/null || return 0
  [[ -f "$SYSTEMD_UNIT" ]] || return 0
  systemctl --user disable env-doctor-audit.service 2>/dev/null || true
  rm -f "$SYSTEMD_UNIT"
  systemctl --user daemon-reload 2>/dev/null || true
  echo "  removed systemd user unit"
}

cmd="${1:-}"
case "$cmd" in
  install)
    [[ -x "$ENV_DOCTOR" ]] || { echo "env-doctor.sh not found at $ENV_DOCTOR" >&2; exit 1; }
    _install_profile_snippet
    _install_systemd_unit
    ;;
  uninstall)
    _uninstall_profile_snippet
    _uninstall_systemd_unit
    ;;
  *)
    _usage
    exit 1
    ;;
esac
