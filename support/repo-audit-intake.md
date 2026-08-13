# Repository Environment Audit Intake Form

If you have a complex repository structure, legacy dependencies, custom private package registries, or specialized build containers, we can help you build a custom, hardened Env Doctor configuration.

Please fill out this questionnaire and send it to our support team at `support@glitchworks.io` (or your dedicated account manager) to initiate a custom environment audit.

## 1. Contact Information

- **Company Name**:
- **Contact Person**:
- **Email Address**:
- **Dedicated Slack/Discord Channel (if applicable)**:

## 2. Repository Overview

- **Repository Name/Alias**:
- **Primary Programming Languages**:
- **Approximate Number of Active Developers**:
- **Primary Operating Systems Used by Developers**:
  - [ ] macOS (Apple Silicon)
  - [ ] macOS (Intel)
  - [ ] Linux (Ubuntu/Debian)
  - [ ] Linux (RHEL/CentOS)
  - [ ] Windows (Git Bash/MSYS2)
  - [ ] Windows (WSL2)

## 3. Dependency Management

- **What package managers do you use?** (e.g., npm, yarn, pnpm, pip, poetry, cargo, go modules, bundler)
- **Do you use private package registries?** (e.g., private npm registry, Artifactory, AWS CodeArtifact)
- **Are there any system-level dependencies required?** (e.g., openssl, postgresql-client, redis-tools, libpq-dev)

## 4. Git & Submodule Structure

- **Does this repository use git submodules?** (Yes / No)
- **If yes, are any of them hosted in private repositories requiring specific SSH keys or tokens?**
- **Do you have custom git hooks that developers must install?**

## 5. Environment Variables & Credentials

- **What configuration/secrets files are required for local development?** (e.g., .env, config.json, credentials.json)
- **What are the key environment variables that developers frequently forget to set or misconfigure?**

## 6. Local Services & Docker

- **Does local development require running background services?** (e.g., databases, caches, message brokers)
- **Do you use Docker Compose to manage these services locally?**
- **What are the common failure modes developers encounter with these services?**

## 7. Desired Outcomes

- **What are the top 3 environment-related issues that waste developer time in this repository?**
- **Do you want to integrate Env Doctor with a custom internal wiki, developer portal, or onboarding guide?**
