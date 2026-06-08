#!/usr/bin/env bash
# release.sh — Build a clean commercial Field Kit release bundle for env-doctor.
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
VERSION="$(bash "${SCRIPT_DIR}/env-doctor.sh" --version)"
KIT_NAME="env-doctor-field-kit-v${VERSION}"
ZIP_NAME="${KIT_NAME}.zip"

echo "Building env-doctor Field Kit v${VERSION} release bundle..."

# Clean previous builds
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/${KIT_NAME}"

# Copy core files
cp "${SCRIPT_DIR}/env-doctor.sh" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/.env-doctor.conf.example" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/LICENSE" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/README-FIRST.md" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/QUICKSTART.md" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/SAFETY.md" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/INSTALL.md" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/CHANGELOG.md" "${DIST_DIR}/${KIT_NAME}/"
cp "${SCRIPT_DIR}/README.md" "${DIST_DIR}/${KIT_NAME}/"

# Copy docs
if [[ -d "${SCRIPT_DIR}/docs" ]]; then
  mkdir -p "${DIST_DIR}/${KIT_NAME}/docs"
  cp -r "${SCRIPT_DIR}/docs/"* "${DIST_DIR}/${KIT_NAME}/docs/"
fi

# Copy templates
if [[ -d "${SCRIPT_DIR}/templates" ]]; then
  mkdir -p "${DIST_DIR}/${KIT_NAME}/templates"
  cp -r "${SCRIPT_DIR}/templates/"* "${DIST_DIR}/${KIT_NAME}/templates/"
fi

# Copy examples
if [[ -d "${SCRIPT_DIR}/examples" ]]; then
  mkdir -p "${DIST_DIR}/${KIT_NAME}/examples"
  cp -r "${SCRIPT_DIR}/examples/"* "${DIST_DIR}/${KIT_NAME}/examples/"
fi

# Copy support templates
if [[ -d "${SCRIPT_DIR}/support" ]]; then
  mkdir -p "${DIST_DIR}/${KIT_NAME}/support"
  cp -r "${SCRIPT_DIR}/support/"* "${DIST_DIR}/${KIT_NAME}/support/"
fi

# Create zip
cd "${DIST_DIR}"
zip -rq "${ZIP_NAME}" "${KIT_NAME}"

# Generate SHA256 checksums
echo "Generating SHA256 checksums..."
if command -v sha256sum &>/dev/null; then
  sha256sum "${ZIP_NAME}" > SHA256SUMS
  sha256sum "${KIT_NAME}/env-doctor.sh" >> SHA256SUMS
elif command -v shasum &>/dev/null; then
  shasum -a 256 "${ZIP_NAME}" > SHA256SUMS
  shasum -a 256 "${KIT_NAME}/env-doctor.sh" >> SHA256SUMS
fi

echo "Release bundle created successfully: dist/${ZIP_NAME}"
