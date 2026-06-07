# Installation and Setup

`env-doctor` is a single-file, zero-dependency Bash script. It can be installed in seconds.

## Quick Installation (with Checksum Verification)

To securely download and verify the latest release of `env-doctor.sh` directly into your repository:

```bash
# Download the script and its SHA256 checksum
curl -fsSL https://raw.githubusercontent.com/greyz/env-doctor/main/env-doctor.sh -o env-doctor.sh
curl -fsSL https://raw.githubusercontent.com/greyz/env-doctor/main/SHA256SUMS -o SHA256SUMS

# Verify the checksum matches
# On Linux:
sha256sum --check --ignore-missing SHA256SUMS
# On macOS:
shasum -a 256 --check --ignore-missing SHA256SUMS

# Once verified, make it executable and clean up
chmod +x env-doctor.sh
rm SHA256SUMS
```

## Quick Installation (Unverified)

To download `env-doctor.sh` directly into your repository without verification:

```bash
curl -fsSL https://raw.githubusercontent.com/greyz/env-doctor/main/env-doctor.sh -o env-doctor.sh
chmod +x env-doctor.sh
```

## Global Installation

If you prefer to make `env-doctor` available as a global command on your system:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/greyz/env-doctor/main/env-doctor.sh -o /usr/local/bin/env-doctor
sudo chmod +x /usr/local/bin/env-doctor
```

## Customizing Checks

To customize the checks for your project, copy the configuration template to your repository root:

```bash
cp .env-doctor.conf.example .env-doctor.conf
```

Edit `.env-doctor.conf` to specify your project's core submodules, Python dependencies, and custom help URLs.
