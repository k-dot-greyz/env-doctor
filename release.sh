#!/usr/bin/env bash
# release.sh — Build a clean distributable zip for env-doctor.
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
VERSION="$(bash "${SCRIPT_DIR}/env-doctor.sh" --version)"
ZIP_NAME="env-doctor-${VERSION}.zip"

echo "Building env-doctor v${VERSION} release bundle..."

# Clean previous builds
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/env-doctor"

# Copy clean files
cp "${SCRIPT_DIR}/env-doctor.sh" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/.env-doctor.conf.example" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/LICENSE" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/README.md" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/INSTALL.md" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/CHANGELOG.md" "${DIST_DIR}/env-doctor/"
cp "${SCRIPT_DIR}/landing.md" "${DIST_DIR}/env-doctor/"

# Copy docs
mkdir -p "${DIST_DIR}/env-doctor/docs"
cp -r "${SCRIPT_DIR}/docs/"* "${DIST_DIR}/env-doctor/docs/"

# Create zip
cd "${DIST_DIR}"
zip -rq "${ZIP_NAME}" env-doctor

# Generate SHA256 checksums
echo "Generating SHA256 checksums..."
if command -v sha256sum &>/dev/null; then
  sha256sum "${ZIP_NAME}" > SHA256SUMS
  sha256sum env-doctor/env-doctor.sh >> SHA256SUMS
elif command -v shasum &>/dev/null; then
  shasum -a 256 "${ZIP_NAME}" > SHA256SUMS
  shasum -a 256 env-doctor/env-doctor.sh >> SHA256SUMS
fi

echo "Release bundle created successfully: dist/${ZIP_NAME}"
