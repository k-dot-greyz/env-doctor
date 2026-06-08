#!/usr/bin/env bash
# generate-examples.sh — Automatically generate real human and JSON output samples.
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_DOCTOR="${REPO_ROOT}/env-doctor.sh"
EXAMPLES_DIR="${REPO_ROOT}/examples"

echo "Generating sample outputs..."

# Create examples directory if it doesn't exist
mkdir -p "${EXAMPLES_DIR}"

# Create a temporary fixture repo
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Setup mock repo
cd "${TMP_DIR}"
git init -q
git config user.name "Demo Developer"
git config user.email "demo@example.com"

# Create mock .env-doctor.conf
cat <<'EOF' > .env-doctor.conf
BRAND="Acme Core Platform"
ENV_DOCTOR_CORE_REPOS="shared-types"
ENV_DOCTOR_PYTHON_DEPS="yaml,click,pydantic,requests"
ENV_DOCTOR_HELP_URL="https://wiki.acme.internal/dev-setup"
EOF

# Create mock .env and env.example
cat <<'EOF' > .env
DATABASE_URL="postgresql://user:pass@localhost:5432/db"
STRIPE_SECRET_KEY="sk_test_placeholder"
JWT_SECRET="CHANGE_ME"
EOF

cat <<'EOF' > env.example
DATABASE_URL=""
STRIPE_SECRET_KEY=""
JWT_SECRET=""
ANOTHER_KEY=""
EOF

# Create mock pyproject.toml
cat <<'EOF' > pyproject.toml
[project]
name = "acme-platform"
version = "1.0.0"
dependencies = [
    "pyyaml",
    "click",
    "pydantic",
    "requests"
]
EOF

# Create mock .gitmodules
cat <<'EOF' > .gitmodules
[submodule "libs/shared-types"]
	path = libs/shared-types
	url = https://github.com/acme/shared-types.git
[submodule "libs/api-client"]
	path = libs/api-client
	url = https://github.com/acme/api-client.git
EOF

# Copy the script to the temp directory
cp "${ENV_DOCTOR}" ./env-doctor.sh
chmod +x env-doctor.sh

# Run env-doctor.sh in human-readable mode (no TTY means no colors)
# We mock certain commands/outputs to make it look realistic and clean
echo "Running env-doctor.sh in human-readable mode..."
# Export PKG_MANAGER to make it deterministic
export PKG_MANAGER="pip"
bash ./env-doctor.sh --with-submodules > "${EXAMPLES_DIR}/sample-human-output.txt" 2>&1 || true

# Run env-doctor.sh in JSON mode and format with python3
echo "Running env-doctor.sh in JSON mode..."
bash ./env-doctor.sh --with-submodules --json > "${EXAMPLES_DIR}/sample-json-output.json" 2>/dev/null || true

# Format the JSON if python3 is available
if command -v python3 &>/dev/null; then
  python3 -m json.tool "${EXAMPLES_DIR}/sample-json-output.json" > "${EXAMPLES_DIR}/sample-json-output.json.tmp" 2>/dev/null && mv "${EXAMPLES_DIR}/sample-json-output.json.tmp" "${EXAMPLES_DIR}/sample-json-output.json" || true
fi

echo "Examples generated successfully in ${EXAMPLES_DIR}:"
echo "  - sample-human-output.txt"
echo "  - sample-json-output.json"
