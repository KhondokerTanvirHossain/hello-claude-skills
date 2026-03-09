# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A multi-platform AI skills library for a developer productivity SaaS product. Skills are organized across 7 domains and can be installed into target project repos for use with Claude Code, Cursor, Codex, and Gemini CLI.

## Current Status

- **Total skills:** 98 across 7 domains
- **Populated:** 72 (20 custom hand-written + 52 from open-source repos)
- **Remaining placeholders:** 26 (empty dirs with `.gitkeep`)
- **Open-source sources:** 17 GitHub repos cloned via `populate-skills.sh`

## Tech Stack Context

Skills are written for this stack:
- **Frontend:** React + TypeScript
- **Backend:** Java 21 + Spring Boot 3.x + Gradle (NOT Maven)
- **Database:** PostgreSQL
- **Infrastructure:** Docker, GitHub Actions
- **Architecture:** Microservices, Clean Architecture, DDD, BFF pattern

## Repository Structure

```
├── product-skills/       # Product management (13 skills: 11 populated, 2 placeholders)
├── uiux-skills/          # UI/UX design (9 skills: 8 populated, 1 placeholder)
├── frontend-skills/      # React + TypeScript (15 skills: 12 populated, 3 placeholders)
├── backend-skills/       # Java + Spring Boot (24 skills: 21 populated, 3 placeholders)
├── platform-skills/      # DevOps, CI/CD, security (22 skills: 12 populated, 10 placeholders)
├── marketing-skills/     # Developer marketing (10 skills: 3 populated, 7 placeholders)
├── saas-skills/          # SaaS business logic (5 skills: 5 populated, 0 placeholders)
├── install.sh            # Install skills into a target project
├── sync-platforms.sh     # Create IDE platform symlinks
└── populate-skills.sh    # Clone open-source skills from source repos
```

Each domain has: `README.md` (skill inventory) + `skills/` directory containing skill subdirectories.

## Skill Types

- **✍️ Custom** — 20 hand-written SKILL.md files tailored to our stack. These have full content.
- **✅ Populated** — 52 skills copied from open-source repos via `populate-skills.sh`.
- **🔲 Placeholder** — 26 empty directories with `.gitkeep`. No matching open-source source found.

## Key Scripts

```bash
# Install all skills from a domain into a target project
./install.sh backend-skills /path/to/your-project

# Install a specific skill
./install.sh backend-skills /path/to/your-project gradle-spring-conventions

# Populate placeholder skills from open-source repos
./populate-skills.sh

# Create IDE symlinks (skills/ → .claude/skills/, .cursor/skills/, etc.)
./sync-platforms.sh
```

## SKILL.md Format

Every custom skill follows this structure:
```yaml
---
name: skill-name
description: |
  One-line description.
  Trigger: "keyword1", "keyword2"
---
```
Followed by markdown sections: Purpose, When to Use, Workflow/Rules, Examples.

## Conventions

- Skill directories use kebab-case
- Each domain's README.md has a table listing all skills with Source and Status columns
- `saas-skills` skills have `references/` subfolders with project-specific config templates
- Platform targets: `.claude/skills/`, `.cursor/skills/`, `.codex/skills/`, `.gemini/skills/`

## Open-Source Skill Sources

The `populate-skills.sh` script clones from these 17 repos:

| Repo | Domain(s) | Skills Provided |
|------|-----------|-----------------|
| OthmanAdi/planning-with-files | product | planning-with-files |
| deanpeters/Product-Manager-Skills | product | prd-development, user-story, epic-hypothesis, prioritization-advisor, roadmap-planning, discovery-interview-prep, positioning-statement |
| levnikolaevich/claude-code-skills | product, backend | epic-coordinator |
| automazeio/ccpm | product | (path mismatch — placeholder) |
| addyosmani/web-quality-skills | uiux, frontend | accessibility, best-practices, performance, core-web-vitals, seo |
| dralgorhythm/claude-agentic-framework | uiux, frontend, backend, platform | brainstorming, design-md, platform-design, TDD, implementing-code, debugging, refactoring-code, dependency-management, optimizing-code, systematic-debugging, defense-in-depth, owasp-security, vibesec |
| lackeyjb/playwright-skill | frontend | playwright-skill |
| Jeffallan/claude-skills | frontend, backend, platform | react-best-practices, webapp-testing, java-architect, postgresql, databases, software-architecture, code-quality-checker, test-executor, devops-engineer |
| decebals/claude-code-java | backend | spring-boot-patterns, jpa-patterns, java-migration, logging-patterns, solid-principles, design-patterns, clean-code |
| giuseppe-trisciuoglio/developer-kit | backend | (path mismatch — placeholder) |
| aidankinzett/claude-git-pr-skill | platform | github-pr-review |
| hashicorp/agent-skills | platform | terraform-style-guide, terraform-test |
| snyk/studio-recipes | platform | (nested path mismatch — placeholder) |
| snyk-labs/snyk-learning-path-skill | platform | (repo unavailable — placeholder) |
| wshobson/agents | frontend, platform | frontend-design, incident-runbook-templates, github-actions-templates |
| AgriciDaniel/claude-seo | marketing | claude-seo |
| smixs/creative-director-skill | marketing | creative-director |

## Remaining Placeholders (26 TODOs)

These need custom SKILL.md files written or alternative sources found:

### High Priority — Write Custom
Skills that are core to our stack and should be hand-written:
- `backend-skills/clean-architecture` — Clean Architecture patterns for Java/Spring
- `backend-skills/task-executor` — Task execution patterns
- `backend-skills/task-reviewer` — Code review automation
- `frontend-skills/shadcn-ui` — shadcn/ui component patterns for React
- `frontend-skills/react-components` — React component best practices
- `platform-skills/finishing-dev-branch` — Branch completion workflow
- `platform-skills/requesting-code-review` — PR review request workflow
- `platform-skills/gitops-workflow` — GitOps patterns
- `platform-skills/github-automation` — GitHub API automation

### Medium Priority — Write Custom or Find Source
- `product-skills/scope-decomposer` — Breaking epics into stories
- `product-skills/prd-to-epic-pipeline` — PRD-to-epic conversion
- `uiux-skills/enhance-prompt` — Prompt enhancement for design
- `frontend-skills/stitch-loop` — Component stitching patterns
- `platform-skills/git-pushing` — Safe push workflows
- `platform-skills/root-cause-tracing` — Root cause analysis
- `platform-skills/cost-optimization` — Cloud cost optimization
- `marketing-skills/content-research-writer` — Content research and writing
- `marketing-skills/devmarketing-skills` — Developer marketing playbook

### Lower Priority — Consider Removing
- `platform-skills/devops` — Overlaps significantly with `devops-engineer`
- `platform-skills/snyk-fix` — Snyk-specific, may not be needed
- `platform-skills/snyk-learning-path` — Source repo no longer available
- `marketing-skills/avoid-ai-writing` — Niche topic
- `marketing-skills/domain-brainstormer` — Domain name brainstorming
- `marketing-skills/twitter-optimizer` — Platform-specific
- `marketing-skills/email-marketing-bible` — Source repo unavailable
- `marketing-skills/competitive-ads-extractor` — Niche topic
