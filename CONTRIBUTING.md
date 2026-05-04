# Contributing to DracoLabs

Welcome! This document describes the DracoLabs development workflow. All contributors — human and automated — must follow it. It is part of the **gatekeeper rollout** that protects the `main` branch from secrets, PII, and regressions.

---

## 1. Branch Strategy

- All work happens on **feature branches**, never directly on `main`.
- Branch naming: `feature/<short-description>` (e.g. `feature/add-nft-metadata-validation`)
- Keep branches short-lived. Open a PR as soon as the change is ready for review.
- **Direct commits to `main` are blocked.** Branch protection is enforced; any push directly to `main` will be rejected.

---

## 2. Opening a Pull Request

Before opening a PR, go through this checklist:

- [ ] I have read through my own diff and understand every change
- [ ] No hardcoded secrets, API keys, or credentials anywhere in the diff
- [ ] No hardcoded IP addresses (use environment variables or DNS names)
- [ ] No personally identifiable information (names, emails, phone numbers, locations) in source files
- [ ] Local test suite passes (see [§ Repo-Specific Test Command](#repo-specific-test-command))
- [ ] Local pre-push hooks pass (see [§ Installing Local Hooks](#7-installing-local-hooks))
- [ ] Branch is up to date with `main` (rebase or merge before opening the PR)

Open the PR against `main`. Fill in the description with what changed and why.

---

## 3. Quality Gates

Every PR and every push to `main` runs four automated gates via the shared [quality-gates workflow](/.github/workflows/quality-gates.yml). Each gate is a separate CI job with a clear PASS / FAIL status.

### Gate 1 · Secret Scanning

**Tool:** [gitleaks](https://github.com/gitleaks/gitleaks)
**What it checks:** Scans the PR diff for secrets, credentials, API keys, tokens, and other sensitive strings.
**On failure:** The job lists the offending file and line. Remove the secret, rotate the credential, and force-push the fix branch (with the bad commit removed from history using `git rebase -i` or `git filter-repo`).
**Run locally:**
```bash
gitleaks detect --source . --log-opts "$(git merge-base HEAD main)..HEAD" --report-format json
```

### Gate 2 · IP Address Detection

**What it checks:** Regex scan over changed files for hardcoded IPv4 and IPv6 addresses (excluding test fixtures and documentation via configurable glob patterns).
**On failure:** The job names the file and line. Replace the hardcoded IP with an environment variable, config value, or DNS hostname. If the IP is intentional (e.g. a well-known address like `127.0.0.1`), add the file pattern to the `ip_exclude_globs` input in your repo's `ci.yml`.
**Run locally:**
```bash
# Using the pre-push hook (recommended — see §7)
SKIP_GATES=secret,pii,test git push --dry-run
```

### Gate 3 · PII / DSGVO Detection

**Tool:** [Microsoft Presidio](https://microsoft.github.io/presidio/)
**What it checks:** Scans changed source files for PERSON, EMAIL_ADDRESS, PHONE_NUMBER, and LOCATION entities above a confidence threshold of 0.7.
**On failure:** The job lists the entity type, file path, and surrounding context snippet. Remove or anonymize the PII. For intentional false positives, add an inline suppression comment:
```python
# pii-ignore: test fixture only
name = "Jane Doe"
```
**Run locally:**
```bash
pip install presidio-analyzer spacy && python -m spacy download en_core_web_lg
# Then run the pre-push hook (see §7)
```

### Gate 4 · Test Suite

**What it checks:** Runs the repo's test command. Resolution order: `workflow_call` input → `TEST_COMMAND` repository variable → auto-detection (npm, pytest, go test, make test, cargo test).
**On failure:** Fix the failing tests before merging. Do not merge with a broken test suite.
**Run locally:** See [§ Repo-Specific Test Command](#repo-specific-test-command) below.

### Wiring the gates into a new repo

Create `.github/workflows/ci.yml` in your repo:

```yaml
name: CI
on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [main]
jobs:
  quality-gates:
    uses: DracoLabs/.github/.github/workflows/quality-gates.yml@main
    with:
      test_command: "npm test"   # override with your repo's test command
    secrets: inherit
```

Then add these required status checks in your repo's branch protection settings
(Settings → Branches → main):

- `quality-gates / secret-scan`
- `quality-gates / ip-address-scan`
- `quality-gates / pii-scan`
- `quality-gates / test-suite`

---

## 4. Review Process

- **All PRs are reviewed by [Stark](https://github.com/orgs/DracoLabs/people) (CTO).**
- Expected turnaround: **1 business day** for standard PRs; critical security fixes are prioritised same-day.
- Reviewers check:
  - Code correctness and logic
  - Absence of secrets, hardcoded IPs, and PII (backed by CI gates)
  - Test coverage for new behaviour
  - Adherence to the branch strategy and commit hygiene
  - Clear commit messages that explain *why*, not just *what*
- Address all reviewer comments before requesting a re-review. Mark resolved threads as resolved only after the fix is pushed.

---

## 5. Merge and Push

- **Only Stark merges PRs to `main` and pushes to the GitHub remote.**
- Contributors must **not** push directly to the remote `main` branch.
- Stark performs a final local verification pass (pre-push hooks run automatically) before merging.
- The preferred merge strategy is **squash merge** for feature branches to keep `main`'s history linear and readable.

---

## 6. Emergency Bypass

In a genuine emergency (e.g. a production outage fix that must ship immediately):

1. **Request approval from Stark** via the company's incident channel before bypassing any gate.
2. Stark may authorize a bypass by setting the `SKIP_GATES` environment variable for the pre-push hook:
   ```bash
   SKIP_GATES=secret,ip,pii,test git push origin main
   ```
   Valid gate names: `secret`, `ip`, `pii`, `test`.
3. **All bypasses must be logged.** The hook automatically writes a bypass record to `~/.dracolabs-bypass.log` with the timestamp, gates skipped, commit SHA, and authorizing identity.
4. A follow-up issue must be created within 24 hours to address the bypassed gates properly.

Bypasses are audited. Unauthorized bypasses are a serious policy violation.

---

## 7. Installing Local Hooks

The pre-push hook runs all four quality gates locally before any push reaches GitHub, giving you fast feedback before CI runs.

**Install once per clone:**

```bash
bash scripts/install-hooks.sh
```

This symlinks `scripts/pre-push` into `.git/hooks/pre-push` and verifies that the required tools (gitleaks, presidio-analyzer) are available.

**What the hook does:**

1. Runs gitleaks on the commits being pushed
2. Scans changed files for hardcoded IP addresses
3. Runs presidio-analyzer on changed source files
4. Runs the repo test command

If any gate fails, the push is blocked with a clear error message naming the offending file or line.

**Requirements:**

- `gitleaks` in PATH — install from https://github.com/gitleaks/gitleaks/releases
- Python 3.8+ with `presidio-analyzer` and `spacy en_core_web_lg`:
  ```bash
  pip install presidio-analyzer spacy && python -m spacy download en_core_web_lg
  ```

---

## Repo-Specific Test Command

| Repo | Test command |
|------|-------------|
| `forex-bot` | `pytest` |
| `health-data-hub` | `pytest` |
| `task-runner` | `pytest` |
| `finanzflow` | `pytest` |
| `homecortex` | `pytest` |
| `dracolabs` | `make test` *(if target exists)* |
| `infra` | *(no automated test suite — Gate 4 auto-skips)* |
| `task-sync` | *(no automated test suite — Gate 4 auto-skips)* |
| `tailscale-clients` | *(no automated test suite — Gate 4 auto-skips)* |
| `headscale-server` | *(no automated test suite — Gate 4 auto-skips)* |
| `mercedes-assistant` | *(no automated test suite — Gate 4 auto-skips)* |

---

## Questions?

Open an issue or reach out to Stark directly.
