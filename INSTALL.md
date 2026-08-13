# Installation and Setup

`env-doctor` is a single-file, zero-dependency Bash script. It can be installed in seconds.

## Release Installation

Download the latest release bundle from the GitHub Releases page once a release has been published.

Each release bundle should include:

- `env-doctor.sh`
- `.env-doctor.conf.example`
- `README.md`
- `INSTALL.md`
- `CHANGELOG.md`
- `docs/`
- `SHA256SUMS`

Verify the downloaded release:

```bash
sha256sum --check --ignore-missing SHA256SUMS
# or on macOS:
shasum -a 256 --check --ignore-missing SHA256SUMS
```

Then copy the script into your repository:

```bash
cp env-doctor/env-doctor.sh ./env-doctor.sh
chmod +x env-doctor.sh
```

## Quick Installation (Unverified)

To download `env-doctor.sh` directly into your repository without verification:

```bash
curl -fsSL https://raw.githubusercontent.com/k-dot-greyz/env-doctor/main/env-doctor.sh -o env-doctor.sh
chmod +x env-doctor.sh
```

## Global Installation

If you prefer to make `env-doctor` available as a global command on your system:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/k-dot-greyz/env-doctor/main/env-doctor.sh -o /usr/local/bin/env-doctor
sudo chmod +x /usr/local/bin/env-doctor
```

## Customizing Checks

To customize the checks for your project, copy the configuration template to your repository root:

```bash
cp .env-doctor.conf.example .env-doctor.conf
```

Edit `.env-doctor.conf` to specify your project's core submodules, Python dependencies, and custom help URLs.
