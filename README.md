# Claude Skills Library — Developer Productivity SaaS

A curated, multi-platform skills library for AI-assisted development. Organized by domain, designed to be copied into your product repos when needed.

**Stack:** React + TypeScript | Java 21 + Spring Boot 3.x (Gradle) | PostgreSQL | Docker | GitHub Actions
**Architecture:** Microservices, Clean Architecture, DDD, BFF Pattern

## Domains

| Domain | Total | Populated | Placeholders | Purpose |
|--------|-------|-----------|--------------|---------|
| [product-skills](./product-skills/) | 13 | 11 | 2 | PRD development, user stories, roadmap planning, market research |
| [uiux-skills](./uiux-skills/) | 9 | 8 | 1 | Accessibility, design systems, UX audits, wireframe-to-spec |
| [frontend-skills](./frontend-skills/) | 15 | 12 | 3 | React patterns, performance, testing, BFF, state management |
| [backend-skills](./backend-skills/) | 24 | 21 | 3 | Java/Spring Boot, DDD, microservices, PostgreSQL, engineering practices |
| [platform-skills](./platform-skills/) | 22 | 12 | 10 | CI/CD, Git workflows, Terraform, security, debugging |
| [marketing-skills](./marketing-skills/) | 10 | 3 | 7 | SEO, content writing, landing pages, developer marketing |
| [saas-skills](./saas-skills/) | 5 | 5 | 0 | Feature flags, billing, rate limiting, onboarding, API docs |

**Total: 98 skills** — 72 populated (20 custom + 52 open-source), 26 remaining placeholders

## Quick Start

### Install skills into your project

```bash
# Install a specific skill
./install.sh backend-skills /path/to/my-project gradle-spring-conventions

# Install from a domain interactively
./install.sh frontend-skills /path/to/my-project

# Install into current directory
./install.sh backend-skills .
```

### First-time setup (populate open-source skills)

```bash
git clone git@github.com:KhondokerTanvirHossain/hello-claude-skills.git
cd hello-claude-skills

# Clone and copy all open-source skills
./populate-skills.sh

# Review copied skills for security, then commit
git add . && git commit -m "feat: populate open-source skills"
```

## All Skills

### product-skills (11 populated, 2 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| planning-with-files | OthmanAdi/planning-with-files | ✅ Populated |
| prd-development | deanpeters/Product-Manager-Skills | ✅ Populated |
| user-story | deanpeters/Product-Manager-Skills | ✅ Populated |
| epic-hypothesis | deanpeters/Product-Manager-Skills | ✅ Populated |
| prioritization-advisor | deanpeters/Product-Manager-Skills | ✅ Populated |
| roadmap-planning | deanpeters/Product-Manager-Skills | ✅ Populated |
| discovery-interview-prep | deanpeters/Product-Manager-Skills | ✅ Populated |
| positioning-statement | deanpeters/Product-Manager-Skills | ✅ Populated |
| epic-coordinator | levnikolaevich/claude-code-skills | ✅ Populated |
| devtool-market-research | Custom | ✍️ Custom |
| saas-competitor-analysis | Custom | ✍️ Custom |
| scope-decomposer | levnikolaevich/claude-code-skills | 🔲 Placeholder |
| prd-to-epic-pipeline | automazeio/ccpm | 🔲 Placeholder |

### uiux-skills (8 populated, 1 placeholder)

| Skill | Source | Status |
|-------|--------|--------|
| accessibility | addyosmani/web-quality-skills | ✅ Populated |
| best-practices | addyosmani/web-quality-skills | ✅ Populated |
| brainstorming | dralgorhythm/claude-agentic-framework | ✅ Populated |
| design-md | dralgorhythm/claude-agentic-framework | ✅ Populated |
| platform-design | dralgorhythm/claude-agentic-framework | ✅ Populated |
| design-system | Custom | ✍️ Custom |
| ux-audit | Custom | ✍️ Custom |
| wireframe-to-spec | Custom | ✍️ Custom |
| enhance-prompt | google-labs-code | 🔲 Placeholder |

### frontend-skills (12 populated, 3 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| performance | addyosmani/web-quality-skills | ✅ Populated |
| core-web-vitals | addyosmani/web-quality-skills | ✅ Populated |
| seo | addyosmani/web-quality-skills | ✅ Populated |
| test-driven-development | dralgorhythm/claude-agentic-framework | ✅ Populated |
| implementing-code | dralgorhythm/claude-agentic-framework | ✅ Populated |
| playwright-skill | lackeyjb/playwright-skill | ✅ Populated |
| react-best-practices | Jeffallan/claude-skills | ✅ Populated |
| webapp-testing | Jeffallan/claude-skills | ✅ Populated |
| frontend-design | wshobson/agents | ✅ Populated |
| bff-patterns | Custom | ✍️ Custom |
| state-management | Custom | ✍️ Custom |
| api-client-patterns | Custom | ✍️ Custom |
| shadcn-ui | — | 🔲 Placeholder |
| react-components | — | 🔲 Placeholder |
| stitch-loop | — | 🔲 Placeholder |

### backend-skills (21 populated, 3 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| java-architect | Jeffallan/claude-skills | ✅ Populated |
| spring-boot-patterns | decebals/claude-code-java | ✅ Populated |
| jpa-patterns | decebals/claude-code-java | ✅ Populated |
| java-migration | decebals/claude-code-java | ✅ Populated |
| logging-patterns | decebals/claude-code-java | ✅ Populated |
| solid-principles | decebals/claude-code-java | ✅ Populated |
| design-patterns | decebals/claude-code-java | ✅ Populated |
| clean-code | decebals/claude-code-java | ✅ Populated |
| software-architecture | Jeffallan/claude-skills | ✅ Populated |
| postgresql | Jeffallan/claude-skills | ✅ Populated |
| databases | Jeffallan/claude-skills | ✅ Populated |
| code-quality-checker | Jeffallan/claude-skills | ✅ Populated |
| test-executor | Jeffallan/claude-skills | ✅ Populated |
| debugging | dralgorhythm/claude-agentic-framework | ✅ Populated |
| refactoring-code | dralgorhythm/claude-agentic-framework | ✅ Populated |
| dependency-management | dralgorhythm/claude-agentic-framework | ✅ Populated |
| optimizing-code | dralgorhythm/claude-agentic-framework | ✅ Populated |
| gradle-spring-conventions | Custom | ✍️ Custom |
| ddd-your-project | Custom | ✍️ Custom |
| microservice-boundaries | Custom | ✍️ Custom |
| api-design-conventions | Custom | ✍️ Custom |
| task-executor | levnikolaevich/claude-code-skills | 🔲 Placeholder |
| task-reviewer | levnikolaevich/claude-code-skills | 🔲 Placeholder |
| clean-architecture | giuseppe-trisciuoglio/developer-kit | 🔲 Placeholder |

### platform-skills (12 populated, 10 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| github-pr-review | aidankinzett/claude-git-pr-skill | ✅ Populated |
| devops-engineer | Jeffallan/claude-skills | ✅ Populated |
| terraform-style-guide | hashicorp/agent-skills | ✅ Populated |
| terraform-test | hashicorp/agent-skills | ✅ Populated |
| systematic-debugging | dralgorhythm/claude-agentic-framework | ✅ Populated |
| defense-in-depth | dralgorhythm/claude-agentic-framework | ✅ Populated |
| owasp-security | dralgorhythm/claude-agentic-framework | ✅ Populated |
| vibesec | dralgorhythm/claude-agentic-framework | ✅ Populated |
| incident-runbook-templates | wshobson/agents | ✅ Populated |
| github-actions-templates | wshobson/agents | ✅ Populated |
| ci-cd-pipeline | Custom | ✍️ Custom |
| git-branching-strategy | Custom | ✍️ Custom |
| devops | — | 🔲 Placeholder |
| finishing-dev-branch | — | 🔲 Placeholder |
| git-pushing | — | 🔲 Placeholder |
| gitops-workflow | — | 🔲 Placeholder |
| github-automation | — | 🔲 Placeholder |
| requesting-code-review | — | 🔲 Placeholder |
| root-cause-tracing | — | 🔲 Placeholder |
| cost-optimization | — | 🔲 Placeholder |
| snyk-fix | snyk/studio-recipes | 🔲 Placeholder |
| snyk-learning-path | snyk-labs (repo unavailable) | 🔲 Placeholder |

### marketing-skills (3 populated, 7 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| claude-seo | AgriciDaniel/claude-seo | ✅ Populated |
| creative-director | smixs/creative-director-skill | ✅ Populated |
| saas-landing-page | Custom | ✍️ Custom |
| content-research-writer | — | 🔲 Placeholder |
| avoid-ai-writing | — | 🔲 Placeholder |
| domain-brainstormer | — | 🔲 Placeholder |
| devmarketing-skills | — | 🔲 Placeholder |
| twitter-optimizer | — | 🔲 Placeholder |
| email-marketing-bible | CosmoBlk (repo unavailable) | 🔲 Placeholder |
| competitive-ads-extractor | — | 🔲 Placeholder |

### saas-skills (5 populated, 0 placeholders)

| Skill | Source | Status |
|-------|--------|--------|
| feature-flags | Custom | ✍️ Custom |
| billing-stripe | Custom | ✍️ Custom |
| rate-limiting | Custom | ✍️ Custom |
| user-onboarding | Custom | ✍️ Custom |
| api-documentation | Custom | ✍️ Custom |

## Remaining Placeholders (26)

These skills have empty directories with `.gitkeep` files. No matching open-source source was found during population.

### Options for each placeholder

| Option | Description |
|--------|-------------|
| **Write custom** | Create a hand-written SKILL.md tailored to our stack |
| **Find new source** | Search for a new open-source repo that covers the topic |
| **Remove** | Delete the placeholder if the skill isn't needed |
| **Leave** | Keep as placeholder for future work |

### By domain

**product-skills** (2 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| scope-decomposer | Source repo structure didn't match expected path | Find new source or write custom |
| prd-to-epic-pipeline | automazeio/ccpm repo structure didn't match | Find new source or write custom |

**uiux-skills** (1 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| enhance-prompt | google-labs-code repo not in our clone list | Find new source or write custom |

**frontend-skills** (3 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| shadcn-ui | No open-source skill repo found for shadcn/ui patterns | Write custom |
| react-components | google-labs-code repo not in our clone list | Write custom |
| stitch-loop | google-labs-code repo not in our clone list | Find new source |

**backend-skills** (3 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| task-executor | Source repo (levnikolaevich) didn't have matching skill | Write custom |
| task-reviewer | Source repo (levnikolaevich) didn't have matching skill | Write custom |
| clean-architecture | giuseppe-trisciuoglio/developer-kit didn't have matching skill | Write custom |

**platform-skills** (10 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| devops | General DevOps skill, no specific source matched | Write custom or remove (overlaps with devops-engineer) |
| finishing-dev-branch | obra/superpowers repo not in our clone list | Write custom |
| git-pushing | Community skill, no source repo found | Write custom |
| gitops-workflow | wshobson/agents didn't have matching skill | Write custom |
| github-automation | General GitHub automation, no specific source | Write custom |
| requesting-code-review | obra/superpowers repo not in our clone list | Write custom |
| root-cause-tracing | obra/superpowers repo not in our clone list | Write custom |
| cost-optimization | wshobson/agents didn't have matching skill | Write custom |
| snyk-fix | snyk/studio-recipes had different nested structure | Find new source |
| snyk-learning-path | snyk-labs repo unavailable (404 or renamed) | Remove or find alternative |

**marketing-skills** (7 remaining)
| Skill | Notes | Recommended |
|-------|-------|-------------|
| content-research-writer | Community skill, no source repo | Write custom |
| avoid-ai-writing | Community skill, no source repo | Write custom |
| domain-brainstormer | ComposioHQ, no matching skill in repo | Write custom |
| devmarketing-skills | Community skill, no source repo | Write custom |
| twitter-optimizer | Community skill, no source repo | Write custom |
| email-marketing-bible | CosmoBlk repo unavailable | Find new source or write custom |
| competitive-ads-extractor | ComposioHQ, no matching skill in repo | Write custom |

## Adding New Skills

1. Create a folder under the appropriate domain: `<domain>/skills/<skill-name>/`
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`)
3. Optionally add a `references/` subfolder for supporting docs
4. Run `./sync-platforms.sh` to create IDE symlinks
5. Use `./install.sh <domain> <target> <skill-name>` to install into a project

## Multi-Platform Support

Skills are written once and work across all supported AI coding tools:

| Platform | Skill Location | Tool |
|----------|---------------|------|
| Claude Code | `.claude/skills/` | claude.ai/code |
| Cursor | `.cursor/skills/` | cursor.com |
| Codex | `.codex/skills/` | OpenAI Codex |
| Gemini CLI | `.gemini/skills/` | Google Gemini |

Run `./sync-platforms.sh` to create symlinks from the canonical `skills/` directory into all platform directories.

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Copy skills from this library into a target project |
| `sync-platforms.sh` | Create symlinks for all IDE platforms |
| `populate-skills.sh` | Clone open-source repos and populate placeholder skills |

## License

MIT
