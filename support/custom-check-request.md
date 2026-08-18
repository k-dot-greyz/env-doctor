# Custom Diagnostic Check Request Template

Use this template to request custom diagnostic checks or integrations for your Env Doctor deployment. Our engineering team will review the request and provide a hardened, production-grade implementation.

Submit this request by opening an issue in your private support repository or emailing it to `support@glitchworks.io`.

## 1. Check Overview

- **Check Name**: (e.g., Verify AWS CLI SSO Session)
- **Target Tier**:
  - [ ] Tier 0 (Core Tools)
  - [ ] Tier 1 (Recommended Tools & Config)
  - [ ] Tier 2 (Dev Extras & Submodules)
  - [ ] Tier 3 (Docker & Services)
- **Primary OS Scope**:
  - [ ] macOS
  - [ ] Linux
  - [ ] Windows (Git Bash)
  - [ ] All

## 2. Diagnostic Logic

Describe how to manually verify this condition on a developer's machine:

- **Command to run**: (e.g., `aws sts get-caller-identity`)
- **Expected output/success criteria**: (e.g., Returns active account details with exit code 0)
- **Failure criteria/exit codes**: (e.g., Returns "ExpiredToken" or exit code 254)

## 3. Auto-Healing / Remediation Logic (Optional)

If the check fails, can the environment be automatically healed during `--init`?

- **Remediation steps**: (e.g., Run `aws sso login`)
- **Requires user interaction?** (Yes / No)
- **Requires system privileges (sudo)?** (Yes / No)

## 4. Error Message & Developer Guidance

What should Env Doctor print to the developer if this check fails?

- **Short Warning/Error message**: (e.g., AWS SSO session expired)
- **Detailed troubleshooting steps**: (e.g., Run `aws sso login --profile default` to renew your session. For help, visit: https://wiki.acme.internal/aws-sso)

## 5. Context & Business Value

- **Why is this check important for your team?**
- **How often does this issue occur?**
