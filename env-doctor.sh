#!/usr/bin/env bash
# env-doctor.sh — Environment discovery and progressive init for any git repo.
# Extra heuristics (submodules, dex paths, Agent RAM) activate in dev-master / zenOS-style trees
# via .env-doctor.conf or auto-detected profile. Targets: VSCode, Linux (bash), macOS (zsh), WSL.
# Zero external deps on discovery pass (pure bash/zsh) except optional python3 for LM Studio model counts.
#
# ToC:
#   Phase 1  Shell & OS Discovery (phase1_shell_os)
#   Phase 2  Tooling Discovery (phase2_tooling)
#   Phase 3  Git & Submodule Discovery (phase3_git)
#   Phase 4  Credentials & Config (phase4_creds)
#   Phase 5  Progressive Init (phase5_init) — only with --init
#   Summary  (summary)
#
# Usage:
#   bash env-doctor.sh                    # discovery (submodules skipped unless profile=dev-master)
#   bash env-doctor.sh --with-submodules # include submodule scan + private URL warnings
#   bash env-doctor.sh --init             # progressive init (tier 1)
#   See --help for full options.

set -euo pipefail

_ENV_DOCTOR_SCRIPT="${BASH_SOURCE[0]}"

# ── globals (REPO_ROOT set in _bootstrap_env after argv) ─────────────────────
REPO_ROOT=""
DO_INIT=false
INIT_TIER=1
DRY_RUN=false
OUTPUT_JSON=false
QUIET=false
SUBMODULES_ONLY=false
USER_SUBMODULE_CHOICE=""
PROFILE_OVERRIDE=""
BRAND_OVERRIDE=""
PROFILE=""
WITH_SUBMODULES=false
PROJECT_TYPES=()
BRAND="${BRAND:-}"
ENV_DOCTOR_CORE_REPOS="${ENV_DOCTOR_CORE_REPOS:-}"
ENV_DOCTOR_PYTHON_DEPS="${ENV_DOCTOR_PYTHON_DEPS:-}"
ENV_DOCTOR_SHOW_AGENT_RAM="${ENV_DOCTOR_SHOW_AGENT_RAM:-}"
ENV_DOCTOR_HELP_URL="${ENV_DOCTOR_HELP_URL:-}"
ISSUES=0
WARNINGS=0
JSON_LINES=()
DOCTOR_NAME="env-doctor"

# ── colors (disabled if not tty or --json/--quiet) ───────────────────────────
_setup_colors() {
  if [[ -t 1 ]] && [[ "$OUTPUT_JSON" == false ]] && [[ "$QUIET" == false ]]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'
    DIM=$'\033[2m'; BOLD=$'\033[1m'; RST=$'\033[0m'
  else
    R=''; G=''; Y=''; B=''; DIM=''; BOLD=''; RST=''
  fi
}

# ── output helpers ───────────────────────────────────────────────────────────
_jline() {
  local type=$1 k=$2 v=$3
  printf '{"type":"%s","key":"%s","value":"%s"}\n' "$type" "$(printf '%s' "$k" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}
_pass()  {
  if [[ "$OUTPUT_JSON" == "true" ]]; then JSON_LINES+=("$(_jline "pass" "$1" "$2")"); return; fi
  [[ "$QUIET" == "true" ]] && return; printf "  ${G}[PASS]${RST}  %-28s %s\n" "$1" "$2";
}
_warn()  {
  WARNINGS=$((WARNINGS+1))
  if [[ "$OUTPUT_JSON" == "true" ]]; then JSON_LINES+=("$(_jline "warn" "$1" "$2")"); return; fi
  [[ "$QUIET" == "true" ]] && return; printf "  ${Y}[WARN]${RST}  %-28s %s\n" "$1" "$2";
}
_fail()  {
  ISSUES=$((ISSUES+1))
  if [[ "$OUTPUT_JSON" == "true" ]]; then JSON_LINES+=("$(_jline "fail" "$1" "$2")"); return; fi
  [[ "$QUIET" == "true" ]] && return; printf "  ${R}[FAIL]${RST}  %-28s %s\n" "$1" "$2";
}
_info()  {
  if [[ "$OUTPUT_JSON" == "true" ]]; then JSON_LINES+=("$(_jline "info" "$1" "$2")"); return; fi
  [[ "$QUIET" == "true" ]] && return; printf "  ${DIM}[info]${RST}  %-28s %s\n" "$1" "$2";
}
_head()  {
  if [[ "$OUTPUT_JSON" == "true" ]]; then JSON_LINES+=("$(_jline "section" "$1" "")"); return; fi
  [[ "$QUIET" == "true" ]] && return; printf "\n${BOLD}${B}── %s ──${RST}\n" "$1";
}

# Run with timeout when GNU coreutils timeout exists (stock macOS often lacks it).
_timeout_cmd() {
  local sec=$1
  shift
  if command -v timeout &>/dev/null; then
    timeout "$sec" "$@"
  else
    "$@"
  fi
}

# Value field from git config --get-regexp output (KEY<TAB>VALUE or KEY VALUE).
_git_config_regexp_value() {
  local line="$1"
  if [[ "$line" == *$'\t'* ]]; then
    printf '%s' "${line#*$'\t'}"
  else
    printf '%s' "$line" | sed 's/^[^[:space:]]*[[:space:]]\{1,\}//'
  fi
}

# Submodule path from one line of git submodule status (paths may contain spaces).
# Portable: avoid GNU sed -E character classes (BSD sed rejects ranges like \-+ in []).
_submodule_status_path_from_line() {
  local line="$1"
  [[ -z "$line" ]] && return
  line="${line:1}"
  while [[ "$line" == [[:space:]]* ]]; do
    line="${line:1}"
  done
  [[ -z "$line" ]] && return
  local sha="${line%% *}"
  line="${line#"$sha"}"
  while [[ "$line" == [[:space:]]* ]]; do
    line="${line:1}"
  done
  [[ -z "$line" ]] && return
  printf '%s' "$line" | sed 's/ ([^)]*)$//'
}

# ═════════════════════════════════════════════════════════════════════════════
# Helper: Private Submodule Detection
# ═════════════════════════════════════════════════════════════════════════════
_check_private_submodules() {
  cd "$REPO_ROOT" 2>/dev/null || return 0

  local private_submodules=()
  local ssh_works=false

  # URLs that look intentionally non-public (avoid flagging every personal GitHub org)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local url
    url="$(_git_config_regexp_value "$line")"

    if echo "$url" | grep -qiE '(/private/|/internal/|@private\.|[.]private\.)'; then
      private_submodules+=("$url")
    fi
  done < <(git config -f .gitmodules --get-regexp 'submodule\..*\.url' 2>/dev/null || true)

  if [[ ${#private_submodules[@]} -eq 0 ]]; then
    _pass "Private submodules" "none detected"
    return
  fi

  # GitHub SSH prints success on stderr and exits 1 — detect auth from output, not exit code.
  if ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 \
      | grep -q "successfully authenticated"; then
    ssh_works=true
  fi

  local ssh_info="(SSH key setup required)"
  [[ "$ssh_works" == "true" ]] && ssh_info="(SSH key detected - may work)"

  _warn "Private submodules" "${#private_submodules[@]} detected $ssh_info"
  for sub in "${private_submodules[@]}"; do
    _info "  Private repo" "$sub"
  done

  # Provide guidance
  if [[ "$ssh_works" != "true" ]]; then
    if [[ -n "$ENV_DOCTOR_HELP_URL" ]]; then
      _info "Suggested fix" "Setup SSH key for GitHub (ssh-keygen -t ed25519; add public key to GitHub) or use a credential helper — $ENV_DOCTOR_HELP_URL"
    else
      _info "Suggested fix" "Setup SSH key for GitHub (ssh-keygen -t ed25519; add public key to GitHub) or use HTTPS with a token/credential helper"
    fi
  fi
}

# Resolve repo root: prefer git (works when script is copied anywhere), then legacy layout, then cwd.
_resolve_repo_root() {
  local sd
  sd="$(cd "$(dirname "$_ENV_DOCTOR_SCRIPT")" && pwd)"
  if REPO_ROOT="$(git -C "$sd" rev-parse --show-toplevel 2>/dev/null)"; then return; fi
  if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then return; fi
  if [[ -d "$sd/../.." ]]; then
    REPO_ROOT="$(cd "$sd/../.." && pwd)"
  else
    REPO_ROOT="$(pwd)"
  fi
}

_detect_profile() {
  if [[ -n "${PROFILE_OVERRIDE:-}" ]]; then
    PROFILE="$PROFILE_OVERRIDE"
    return
  fi
  if [[ -f "$REPO_ROOT/.gitmodules" ]] \
     && [[ -d "$REPO_ROOT/dex" ]] \
     && grep -q "dex/09-repos" "$REPO_ROOT/.gitmodules" 2>/dev/null; then
    PROFILE="dev-master"
  else
    PROFILE="generic"
  fi
}

_bootstrap_env() {
  _resolve_repo_root
  if [[ -f "$REPO_ROOT/.env-doctor.conf" ]]; then
    # shellcheck disable=SC1090
    source "$REPO_ROOT/.env-doctor.conf"
  fi
  DOCTOR_NAME="$(basename "$_ENV_DOCTOR_SCRIPT")"
  [[ -n "${BRAND_OVERRIDE:-}" ]] && BRAND="$BRAND_OVERRIDE"
  _detect_profile
  if [[ "$USER_SUBMODULE_CHOICE" == with ]]; then
    WITH_SUBMODULES=true
  elif [[ "$USER_SUBMODULE_CHOICE" == skip ]]; then
    WITH_SUBMODULES=false
  elif [[ "$PROFILE" == dev-master ]]; then
    WITH_SUBMODULES=true
  else
    WITH_SUBMODULES=false
  fi
}

# ── arg parsing ──────────────────────────────────────────────────────────────
# Expand combined short flags: -it2 → -i -t 2, -iqt0 → -i -q -t 0, etc.
_expand_args=()
for _arg in "$@"; do
  if [[ "$_arg" =~ ^-[a-zA-Z] && ! "$_arg" =~ ^-- ]]; then
    _rest="${_arg#-}"
    while [[ -n "$_rest" ]]; do
      _ch="${_rest:0:1}"
      _rest="${_rest:1}"
      case "$_ch" in
        t) # -t consumes only leading digits as its value (e.g. -t2, -it2, -it2n)
           if [[ "$_rest" =~ ^([0-9]+)(.*) ]]; then
             _expand_args+=("-t" "${BASH_REMATCH[1]}")
             _rest="${BASH_REMATCH[2]}"
           else
             _expand_args+=("-t")
           fi ;;
        *) _expand_args+=("-$_ch") ;;
      esac
    done
  else
    _expand_args+=("$_arg")
  fi
done
# With set -u, "${empty[@]}" can error on some Bash; guard zero-arg invocations.
if [[ ${#_expand_args[@]} -eq 0 ]]; then
  set --
else
  set -- "${_expand_args[@]}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init|-i)      DO_INIT=true; shift ;;
    --tier|-t)      INIT_TIER="${2:?--tier/-t requires a number 0-3}"; shift 2 ;;
    --dry-run|-n)   DRY_RUN=true; shift ;;
    --json|-j)      OUTPUT_JSON=true; shift ;;
    --quiet|-q)     QUIET=true; shift ;;
    --submodules)   SUBMODULES_ONLY=true; shift ;;
    --with-submodules)  USER_SUBMODULE_CHOICE=with; shift ;;
    --skip-submodules)  USER_SUBMODULE_CHOICE=skip; shift ;;
    --profile)      PROFILE_OVERRIDE="${2:?--profile requires dev-master or generic}"; shift 2 ;;
    --brand)        BRAND_OVERRIDE="${2:?--brand requires a string}"; shift 2 ;;
    --help|-h)
      cat <<'EOF'
env-doctor — Environment discovery & progressive init

Usage:
  bash env-doctor.sh              # discovery (read-only)
  bash env-doctor.sh --with-submodules   # include submodule scan (default off in generic repos)
  bash env-doctor.sh --skip-submodules   # force skip even in dev-master-style trees
  bash env-doctor.sh -i           # init tier 1
  bash env-doctor.sh -it0         # init tier 0 (venv + core deps only)
  bash env-doctor.sh -it2         # init tier 2 (full tooling + all submodules when enabled)
  bash env-doctor.sh -it3         # init tier 3 (+ Docker services)
  bash env-doctor.sh -it2n        # tier 2 dry-run
  bash env-doctor.sh -j           # JSON for CI/agents
  bash env-doctor.sh -q           # exit code only
  bash env-doctor.sh --submodules # private submodule URL check only (SSH hint)
  bash env-doctor.sh --profile generic
  bash env-doctor.sh --brand myrepo

Optional repo config (sourced if present): .env-doctor.conf in repo root
  BRAND, ENV_DOCTOR_CORE_REPOS, ENV_DOCTOR_PYTHON_DEPS, ENV_DOCTOR_SHOW_AGENT_RAM, ENV_DOCTOR_HELP_URL

Long forms:
  --init, --tier N, --dry-run, --json, --quiet, --submodules,
  --with-submodules, --skip-submodules, --profile, --brand, --help

Short flags:
  -i  init          -t N  tier (0-3)     -n  dry-run
  -j  json output   -q  quiet            -h  help

Combined:  -it2 = --init --tier 2    -iqt0 = --init --quiet --tier 0

Tiers:
  0  Python venv + install from pyproject when present
  1  + targeted submodule init (when .env-doctor.conf / scan enabled), dev extras, pre-commit
  2  + all submodules (git submodule update --init), dev tools
  3  + Docker services

Private repos over HTTPS/SSH:
  If submodule init fails, ensure SSH works (ssh -T git@github.com) or use HTTPS with a token.
EOF
      exit 0 ;;
    *) echo "Unknown arg: $1 (try --help)"; exit 1 ;;
  esac
done

_bootstrap_env
_setup_colors

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 1: Shell & OS Discovery
# ═════════════════════════════════════════════════════════════════════════════
phase1_shell_os() {
  _head "Phase 1: Shell & OS Discovery"

  # OS
  local os_name kernel arch
  kernel="$(uname -s)"
  arch="$(uname -m)"
  case "$kernel" in
    Linux)
      if [[ -f /etc/os-release ]]; then
        os_name="$(. /etc/os-release && echo "$PRETTY_NAME")"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        os_name="WSL (Linux)"
      else
        os_name="Linux (unknown distro)"
      fi ;;
    Darwin) os_name="macOS $(sw_vers -productVersion 2>/dev/null || echo '?')" ;;
    *)      os_name="$kernel" ;;
  esac
  _pass "OS" "$os_name ($arch)"

  # Shell
  local current_shell shell_ver
  current_shell="${SHELL:-unknown}"
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    shell_ver="zsh $ZSH_VERSION"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    shell_ver="bash $BASH_VERSION"
  else
    shell_ver="$current_shell"
  fi
  _pass "Shell" "$shell_ver"

  # Shell config files
  local configs=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.profile")
  local found_configs=()
  for f in "${configs[@]}"; do
    [[ -f "$f" ]] && found_configs+=("$(basename "$f")")
  done
  if [[ ${#found_configs[@]} -gt 0 ]]; then
    _pass "Shell configs found" "${found_configs[*]}"
  else
    _warn "Shell configs" "none found (no .bashrc, .zshrc, .profile, etc.)"
  fi

  # Alias warnings — check for dangerous overrides of coreutils
  _check_alias_shadows
}

_check_alias_shadows() {
  local dangerous_aliases=()
  local shadow_cmds=(rm mv cp cat diff grep ls)
  local configs=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.profile")

  # Collect alias definitions: from current shell (if interactive) and from config files
  local alias_lines
  alias_lines="$(alias 2>/dev/null || true)"
  for f in "${configs[@]}"; do
    [[ -f "$f" ]] && alias_lines+=$'\n'"$(grep -E '^\s*alias\s+('"$(IFS='|'; echo "${shadow_cmds[*]}")"')=' "$f" 2>/dev/null || true)"
  done

  for cmd in "${shadow_cmds[@]}"; do
    local match
    match="$(echo "$alias_lines" | grep -E "^(alias\s+)?${cmd}=" 2>/dev/null | head -1)" || true
    [[ -z "$match" ]] && continue

    # ls/grep with only --color are usually safe (just coloring)
    case "$cmd" in
      ls|grep)
        if echo "$match" | grep -qE '\-\-color' && ! echo "$match" | grep -qE '\-i|\-f|\-r|\-n'; then
          continue
        fi ;;
    esac
    # -i (interactive), -f (force), -r (recursive), -n (no-clobber) can break automation
    if echo "$match" | grep -qE '\-i|\-f|\-r|\-n'; then
      dangerous_aliases+=("$cmd")
    fi
  done

  if [[ ${#dangerous_aliases[@]} -gt 0 ]]; then
    _warn "Alias shadows" "${dangerous_aliases[*]} — may break automation (check shell config)"
  else
    _pass "Alias shadows" "none detected"
  fi
}

_project_has() {
  local want="$1" i
  # Avoid "${PROJECT_TYPES[@]}" under set -u when the array is empty (some Bash builds error).
  for (( i = 0; i < ${#PROJECT_TYPES[@]}; i++ )); do
    [[ "${PROJECT_TYPES[$i]}" == "$want" ]] && return 0
  done
  return 1
}

_detect_project_types() {
  PROJECT_TYPES=()
  cd "$REPO_ROOT" 2>/dev/null || return 0
  if [[ -f pyproject.toml ]] || [[ -f requirements.txt ]] || [[ -f setup.py ]] || [[ -f setup.cfg ]]; then
    PROJECT_TYPES+=("python")
  fi
  [[ -f package.json ]] && PROJECT_TYPES+=("node")
  [[ -f Cargo.toml ]] && PROJECT_TYPES+=("rust")
  [[ -f go.mod ]] && PROJECT_TYPES+=("go")
  return 0
}

_check_zen_teaser() {
  if command -v zen &>/dev/null; then
    local zv
    zv="$(zen --version 2>&1 | head -1)"
    _pass "zen" "$zv"
  else
    _info "zen" "not installed"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 2: Core Tooling Discovery
# ═════════════════════════════════════════════════════════════════════════════
phase2_tooling() {
  _head "Phase 2: Tooling Discovery"

  _detect_project_types
  if [[ ${#PROJECT_TYPES[@]} -eq 0 ]]; then
    _info "Project manifests" "none at repo root (pyproject.toml, package.json, Cargo.toml, go.mod)"
  else
    _info "Project types" "${PROJECT_TYPES[*]}"
  fi

  # ── Tier 0: Required ──
  _info "Tier 0" "Required tools"
  _check_tool "git"       "git --version"        ""

  if _project_has python; then
    _check_python
    _check_pkg_manager
  else
    _info "python scan" "skipped (no Python manifest at repo root)"
    if command -v python3 &>/dev/null; then
      BEST_PYTHON="python3"
    elif command -v python &>/dev/null; then
      BEST_PYTHON="python"
    else
      BEST_PYTHON=""
    fi
    PKG_MANAGER="${PKG_MANAGER:-}"
  fi

  # ── Tier 1: Recommended (cross-language) ──
  _info "Tier 1" "Recommended tools"
  _check_tool "docker"    "docker --version"     ""
  _check_tool "gh"        "gh --version"         "GitHub CLI"
  _check_tool "pre-commit" "pre-commit --version" ""

  if _project_has node; then
    _info "Node project" "package.json detected"
    _check_tool "node"      "node --version"       ""
    _check_tool "npm"       "npm --version"        ""
    if [[ -f "$REPO_ROOT/package.json" ]] && [[ ! -d "$REPO_ROOT/node_modules" ]]; then
      _warn "node_modules" "missing (run npm install)"
    fi
  fi

  if _project_has rust; then
    _info "Rust project" "Cargo.toml detected"
    _check_tool "cargo"   "cargo --version"      ""
    if [[ -f "$REPO_ROOT/Cargo.toml" ]] && [[ ! -f "$REPO_ROOT/Cargo.lock" ]]; then
      _info "Cargo.lock" "missing (run cargo generate-lockfile or cargo build)"
    fi
  fi

  if _project_has go; then
    _info "Go project" "go.mod detected"
    _check_tool "go"      "go version"           ""
  fi

  # ── Tier 2: Dev extras ──
  _info "Tier 2" "Dev extras"
  _check_tool "rg"        "rg --version"         "ripgrep"
  if _project_has python; then
    _check_tool "black"     "black --version"      ""
    _check_tool "ruff"      "ruff --version"       ""
    _check_tool "mypy"      "mypy --version"       ""
    _check_tool "pytest"    "pytest --version"     ""
    _check_tool "mkdocs"    "mkdocs --version"     ""
  fi
  _check_tool "shellcheck" "shellcheck --version" ""
  _check_tool "yamllint"  "yamllint --version"   ""

  # ── Tier 3: Teaser + shell tooling ──
  _info "Tier 3" "Project-specific"
  _check_zen_teaser

  # ── Python environment + optional deps (Python projects only) ──
  if _project_has python; then
    _head "Phase 2b: Python Environment"
    if [[ -d "$REPO_ROOT/.venv" ]]; then
      _pass "Virtualenv" ".venv exists"
    elif [[ -d "$REPO_ROOT/venv" ]]; then
      _pass "Virtualenv" "venv exists"
    else
      _warn "Virtualenv" "no .venv or venv directory found"
    fi

    local python_to_use="python3"
    if [[ -f "$REPO_ROOT/.venv/bin/python" ]]; then
      python_to_use="$REPO_ROOT/.venv/bin/python"
    elif [[ -f "$REPO_ROOT/venv/bin/python" ]]; then
      python_to_use="$REPO_ROOT/venv/bin/python"
    fi

    if [[ -n "${ENV_DOCTOR_PYTHON_DEPS:-}" ]]; then
      local deps_ok=true dep import_name
      for dep in ${ENV_DOCTOR_PYTHON_DEPS//,/ }; do
        dep="$(echo "$dep" | tr -d '[:space:]')"
        [[ -z "$dep" ]] && continue
        import_name="$dep"
        [[ "$dep" == "pyyaml" ]] && import_name="yaml"
        if ! "$python_to_use" -c "import $import_name" 2>/dev/null; then
          deps_ok=false
          break
        fi
      done
      if [[ "$deps_ok" == true ]]; then
        _pass "Python deps (ENV_DOCTOR_PYTHON_DEPS)" "all importable"
      else
        _warn "Python deps (ENV_DOCTOR_PYTHON_DEPS)" "not all importable (venv + pip install)"
      fi
    else
      _info "Python deps" "ENV_DOCTOR_PYTHON_DEPS not set — skipping import check"
    fi
  fi
}

_check_tool() {
  local name="$1" cmd="$2" label="${3:-$1}"
  local full_cmd="$name"

  if ! command -v "$name" &>/dev/null; then
    if [[ -f "$REPO_ROOT/.venv/bin/$name" ]]; then
      full_cmd="$REPO_ROOT/.venv/bin/$name"
    fi
  fi

  if command -v "$full_cmd" &>/dev/null; then
    local ver
    # If using absolute path, we might need to use it in the cmd too
    local eval_cmd="${cmd/$name/$full_cmd}"
    ver="$(eval "$eval_cmd" 2>&1 | head -1 | sed 's/.*version //' | sed 's/^v//')" || ver="?"
    _pass "$label" "$ver"
  else
    _warn "$label" "not found"
  fi
}

_check_python() {
  local best="" best_ver=""
  for py in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$py" &>/dev/null; then
      local ver
      ver="$($py --version 2>&1 | awk '{print $2}')"
      local major minor
      major="$(echo "$ver" | cut -d. -f1)"
      minor="$(echo "$ver" | cut -d. -f2)"
      if [[ -z "$best" ]]; then
        best="$py"; best_ver="$ver"
      fi
      if [[ "$major" -ge 3 ]] && [[ "$minor" -ge 10 ]]; then
        _pass "python ($py)" "$ver"
        BEST_PYTHON="$py"
        return
      fi
    fi
  done
  if [[ -n "$best" ]]; then
    local py_hint="3.10+ recommended"
    [[ -f "$REPO_ROOT/pyproject.toml" ]] && py_hint="3.10+ recommended (see pyproject.toml)"
    _warn "python ($best)" "$best_ver ($py_hint)"
    BEST_PYTHON="$best"
  else
    _fail "python" "not found"
    BEST_PYTHON=""
  fi
}

_check_pkg_manager() {
  local found=""
  for mgr in uv poetry pip3 pip; do
    if command -v "$mgr" &>/dev/null; then
      local ver
      ver="$($mgr --version 2>&1 | head -1)"
      _pass "pkg manager ($mgr)" "$ver"
      found="$mgr"
      break
    fi
  done
  if [[ -z "$found" ]]; then
    if _project_has python; then
      _fail "pkg manager" "none of uv/poetry/pip found"
    else
      _info "pkg manager" "none found (optional without a Python manifest)"
    fi
  fi
  PKG_MANAGER="${found:-}"
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 3: Git & Submodule Discovery
# ═════════════════════════════════════════════════════════════════════════════
phase3_git() {
  _head "Phase 3: Git & Submodule Discovery"

  cd "$REPO_ROOT"

  # Remote & branch
  local branch remote
  branch="$(git branch --show-current 2>/dev/null || echo "detached")"
  remote="$(git remote get-url origin 2>/dev/null || echo "none")"
  _pass "Branch" "$branch"
  _pass "Remote" "$remote"

  # Dirty check
  local dirty
  dirty="$(git status --porcelain 2>/dev/null | head -5 | wc -l | tr -d ' ')"
  if [[ "$dirty" == "0" ]]; then
    _pass "Working tree" "clean"
  else
    _warn "Working tree" "$dirty+ uncommitted changes"
  fi

  if [[ "$WITH_SUBMODULES" != true ]]; then
    _info "Submodules" "scan skipped (--with-submodules to include)"
  else
    # Submodule classification
    local total=0 initialized=0 uninitialized=0 modified=0
    local tier0_subs=() tier1_subs=() tier2_subs=() tier3_subs=()
    local core_repos="${ENV_DOCTOR_CORE_REPOS:-}"

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      total=$((total+1))
      local prefix="${line:0:1}"
      local path
      path="$(_submodule_status_path_from_line "$line")"

      case "$prefix" in
        '-') uninitialized=$((uninitialized+1)) ;;
        '+') modified=$((modified+1)) ;;
        ' ') initialized=$((initialized+1)) ;;
      esac

      if [[ -n "$core_repos" ]] && echo "$path" | grep -qE "(${core_repos})$"; then
        tier0_subs+=("$path")
      elif [[ "$PROFILE" == dev-master ]] && [[ "$path" == dex/09-repos/* ]]; then
        tier1_subs+=("$path")
      elif [[ "$PROFILE" == dev-master ]] && [[ "$path" == dex/06-tools/* ]]; then
        tier2_subs+=("$path")
      else
        tier3_subs+=("$path")
      fi
    done < <(git submodule status 2>/dev/null || true)

    _pass "Submodules total" "$total"
    _info "  initialized"    "$initialized"
    _info "  uninitialized"  "$uninitialized"
    if [[ "$modified" -gt 0 ]]; then
      _warn "  modified" "$modified"
    else
      _info "  modified" "$modified"
    fi
    _info "Tier 0 (core)"    "${#tier0_subs[@]} submodules"
    _info "Tier 1 (repos)"   "${#tier1_subs[@]} submodules"
    _info "Tier 2 (tools)"   "${#tier2_subs[@]} submodules"
    _info "Tier 3 (other)"   "${#tier3_subs[@]} submodules"

    _check_private_submodules
  fi

  # Orphan check (only meaningful when .gitmodules exists)
  if [[ -f .gitmodules ]]; then
    local orphans=0
    local gitmod_paths
    gitmod_paths="$(grep 'path = ' .gitmodules 2>/dev/null | sed 's/.*path = //' || true)"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local p
      p="${line#*$'\t'}"
      [[ -z "$p" || "$p" == "$line" ]] && continue
      if ! echo "$gitmod_paths" | grep -qFx "$p"; then
        orphans=$((orphans+1))
      fi
    done < <(git ls-files -s 2>/dev/null | grep "^160000" || true)

    if [[ "$orphans" -gt 0 ]]; then
      _fail "Orphan gitlinks" "$orphans (in index but not in .gitmodules)"
    else
      _pass "Orphan gitlinks" "none"
    fi
  else
    _pass "Orphan gitlinks" "no .gitmodules — skipped"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 4: Credential & Config Discovery
# ═════════════════════════════════════════════════════════════════════════════
phase4_creds() {
  _head "Phase 4: Credentials & Config"

  cd "$REPO_ROOT"

  # .env vs env.example
  if [[ -f .env ]]; then
    _pass ".env" "exists"
    local missing_keys=()
    while IFS= read -r line; do
      local key
      key="$(echo "$line" | grep -oE '^[A-Z_]+' || true)"
      [[ -z "$key" ]] && continue
      if ! grep -q "^${key}=" .env 2>/dev/null; then
        missing_keys+=("$key")
      fi
    done < <(grep -E '^[A-Z_]+=' env.example 2>/dev/null || true)

    if [[ ${#missing_keys[@]} -gt 0 ]]; then
      _warn ".env missing keys" "${#missing_keys[@]} keys not set (vs env.example)"
    else
      _pass ".env completeness" "all env.example keys present"
    fi

    if grep -q 'mock-key\|your-api-key-here\|CHANGE_ME' .env 2>/dev/null; then
      _warn ".env placeholders" "contains mock/placeholder values"
    fi
  else
    if [[ -f env.example ]]; then
      _warn ".env" "missing (run: cp env.example .env)"
    else
      _info ".env" "missing (no env.example in repo — skipped)"
    fi
  fi

  # gh auth
  if command -v gh &>/dev/null; then
    if gh auth status 2>&1 | grep -q "Logged in"; then
      _pass "gh auth" "authenticated"
    else
      _warn "gh auth" "not authenticated (run: gh auth login)"
    fi
  fi

  # Docker daemon
  if command -v docker &>/dev/null; then
    if _timeout_cmd 3 docker info &>/dev/null 2>&1; then
      _pass "Docker daemon" "reachable"
    else
      _warn "Docker daemon" "not reachable (start Docker Desktop or check socket)"
    fi
  fi

  # MCP config placeholders (lines with # env-doctor-skip or env-doctor-skip are excluded)
  local mcp_config="$HOME/.cursor/mcp.json"
  if [[ -f "$mcp_config" ]]; then
    local placeholders=0
    for pattern in "CHANGE_ME" "YOUR_.*_HERE" "PMAK-CHANGE_ME" "mock-key"; do
      if grep -E "$pattern" "$mcp_config" 2>/dev/null | grep -v "env-doctor-skip" | grep -q .; then
        placeholders=$((placeholders+1))
      fi
    done
    if [[ "$placeholders" -gt 0 ]]; then
      _warn "MCP config" "$placeholders placeholder pattern(s) in $mcp_config"
    else
      _pass "MCP config" "no placeholder patterns detected"
    fi
  else
    _info "MCP config" "$mcp_config not found (Cursor-specific)"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 4b: Local AI Stack (LM Studio / OpenAI-compat)
# ═════════════════════════════════════════════════════════════════════════════
phase4b_local_ai() {
  _head "Phase 4b: Local AI Stack"

  local lms_url="${LMSTUDIO_API_URL:-http://localhost:1234/v1}"

  # LM Studio API reachability
  if curl -sf --connect-timeout 2 "${lms_url}/models" > /dev/null 2>&1; then
    _pass "LM Studio API" "alive at ${lms_url}"

    local model_count
    model_count="$(curl -sf "${lms_url}/models" 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("data",[])))' 2>/dev/null || echo 0)"
    if [[ "$model_count" -gt 0 ]]; then
      _pass "Loaded models" "${model_count} model(s) available"
    else
      _warn "Loaded models" "API is up but no models loaded (run: lms load)"
    fi
  else
    _info "LM Studio API" "not reachable at ${lms_url} (optional — start LM Studio to enable)"
  fi

  # lms CLI
  if command -v lms &>/dev/null; then
    _pass "lms CLI" "$(command -v lms)"
  else
    _info "lms CLI" "not in PATH (optional — install from lmstudio.ai)"
  fi

  # .cursor/mcp.json LM Studio entry
  local repo_mcp="$REPO_ROOT/.cursor/mcp.json"
  if [[ -f "$repo_mcp" ]]; then
    if grep -q '"lmstudio"' "$repo_mcp" 2>/dev/null; then
      if grep -q '"disabled": true' "$repo_mcp" 2>/dev/null; then
        _info "MCP lmstudio" 'present but disabled (set "disabled": false to enable)'
      else
        _pass "MCP lmstudio" "configured and enabled"
      fi
    else
      _info "MCP lmstudio" "not configured in .cursor/mcp.json"
    fi
  fi

  # Task notebooks (dev-master / explicit opt-in only)
  if [[ "$PROFILE" == dev-master ]] || [[ "${ENV_DOCTOR_SHOW_AGENT_RAM:-}" == true ]]; then
    if [[ -d "$REPO_ROOT/dex/10-tasks/active" ]]; then
      _pass "Agent RAM" "dex/10-tasks/active/ exists"
    else
      _warn "Agent RAM" "dex/10-tasks/active/ missing"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 5: Progressive Init (--init only)
# ═════════════════════════════════════════════════════════════════════════════
phase5_init() {
  [[ "$DO_INIT" == false ]] && return

  _head "Phase 5: Progressive Init (tier $INIT_TIER)"
  [[ "$DRY_RUN" == "true" ]] && _info "dry-run" "showing planned actions only (no changes)"

  cd "$REPO_ROOT"

  # ── Tier 0: Venv + core deps ──
  if [[ "$INIT_TIER" -ge 0 ]]; then
    _info "Tier 0" "Python venv + core deps"
    if [[ -z "${BEST_PYTHON:-}" ]]; then
      _fail "Init aborted" "no Python found"
      return 1
    fi
    if [[ -z "${PKG_MANAGER:-}" ]]; then
      for mgr in uv poetry pip3 pip; do
        if command -v "$mgr" &>/dev/null; then
          PKG_MANAGER="$mgr"
          break
        fi
      done
    fi
    if [[ -z "${PKG_MANAGER:-}" ]]; then
      _fail "Init aborted" "no package manager (install pip/uv/poetry)"
      return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      [[ ! -d .venv ]] && _info "Would run" "$BEST_PYTHON -m venv .venv"
      _info "Would run" "$([[ "${PKG_MANAGER:-}" == poetry ]] && echo 'poetry install' || echo 'pip install -e .')"
      _pass "Tier 0 init" "planned (dry-run)"
    else
      if [[ ! -d .venv ]]; then
        echo "  Creating .venv with $BEST_PYTHON..." >&2
        "$BEST_PYTHON" -m venv .venv
      fi
      # shellcheck disable=SC1091
      source .venv/bin/activate

      if [[ "${PKG_MANAGER:-}" == "poetry" ]]; then
        echo "  Installing deps via poetry..." >&2
        poetry install --no-interaction --no-root
      else
        echo "  Installing deps via pip..." >&2
        pip install -e . --quiet
      fi
      _pass "Tier 0 init" "venv + core deps installed"
    fi
  fi

  # ── Tier 1: Core submodules + dev extras + pre-commit ──
  if [[ "$INIT_TIER" -ge 1 ]]; then
    _info "Tier 1" "Core submodules + dev extras"

    if [[ "$WITH_SUBMODULES" != true ]]; then
      _info "Tier 1 submodules" "skipped (--with-submodules to include submodule init)"
    else
      local -a core_paths=()
      if [[ -n "${ENV_DOCTOR_CORE_REPOS:-}" ]]; then
        while IFS= read -r cl; do
          [[ -z "$cl" ]] && continue
          local p
          p="$(_git_config_regexp_value "$cl")"
          echo "$p" | grep -qE "(${ENV_DOCTOR_CORE_REPOS})$" || continue
          core_paths+=("$p")
        done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        for p in "${core_paths[@]}"; do
          _info "Would run" "git submodule update --init $p"
        done
        local -a remaining_repos=()
        while IFS= read -r cl; do
          [[ -z "$cl" ]] && continue
          local rp
          rp="$(_git_config_regexp_value "$cl")"
          [[ "$rp" == dex/09-repos/* ]] || continue
          remaining_repos+=("$rp")
        done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)
        for p in "${remaining_repos[@]}"; do
          _info "Would run" "git submodule update --init $p"
        done
      else
        for p in "${core_paths[@]}"; do
          echo "  Init submodule: $p" >&2
          if ! git submodule update --init "$p" 2>&1; then
            local url
            url="$(git config -f .gitmodules --get "submodule.${p}.url" 2>/dev/null || echo "")"
            if echo "$url" | grep -qiE '(/private/|/internal/|@private\.|[.]private\.)'; then
              echo "    ⚠️  Private submodule failed (credentials needed)" >&2
              if [[ -n "${ENV_DOCTOR_HELP_URL:-}" ]]; then
                echo "    See: $ENV_DOCTOR_HELP_URL" >&2
              fi
            fi
          fi
        done

        local -a remaining_repos=()
        while IFS= read -r cl; do
          [[ -z "$cl" ]] && continue
          local rp
          rp="$(_git_config_regexp_value "$cl")"
          [[ "$rp" == dex/09-repos/* ]] || continue
          remaining_repos+=("$rp")
        done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)

        for p in "${remaining_repos[@]}"; do
          if ! git submodule update --init "$p" 2>&1; then
            local url
            url="$(git config -f .gitmodules --get "submodule.${p}.url" 2>/dev/null || echo "")"
            if echo "$url" | grep -qiE '(/private/|/internal/|@private\.|[.]private\.)'; then
              echo "    ⚠️  Private submodule failed (credentials needed)" >&2
              if [[ -n "${ENV_DOCTOR_HELP_URL:-}" ]]; then
                echo "    See: $ENV_DOCTOR_HELP_URL" >&2
              fi
            fi
          fi
        done
      fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      _info "Would run" "pip install -e .[dev] + pre-commit install"
      _pass "Tier 1 init" "planned (dry-run)"
    else
      if [[ -d .venv ]]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
        echo "  Installing dev extras..." >&2
        pip install -e ".[dev]" --quiet 2>/dev/null || true
      fi

      if command -v pre-commit &>/dev/null; then
        echo "  Installing pre-commit hooks..." >&2
        pre-commit install --allow-missing-config 2>/dev/null || true
      fi

      _pass "Tier 1 init" "core submodules + dev extras"
    fi
  fi

  # ── Tier 2: All submodules + dev tools ──
  if [[ "$INIT_TIER" -ge 2 ]]; then
    _info "Tier 2" "All submodules + dev tools"

    if [[ "$DRY_RUN" == "true" ]]; then
      _info "Would run" "git submodule update --init"
      if command -v brew &>/dev/null; then
        for tool in ripgrep shellcheck yamllint; do
          ! command -v "$tool" &>/dev/null && _info "Would run" "brew install $tool"
        done
      elif command -v apt-get &>/dev/null; then
        for tool in ripgrep shellcheck yamllint; do
          ! command -v "$tool" &>/dev/null && _info "Would run" "apt install $tool"
        done
      fi
      _pass "Tier 2 init" "planned (dry-run)"
    else
      echo "  Initializing all submodules..." >&2
      git submodule update --init 2>/dev/null || true

      if command -v brew &>/dev/null; then
        for tool in ripgrep shellcheck yamllint; do
          if ! command -v "$tool" &>/dev/null; then
            echo "  brew install $tool..." >&2
            brew install "$tool" 2>/dev/null || true
          fi
        done
      elif command -v apt-get &>/dev/null; then
        for tool in ripgrep shellcheck yamllint; do
          if ! command -v "$tool" &>/dev/null; then
            echo "  apt install $tool..." >&2
            sudo apt-get install -y "$tool" 2>/dev/null || true
          fi
        done
      fi

      _pass "Tier 2 init" "all submodules + dev tools"
    fi
  fi

  # ── Tier 3: Docker services ──
  if [[ "$INIT_TIER" -ge 3 ]]; then
    _info "Tier 3" "Docker services"

    if [[ "$DRY_RUN" == "true" ]]; then
      if command -v docker &>/dev/null; then
        _info "Would run" "docker compose up -d"
      fi
      _pass "Tier 3 init" "planned (dry-run)"
    elif _timeout_cmd 3 docker info &>/dev/null 2>&1; then
      if [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
        echo "  Starting docker-compose services..." >&2
        docker compose -f "$REPO_ROOT/docker-compose.yml" up -d 2>/dev/null || true
      fi
      _pass "Tier 3 init" "Docker services started"
    else
      _warn "Tier 3 init" "Docker not reachable, skipped"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
summary() {
  _head "Summary"
  # Do not use _pass/_warn/_fail for Status — they bump ISSUES/WARNINGS and skew JSON totals.
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    # type "status" (not pass/warn/fail) so footer issues/warnings match row counts of fail/warn.
    if [[ "$ISSUES" -eq 0 ]] && [[ "$WARNINGS" -eq 0 ]]; then
      JSON_LINES+=("$(_jline "status" "Status" "all checks passed")")
    elif [[ "$ISSUES" -eq 0 ]]; then
      JSON_LINES+=("$(_jline "status" "Status" "${WARNINGS} warning(s), 0 failures")")
    else
      JSON_LINES+=("$(_jline "status" "Status" "${ISSUES} failure(s), ${WARNINGS} warning(s)")")
    fi
  else
    if [[ "$ISSUES" -eq 0 ]] && [[ "$WARNINGS" -eq 0 ]]; then
      [[ "$QUIET" != "true" ]] && printf "  ${G}[PASS]${RST}  %-28s %s\n" "Status" "all checks passed"
    elif [[ "$ISSUES" -eq 0 ]]; then
      [[ "$QUIET" != "true" ]] && printf "  ${Y}[WARN]${RST}  %-28s %s\n" "Status" "${WARNINGS} warning(s), 0 failures"
    else
      [[ "$QUIET" != "true" ]] && printf "  ${R}[FAIL]${RST}  %-28s %s\n" "Status" "${ISSUES} failure(s), ${WARNINGS} warning(s)"
    fi
  fi

  if [[ "$OUTPUT_JSON" == "true" ]]; then
    local i
    printf '{"results":['
    for i in "${!JSON_LINES[@]}"; do
      [[ $i -gt 0 ]] && printf ','
      printf '%s' "${JSON_LINES[$i]}"
    done
    printf '],"issues":%d,"warnings":%d,"ok":%s}\n' "$ISSUES" "$WARNINGS" "$([[ $ISSUES -eq 0 ]] && echo true || echo false)"
    return
  fi

  if [[ "$DO_INIT" == false ]] && [[ "$QUIET" == false ]]; then
    printf "\n${DIM}  To fix issues, run: %s --init${RST}\n" "$DOCTOR_NAME"
    printf "${DIM}  For full setup:     %s --init --tier 2${RST}\n\n" "$DOCTOR_NAME"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════
main() {
  if [[ "$QUIET" == false ]] && [[ "$OUTPUT_JSON" == false ]]; then
    printf "${BOLD}%s${RST} — environment check\n" "${BRAND:-$DOCTOR_NAME}"
    printf "${DIM}repo: %s  profile: %s  submodules: %s${RST}\n" "$REPO_ROOT" "$PROFILE" "$WITH_SUBMODULES"
  fi

  # Handle --submodules-only flag
  if [[ "$SUBMODULES_ONLY" == "true" ]]; then
    _check_private_submodules
    return
  fi

  phase1_shell_os
  phase2_tooling
  phase3_git
  phase4_creds
  phase4b_local_ai
  phase5_init
  summary

  [[ "$ISSUES" -gt 0 ]] && exit 1
  exit 0
}

BEST_PYTHON=""
PKG_MANAGER=""
main "$@"
