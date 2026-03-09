# Feature Flag Naming Convention

## Naming Format

```
<domain>-<feature>-<variant?>
```

All flag names use **kebab-case**. No underscores, no camelCase, no SCREAMING_CASE.

## Domain Prefixes

Every flag MUST start with a domain prefix to group related flags:

| Prefix | Domain | Examples |
|--------|--------|----------|
| `billing-` | Payments, subscriptions, invoicing | `billing-annual-plans`, `billing-usage-metering` |
| `onboarding-` | Signup, activation, first-run | `onboarding-checklist-v2`, `onboarding-skip-workspace` |
| `api-` | API features, rate limits, versioning | `api-v2-endpoints`, `api-cursor-pagination` |
| `ui-` | Frontend components, layouts | `ui-dark-mode`, `ui-sidebar-redesign` |
| `auth-` | Authentication, authorization | `auth-sso-google`, `auth-mfa-totp` |
| `infra-` | Infrastructure, performance | `infra-redis-cache`, `infra-read-replicas` |
| `notif-` | Notifications, emails, webhooks | `notif-slack-integration`, `notif-digest-emails` |
| `exp-` | Experiments, A/B tests | `exp-pricing-page-v3`, `exp-signup-flow-b` |

## Flag Types

Each flag has a type that determines its behavior and lifecycle:

### Release Flags

Gradually roll out new features. Short-lived -- remove after 100% rollout.

```yaml
name: billing-annual-plans
type: release
description: "Enable annual billing plan selection on pricing page"
default: false
rollout:
  strategy: percentage  # percentage | user-segment | allowlist
  percentage: 25
```

### Experiment Flags

A/B tests with measurable outcomes. Always have a hypothesis and end date.

```yaml
name: exp-pricing-page-v3
type: experiment
description: "Test simplified pricing page layout"
hypothesis: "Reducing plan options from 5 to 3 increases conversion by 10%"
variants:
  - control    # existing 5-plan layout
  - treatment  # new 3-plan layout
metric: pricing-page-conversion-rate
end_date: 2026-04-15
```

### Operational Flags

Circuit breakers and kill switches. Long-lived. Used for graceful degradation.

```yaml
name: infra-redis-cache
type: operational
description: "Enable Redis caching layer for API responses"
default: true
kill_switch: true  # can be disabled without deploy
```

### Permission Flags

Gate features by subscription tier or user role. Long-lived.

```yaml
name: billing-advanced-analytics
type: permission
description: "Access to advanced analytics dashboard"
tiers: [pro, enterprise]
default: false
```

## Lifecycle Stages

Every flag progresses through these stages:

```
development --> testing --> production --> archived
```

| Stage | Description | Who Can Toggle | Duration |
|-------|-------------|----------------|----------|
| `development` | Created in code, local testing only | Developer | Until PR merged |
| `testing` | Available in staging, QA validation | Dev + QA | Until sign-off |
| `production` | Live rollout, monitoring active | Dev + Ops + PM | Until 100% or experiment ends |
| `archived` | Disabled, code removal scheduled | Nobody | Max 2 sprints before deletion |

## Cleanup Policy

Stale flags create technical debt. Follow this policy strictly.

### Automatic Alerts

| Condition | Action |
|-----------|--------|
| Release flag at 100% for > 7 days | Slack alert to flag owner |
| Experiment flag past `end_date` | Slack alert + JIRA ticket created |
| Any flag in `production` > 90 days | Weekly digest to team lead |
| Any flag in `archived` > 14 days | CI build warning |

### Cleanup Checklist

When removing a flag:

1. Verify flag is at 100% rollout (release) or experiment concluded
2. Remove all conditional checks from application code
3. Remove flag definition from configuration
4. Remove flag from monitoring dashboards
5. Update any documentation referencing the flag
6. Create a single PR titled: `chore: remove flag <flag-name>`

### Spring Boot Flag Configuration

Store flags in `application.yml` for local development:

```yaml
# application.yml
feature-flags:
  billing-annual-plans:
    enabled: false
    type: release
    owner: billing-team
    created: 2026-02-15
  exp-pricing-page-v3:
    enabled: false
    type: experiment
    owner: growth-team
    created: 2026-03-01
    end-date: 2026-04-15
```

### Flag Evaluation Service

```java
@Service
public class FeatureFlagService {

    private final FeatureFlagRepository flagRepository;
    private final SubscriptionService subscriptionService;

    /**
     * Evaluate a flag for the given context.
     * Order of precedence:
     *   1. User-level override (allowlist)
     *   2. Tier-based permission
     *   3. Percentage rollout
     *   4. Default value
     */
    public boolean isEnabled(String flagName, FlagContext context) {
        FeatureFlag flag = flagRepository.findByName(flagName)
            .orElseThrow(() -> new FlagNotFoundException(flagName));

        if (flag.getStage() == FlagStage.ARCHIVED) {
            return false;
        }

        // 1. Check user-level override
        if (flag.getAllowlist().contains(context.getUserId())) {
            return true;
        }

        // 2. Check tier-based permission
        if (flag.getType() == FlagType.PERMISSION) {
            var tier = subscriptionService.getTier(context.getTenantId());
            return flag.getAllowedTiers().contains(tier);
        }

        // 3. Check percentage rollout
        if (flag.getRolloutPercentage() > 0) {
            int bucket = Math.abs(context.getUserId().hashCode() % 100);
            return bucket < flag.getRolloutPercentage();
        }

        return flag.isDefaultEnabled();
    }
}
```

## Anti-Patterns

| Anti-Pattern | Why It Is Bad | Do This Instead |
|-------------|---------------|-----------------|
| `enableNewBilling` | camelCase, no domain prefix | `billing-new-checkout` |
| `temp_flag_123` | No description, meaningless name | `ui-sidebar-redesign` |
| `FEATURE_X` | SCREAMING_CASE, vague | `api-batch-endpoints` |
| Flag without type | No lifecycle tracking possible | Always assign a type |
| Nesting flags | `if flagA && flagB` creates combinatorial explosion | One flag per decision point |
| Reusing old flag names | Stale data pollutes analytics | Always use fresh names |

## Database Schema

```sql
CREATE TABLE feature_flags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100) NOT NULL UNIQUE,
    type            VARCHAR(20)  NOT NULL CHECK (type IN ('release', 'experiment', 'operational', 'permission')),
    stage           VARCHAR(20)  NOT NULL DEFAULT 'development'
                        CHECK (stage IN ('development', 'testing', 'production', 'archived')),
    description     TEXT NOT NULL,
    default_enabled BOOLEAN NOT NULL DEFAULT false,
    rollout_pct     INT NOT NULL DEFAULT 0 CHECK (rollout_pct BETWEEN 0 AND 100),
    allowed_tiers   TEXT[] DEFAULT '{}',
    allowlist       TEXT[] DEFAULT '{}',
    owner           VARCHAR(100) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date        DATE,
    metadata        JSONB DEFAULT '{}'
);

CREATE INDEX idx_flags_name  ON feature_flags(name);
CREATE INDEX idx_flags_stage ON feature_flags(stage);
CREATE INDEX idx_flags_type  ON feature_flags(type);
```
