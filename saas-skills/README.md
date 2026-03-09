# SaaS Skills

SaaS-specific business logic patterns that no open-source repo provides. These encode your product's unique conventions for feature flags, billing, rate limiting, onboarding, and API documentation.

## Skills

| Skill | Source | Status | Description |
|-------|--------|--------|-------------|
| feature-flags | Custom | ✍️ Custom | Feature flag lifecycle, targeting, rollouts |
| billing-stripe | Custom | ✍️ Custom | Stripe subscription and usage-based billing |
| rate-limiting | Custom | ✍️ Custom | Token bucket, tier-based API rate limits |
| user-onboarding | Custom | ✍️ Custom | Signup flow, activation metrics, onboarding UX |
| api-documentation | Custom | ✍️ Custom | OpenAPI/Swagger generation and developer portal |

Each skill includes a `references/` subfolder for project-specific configuration (flag naming, tier limits, onboarding steps, etc.).

## Install

```bash
./install.sh saas-skills /path/to/your-project
./install.sh saas-skills /path/to/your-project feature-flags
```
