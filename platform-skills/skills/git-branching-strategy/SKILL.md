---
name: git-branching-strategy
description: Git branching model and workflow conventions for a SaaS product team including branch naming, commit message format, PR requirements, and release management
version: 1.0.0
tags:
  - git
  - branching
  - workflow
  - pull-requests
  - release-management
globs:
  - ".github/pull_request_template.md"
  - ".github/CODEOWNERS"
  - "CONTRIBUTING.md"
  - ".releaserc.*"
  - ".commitlintrc.*"
---

# Git Branching Strategy

## Purpose

Define the git branching model, commit conventions, pull request requirements, and release management process for a SaaS product built with React + TypeScript frontend and Java 21 + Spring Boot 3.x microservices. This strategy optimizes for continuous delivery, small batch sizes, and a clean commit history while supporting a team of multiple developers working across frontend and backend services.

## When to Use

- Starting work on a new feature, bug fix, or chore
- Writing commit messages
- Creating or reviewing pull requests
- Cutting a release or deploying a hotfix
- Configuring branch protection rules for a new repository
- Onboarding a new developer to the team's git workflow
- Resolving merge conflicts or deciding on merge strategy

## Branching Model: Scaled Trunk-Based Development

Use scaled trunk-based development with short-lived feature branches. This is preferred over GitFlow for SaaS products because:

- SaaS does not ship versioned binaries to customers, so `develop`/`release` branch overhead is unnecessary.
- Short-lived branches (1-3 days) reduce merge conflicts and integration risk.
- Feature flags handle incomplete work, not long-lived branches.
- The `main` branch is always deployable.

### Branch Hierarchy

```
main                            # Always deployable. Protected. Linear history.
  feature/PROJ-123-user-auth    # Short-lived. 1-3 days max. Deleted after merge.
  fix/PROJ-456-login-timeout    # Bug fix branch. Same lifecycle as feature.
  chore/PROJ-789-upgrade-java   # Non-functional changes. Same lifecycle.
  release/2.3.0                 # Created only when a release is cut. Read-only after creation.
  hotfix/PROJ-999-critical-fix  # Emergency fix branched from the release tag.
```

## Rules

### 1. Branch Naming Convention

All branches must follow this format: `{type}/{ticket-id}-{short-description}`

| Type | Usage | Example |
|---|---|---|
| `feature/` | New functionality or user-facing capability | `feature/PROJ-123-user-onboarding` |
| `fix/` | Bug fix for an existing feature | `fix/PROJ-456-payment-rounding-error` |
| `chore/` | Tooling, dependency updates, refactoring (no user-facing change) | `chore/PROJ-789-spring-boot-3.4` |
| `docs/` | Documentation-only changes | `docs/PROJ-101-api-rate-limit-guide` |
| `release/` | Release preparation branch | `release/2.3.0` |
| `hotfix/` | Emergency production fix | `hotfix/PROJ-999-null-pointer-checkout` |

Rules:
- The ticket ID is mandatory. Every branch must trace to a Jira/Linear/GitHub issue.
- Use lowercase kebab-case for the description.
- Keep the description under 40 characters.
- Never use personal names or dates in branch names.
- Delete branches immediately after merge. Configure auto-delete in GitHub repository settings.

### 2. Conventional Commits

All commit messages must follow the Conventional Commits specification. This enables automated changelog generation and semantic versioning.

#### Format

```
{type}({scope}): {subject}

{body}

{footer}
```

#### Types

| Type | Description | Bumps |
|---|---|---|
| `feat` | A new feature visible to the end user | MINOR |
| `fix` | A bug fix visible to the end user | PATCH |
| `perf` | A performance improvement | PATCH |
| `refactor` | Code restructuring with no behavior change | none |
| `test` | Adding or updating tests only | none |
| `docs` | Documentation changes only | none |
| `chore` | Build process, dependency updates, tooling | none |
| `ci` | CI/CD pipeline changes | none |
| `style` | Code style changes (formatting, semicolons) | none |
| `revert` | Reverts a previous commit | varies |

#### Scope

The scope identifies the affected service or module:

- Backend services: `user-service`, `billing-service`, `notification-service`, `analytics-service`, `api-gateway`
- Frontend: `frontend`, `ui`, `dashboard`
- Shared: `shared-kernel`, `api-contracts`
- Infrastructure: `docker`, `k8s`, `ci`

#### Subject Line Rules

- Use imperative mood: "add user export endpoint" not "added user export endpoint"
- Do not capitalize the first letter
- Do not end with a period
- Maximum 72 characters
- Reference the ticket in the footer, not the subject

#### Footer

Use `Refs:` for issue references and `BREAKING CHANGE:` for breaking changes.

```
feat(billing-service): add prorated billing for plan upgrades

Implement prorated billing calculation when a user upgrades
their subscription plan mid-cycle. Uses the day-based proration
method aligned with Stripe's proration behavior.

Refs: PROJ-234
```

```
feat(api-gateway)!: migrate authentication from session to JWT

Replace server-side session authentication with stateless JWT tokens
across all BFF endpoints. Existing session cookies will be invalidated
on next deployment.

BREAKING CHANGE: All API consumers must include a Bearer token in the
Authorization header. Session-based authentication is no longer supported.
Refs: PROJ-567
```

### 3. Commit Linting

Enforce conventional commits with commitlint. Add this configuration at the repository root.

```json
// .commitlintrc.json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "scope-enum": [2, "always", [
      "user-service",
      "billing-service",
      "notification-service",
      "analytics-service",
      "api-gateway",
      "frontend",
      "shared-kernel",
      "api-contracts",
      "docker",
      "k8s",
      "ci"
    ]],
    "subject-max-length": [2, "always", 72],
    "body-max-line-length": [2, "always", 100]
  }
}
```

Run commitlint as a Git hook via Husky (frontend) or as a CI check (backend).

### 4. Pull Request Requirements

Every change enters `main` through a pull request. Direct pushes to `main` are blocked.

#### PR Title

The PR title must follow the same conventional commit format as commit messages. When squash merging, the PR title becomes the merge commit message.

```
feat(user-service): add email verification on signup
```

#### PR Template

Use this template at `.github/pull_request_template.md`:

```markdown
## Summary

<!-- What does this PR do and why? Link the ticket. -->

Refs: PROJ-XXX

## Type of Change

- [ ] Feature (new functionality)
- [ ] Bug fix (non-breaking fix for an issue)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Chore (refactoring, dependency update, tooling)
- [ ] Documentation

## Changes

<!-- Bullet list of specific changes -->

-

## Testing

<!-- How was this tested? Include commands, screenshots, or test output. -->

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated (if applicable)
- [ ] Manual testing performed

## Checklist

- [ ] My code follows the project coding conventions
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally
- [ ] I have updated documentation where necessary
- [ ] I have verified there are no breaking changes (or documented them above)
- [ ] My branch is up to date with main
```

#### Review Requirements

| Target Branch | Required Approvals | Required Checks |
|---|---|---|
| `main` | 1 minimum (2 for services with > 1000 lines changed) | CI pass, lint, type check, tests |
| `release/*` | 2 minimum | Full CI + integration tests |
| Any | 0 (draft PRs have no requirements) | None |

#### CODEOWNERS

Define ownership per service directory to auto-assign reviewers:

```
# .github/CODEOWNERS
services/user-service/        @backend-team @user-domain-owner
services/billing-service/     @backend-team @billing-domain-owner
services/api-gateway-bff/     @backend-team @frontend-team
frontend/                     @frontend-team
libs/shared-kernel/           @backend-team @platform-lead
.github/                      @platform-team
```

### 5. Merge Strategy

Use **squash merge** for feature, fix, and chore branches into `main`. This produces a clean, linear history where each commit on `main` represents one complete unit of work.

Configure in GitHub repository settings:
- Allow squash merging: **enabled**
- Allow merge commits: **disabled**
- Allow rebase merging: **disabled**
- Default commit message: **PR title and description**
- Auto-delete head branches: **enabled**

Exception: Release branches use a **merge commit** (not squash) to preserve the full history of what was included in the release.

### 6. Release Process

#### Cutting a Release

1. Ensure `main` is green and all desired features are merged.
2. Create a release branch from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b release/2.3.0
   git push origin release/2.3.0
   ```
3. On the release branch, update version numbers if needed (e.g., `gradle.properties`, `package.json`).
4. Open a PR from `release/2.3.0` to `main` for final review.
5. After approval and merge, tag the merge commit:
   ```bash
   git checkout main
   git pull origin main
   git tag -a v2.3.0 -m "Release 2.3.0"
   git push origin v2.3.0
   ```
6. The tag triggers the CI/CD pipeline to build, publish Docker images with the release version, and deploy through dev -> staging -> production.

#### Release Tag Format

- Production releases: `v{major}.{minor}.{patch}` (e.g., `v2.3.0`)
- Pre-releases: `v{major}.{minor}.{patch}-rc.{n}` (e.g., `v2.3.0-rc.1`)

Use annotated tags (`git tag -a`), not lightweight tags. Include a summary of changes in the tag message.

### 7. Hotfix Process

Hotfixes bypass the normal feature branch flow when a critical production issue requires immediate resolution.

1. Branch from the production release tag:
   ```bash
   git checkout v2.3.0
   git checkout -b hotfix/PROJ-999-critical-null-pointer
   ```
2. Fix the issue. Commit with `fix(scope): description`.
3. Open a PR targeting `main`.
4. After merge, tag the new patch release:
   ```bash
   git tag -a v2.3.1 -m "Hotfix: critical null pointer in checkout flow"
   git push origin v2.3.1
   ```
5. The tag triggers the expedited deployment pipeline (dev -> staging -> production, with required reviewer on each promotion).

A hotfix must also be merged into any active `release/*` branches to prevent regression.

### 8. Branch Protection Rules

Configure these branch protection rules for `main`:

| Rule | Setting |
|---|---|
| Require pull request before merging | Enabled |
| Required approvals | 1 |
| Dismiss stale reviews on new push | Enabled |
| Require review from CODEOWNERS | Enabled |
| Require status checks to pass | Enabled |
| Required checks | `ci-backend`, `ci-frontend`, `commitlint` |
| Require branches to be up to date | Enabled |
| Require linear history | Enabled (squash merges produce linear history) |
| Allow force pushes | Disabled |
| Allow deletions | Disabled |
| Restrict who can push | Platform team only (for emergency) |

### 9. Working with Feature Flags

When a feature takes longer than 3 days, it must be developed behind a feature flag rather than kept on a long-lived branch.

- Merge incomplete work to `main` behind a flag.
- The feature flag configuration lives in the service's application config, not in the code.
- Remove the flag within one sprint after the feature is fully launched.

This approach keeps branches short-lived and reduces merge conflict risk.

## Examples

### Example: Daily Developer Workflow

```bash
# Start new work
git checkout main
git pull origin main
git checkout -b feature/PROJ-345-add-export-csv

# Make changes, commit often with conventional messages
git add -A
git commit -m "feat(analytics-service): add CSV export endpoint for usage reports"

git add -A
git commit -m "test(analytics-service): add integration tests for CSV export"

# Push and open PR
git push -u origin feature/PROJ-345-add-export-csv
# Open PR via GitHub UI or CLI: gh pr create --title "feat(analytics-service): add CSV export endpoint for usage reports"

# After approval, squash merge via GitHub UI
# Branch is auto-deleted
```

### Example: Handling a Merge Conflict

```bash
# Update your branch with latest main
git checkout feature/PROJ-345-add-export-csv
git fetch origin
git rebase origin/main

# Resolve conflicts if any
# After resolving, continue rebase
git rebase --continue

# Force push the rebased branch (safe because it is your feature branch)
git push --force-with-lease origin feature/PROJ-345-add-export-csv
```

Use `--force-with-lease` instead of `--force` to prevent overwriting commits pushed by others.

### Example: Commit Message for a Multi-Service Change

When a change spans multiple services, create separate commits per service:

```bash
git commit -m "feat(api-contracts): add ExportRequest and ExportResponse DTOs

Refs: PROJ-345"

git commit -m "feat(analytics-service): implement CSV export using new API contracts

Refs: PROJ-345"

git commit -m "feat(frontend): add export button to analytics dashboard

Refs: PROJ-345"
```

These will be squashed into a single commit on merge. The PR title should summarize the overall change: `feat(analytics): add CSV export for usage reports`.
