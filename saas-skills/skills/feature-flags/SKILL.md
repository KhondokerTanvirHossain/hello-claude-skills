---
name: feature-flags
description: Feature flag implementation patterns for SaaS products using Spring Boot and React, including flag lifecycle, targeting rules, gradual rollouts, and kill switches
tech_stack:
  - Java 21
  - Spring Boot 3.x
  - React
  - TypeScript
  - PostgreSQL
  - Redis
tags:
  - feature-management
  - rollouts
  - experimentation
  - kill-switch
  - saas
---

# Feature Flag Implementation Patterns

## Purpose

Provide consistent, production-grade patterns for implementing feature flags across the full stack of a SaaS application. This skill covers flag design, backend evaluation, frontend consumption, targeting rules, gradual rollouts, and technical debt management. Feature flags are a critical mechanism for decoupling deployment from release, enabling safe experimentation, and controlling feature access by tenant, plan, or user segment.

## When to Use

- Releasing a new feature to a subset of tenants or users before general availability.
- Running A/B experiments to measure the impact of a change on key business metrics.
- Implementing plan-gated functionality (e.g., "Advanced Analytics" only on Pro tier).
- Adding operational kill switches for expensive or risky code paths.
- Migrating between infrastructure or database implementations with a safety valve.
- Enabling internal dogfooding before external release.
- Managing beta programs where specific customers opt in.

## Flag Naming Conventions

All flag keys MUST follow a structured naming convention to ensure discoverability and lifecycle management.

**Format:** `<type>.<domain>.<flag-name>`

| Segment     | Allowed Values                                       | Example              |
|-------------|------------------------------------------------------|----------------------|
| `type`      | `release`, `experiment`, `ops`, `permission`         | `release`            |
| `domain`    | Bounded context or module name in kebab-case          | `billing`, `analytics` |
| `flag-name` | Descriptive kebab-case name                           | `invoice-pdf-export` |

**Examples:**
- `release.billing.invoice-pdf-export` -- gating a new invoice export feature
- `experiment.onboarding.signup-wizard-v2` -- A/B testing a new signup wizard
- `ops.search.elasticsearch-circuit-breaker` -- kill switch for search subsystem
- `permission.analytics.advanced-dashboards` -- plan-gated analytics feature

## Flag Types

### Release Flags
Temporary flags that gate incomplete or not-yet-announced features. These MUST be removed within 30 days of reaching 100% rollout.

### Experiment Flags
Flags tied to A/B or multivariate experiments. They carry variant assignments and MUST have an associated experiment document with hypothesis, metrics, and success criteria. Remove within 14 days of experiment conclusion.

### Ops Flags
Long-lived operational toggles for circuit breakers, maintenance modes, and infrastructure migration switches. These may persist indefinitely but MUST be reviewed quarterly.

### Permission Flags
Flags that gate features based on subscription plan, tenant entitlements, or role-based access. These are typically long-lived and tied to your pricing/packaging model.

## Workflow: Flag Lifecycle

```
CREATE --> DEVELOP --> TEST --> GRADUAL ROLLOUT --> FULL ROLLOUT --> PERMANENT / CLEANUP
```

### Step 1: Create the Flag

Register the flag in your flag management system (LaunchDarkly, Unleash, or custom) and in code simultaneously. Always define a sensible default (usually `false` for release flags).

**Database schema for custom flag store:**

```sql
CREATE TABLE feature_flags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_key        VARCHAR(128) NOT NULL UNIQUE,
    flag_type       VARCHAR(16) NOT NULL CHECK (flag_type IN ('release', 'experiment', 'ops', 'permission')),
    description     TEXT NOT NULL,
    default_value   BOOLEAN NOT NULL DEFAULT FALSE,
    enabled         BOOLEAN NOT NULL DEFAULT FALSE,
    created_by      VARCHAR(64) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    CONSTRAINT chk_flag_key_format CHECK (flag_key ~ '^(release|experiment|ops|permission)\.[a-z0-9-]+\.[a-z0-9-]+$')
);

CREATE TABLE flag_targeting_rules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_id         UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
    rule_type       VARCHAR(32) NOT NULL CHECK (rule_type IN ('tenant', 'plan', 'user', 'percentage', 'environment')),
    rule_value      JSONB NOT NULL,
    priority        INT NOT NULL DEFAULT 0,
    enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_feature_flags_key ON feature_flags(flag_key);
CREATE INDEX idx_flag_targeting_flag_id ON flag_targeting_rules(flag_id);
```

### Step 2: Spring Boot Backend Integration

**Flag evaluation service:**

```java
@Service
@RequiredArgsConstructor
public class FeatureFlagService {

    private final FeatureFlagRepository flagRepository;
    private final FlagTargetingRuleRepository ruleRepository;
    private final FlagCacheService cacheService;

    public boolean isEnabled(String flagKey, FlagEvaluationContext context) {
        FeatureFlag flag = cacheService.getFlag(flagKey)
            .orElseGet(() -> flagRepository.findByFlagKey(flagKey)
                .orElseThrow(() -> new FlagNotFoundException(flagKey)));

        if (!flag.isEnabled()) {
            return flag.getDefaultValue();
        }

        List<FlagTargetingRule> rules = cacheService.getRules(flag.getId())
            .orElseGet(() -> ruleRepository.findByFlagIdOrderByPriorityDesc(flag.getId()));

        return evaluateRules(rules, context).orElse(flag.getDefaultValue());
    }

    public <T> T getVariant(String flagKey, FlagEvaluationContext context, Class<T> variantType) {
        // For multivariate flags (experiments, permission tiers)
        // Returns typed variant value instead of boolean
    }

    private Optional<Boolean> evaluateRules(List<FlagTargetingRule> rules, FlagEvaluationContext context) {
        for (FlagTargetingRule rule : rules) {
            if (!rule.isEnabled()) continue;

            Optional<Boolean> result = switch (rule.getRuleType()) {
                case "tenant" -> evaluateTenantRule(rule, context);
                case "plan" -> evaluatePlanRule(rule, context);
                case "user" -> evaluateUserRule(rule, context);
                case "percentage" -> evaluatePercentageRule(rule, context);
                case "environment" -> evaluateEnvironmentRule(rule, context);
                default -> Optional.empty();
            };

            if (result.isPresent()) return result;
        }
        return Optional.empty();
    }

    private Optional<Boolean> evaluatePercentageRule(FlagTargetingRule rule, FlagEvaluationContext context) {
        int percentage = rule.getRuleValue().get("percentage").asInt();
        // Use consistent hashing so the same user always gets the same result
        int bucket = Math.abs(
            Hashing.murmur3_32_fixed()
                .hashString(context.getTenantId() + ":" + context.getUserId(), StandardCharsets.UTF_8)
                .asInt() % 100
        );
        return Optional.of(bucket < percentage);
    }
}
```

**Flag evaluation context (passed from request):**

```java
@Builder
public record FlagEvaluationContext(
    String tenantId,
    String userId,
    String planTier,       // FREE, STARTER, PRO, ENTERPRISE
    String environment,    // dev, staging, production
    Map<String, String> attributes  // custom attributes for advanced targeting
) {}
```

**Spring Boot AOP for method-level flag gating:**

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface FeatureGate {
    String value();  // flag key
    String fallbackMethod() default "";
}

@Aspect
@Component
@RequiredArgsConstructor
public class FeatureGateAspect {

    private final FeatureFlagService flagService;
    private final RequestContextHolder contextHolder;

    @Around("@annotation(featureGate)")
    public Object checkFeatureGate(ProceedingJoinPoint joinPoint, FeatureGate featureGate) throws Throwable {
        FlagEvaluationContext ctx = contextHolder.getCurrentContext();

        if (flagService.isEnabled(featureGate.value(), ctx)) {
            return joinPoint.proceed();
        }

        if (!featureGate.fallbackMethod().isEmpty()) {
            Method fallback = joinPoint.getTarget().getClass()
                .getMethod(featureGate.fallbackMethod(), getParameterTypes(joinPoint));
            return fallback.invoke(joinPoint.getTarget(), joinPoint.getArgs());
        }

        throw new FeatureNotAvailableException(featureGate.value());
    }
}
```

**Usage in a controller:**

```java
@RestController
@RequestMapping("/api/v1/invoices")
public class InvoiceController {

    @FeatureGate("release.billing.invoice-pdf-export")
    @PostMapping("/{invoiceId}/export-pdf")
    public ResponseEntity<Resource> exportInvoicePdf(@PathVariable UUID invoiceId) {
        // Only reachable if flag is enabled for the current tenant/user
    }
}
```

### Step 3: React Frontend Integration

**Flag provider and hook:**

```typescript
// contexts/FeatureFlagContext.tsx
interface FlagMap {
  [key: string]: boolean | string | number;
}

interface FeatureFlagContextValue {
  flags: FlagMap;
  isEnabled: (flagKey: string) => boolean;
  getVariant: <T>(flagKey: string, defaultValue: T) => T;
  loading: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextValue | undefined>(undefined);

export function FeatureFlagProvider({ children }: { children: React.ReactNode }) {
  const [flags, setFlags] = useState<FlagMap>({});
  const [loading, setLoading] = useState(true);
  const { workspace } = useWorkspace();

  useEffect(() => {
    if (!workspace?.id) return;

    const fetchFlags = async () => {
      const response = await api.get<FlagMap>(`/api/v1/flags/evaluate`, {
        params: { tenantId: workspace.id },
      });
      setFlags(response.data);
      setLoading(false);
    };

    fetchFlags();

    // Subscribe to real-time flag updates via SSE
    const eventSource = new EventSource(
      `/api/v1/flags/stream?tenantId=${workspace.id}`
    );
    eventSource.onmessage = (event) => {
      const update = JSON.parse(event.data) as Partial<FlagMap>;
      setFlags((prev) => ({ ...prev, ...update }));
    };

    return () => eventSource.close();
  }, [workspace?.id]);

  const isEnabled = useCallback(
    (flagKey: string): boolean => {
      return flags[flagKey] === true;
    },
    [flags]
  );

  const getVariant = useCallback(
    <T,>(flagKey: string, defaultValue: T): T => {
      return (flags[flagKey] as T) ?? defaultValue;
    },
    [flags]
  );

  return (
    <FeatureFlagContext.Provider value={{ flags, isEnabled, getVariant, loading }}>
      {children}
    </FeatureFlagContext.Provider>
  );
}

export function useFeatureFlag(flagKey: string): boolean {
  const ctx = useContext(FeatureFlagContext);
  if (!ctx) throw new Error('useFeatureFlag must be inside FeatureFlagProvider');
  return ctx.isEnabled(flagKey);
}
```

**Component-level gating:**

```tsx
// components/FeatureGate.tsx
interface FeatureGateProps {
  flag: string;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function FeatureGate({ flag, children, fallback = null }: FeatureGateProps) {
  const enabled = useFeatureFlag(flag);
  return enabled ? <>{children}</> : <>{fallback}</>;
}

// Usage:
<FeatureGate flag="release.billing.invoice-pdf-export" fallback={<UpgradeBanner />}>
  <ExportPdfButton invoiceId={invoice.id} />
</FeatureGate>
```

### Step 4: Gradual Rollout Strategy

1. **Internal only (0%):** Enable for internal tenant IDs only. Validate in production with real data.
2. **Canary (1-5%):** Enable for a small percentage using consistent hashing. Monitor error rates and latency.
3. **Early adopters (10-25%):** Expand to beta-program tenants. Collect qualitative feedback.
4. **Broad rollout (50-100%):** Increase percentage incrementally. Watch dashboards at each step.
5. **Full rollout (100%):** Remove targeting rules. Flag stays as a kill switch for 7 days.
6. **Cleanup:** Remove the flag from code, database, and flag management system.

### Step 5: Kill Switch Pattern

Every critical feature MUST have a corresponding ops flag that can immediately disable it without a deployment.

```java
@Service
public class SearchService {

    private final FeatureFlagService flagService;
    private final ElasticsearchClient esClient;
    private final PostgresSearchFallback fallback;

    public SearchResults search(SearchQuery query, FlagEvaluationContext ctx) {
        if (!flagService.isEnabled("ops.search.elasticsearch-circuit-breaker", ctx)) {
            // Elasticsearch is disabled, fall back to PostgreSQL full-text search
            return fallback.search(query);
        }
        return esClient.search(query);
    }
}
```

## Rules

1. **Every flag MUST have an owner.** The `created_by` field is mandatory. Orphaned flags accumulate as tech debt.
2. **Release flags MUST have an expiration date.** Set `expires_at` when creating the flag. A scheduled job alerts on flags past their expiration.
3. **Never nest feature flags.** A code path gated by `flag_a` should not also check `flag_b` inside it. This creates combinatorial complexity that is nearly impossible to test.
4. **Flag evaluation MUST be fast.** Cache flags in Redis with a 60-second TTL. Flag checks happen on every request; they cannot add measurable latency.
5. **Use consistent hashing for percentage rollouts.** The same user must always land in the same bucket so their experience is stable across requests and sessions.
6. **Log flag evaluations for experiment flags.** Tie flag evaluation results to analytics events so experiment analysis has accurate exposure data.
7. **Run a flag hygiene job weekly.** Alert on flags that are 100% rolled out for more than 7 days, or expired flags still in use.
8. **Test both states.** Integration tests MUST cover both the enabled and disabled path for every release flag.
9. **Document permission flags in your pricing page source of truth.** When a permission flag gates a plan-tier feature, the flag key must be referenced in the plan configuration.

## Technical Debt Management

Track flag debt with a scheduled Gradle task:

```kotlin
// build.gradle.kts
tasks.register("flagAudit") {
    group = "verification"
    description = "Scans for stale feature flag references in source code"
    doLast {
        val flagPattern = Regex("""(release|experiment)\.[a-z0-9-]+\.[a-z0-9-]+""")
        val sourceFiles = fileTree("src") { include("**/*.java", "**/*.kt") }
        val flagsFound = mutableSetOf<String>()
        sourceFiles.forEach { file ->
            flagPattern.findAll(file.readText()).forEach { match ->
                flagsFound.add(match.value)
            }
        }
        println("Found ${flagsFound.size} flag references in source code:")
        flagsFound.sorted().forEach { println("  - $it") }
    }
}
```

## Examples

### Example 1: Gating a new billing feature by plan tier

```java
// Permission flag: only Pro and Enterprise tenants get advanced invoicing
@FeatureGate("permission.billing.advanced-invoicing")
@GetMapping("/api/v1/invoices/analytics")
public ResponseEntity<InvoiceAnalytics> getInvoiceAnalytics() {
    return ResponseEntity.ok(invoiceService.computeAnalytics());
}
```

Targeting rule in the database:
```json
{
  "rule_type": "plan",
  "rule_value": { "plans": ["PRO", "ENTERPRISE"] }
}
```

### Example 2: A/B experiment on the onboarding flow

```tsx
function OnboardingWizard() {
  const variant = useFeatureVariant<string>(
    'experiment.onboarding.signup-wizard-v2',
    'control'
  );

  useEffect(() => {
    analytics.track('experiment_exposure', {
      experiment: 'experiment.onboarding.signup-wizard-v2',
      variant,
    });
  }, [variant]);

  if (variant === 'treatment') {
    return <NewOnboardingWizard />;
  }
  return <ClassicOnboardingWizard />;
}
```

### Example 3: Infrastructure migration with kill switch

```java
@Service
public class NotificationService {

    @Value("${app.notifications.provider:legacy}")
    private String configuredProvider;

    private final FeatureFlagService flagService;

    public void send(Notification notification, FlagEvaluationContext ctx) {
        boolean useNewProvider = flagService.isEnabled(
            "ops.notifications.new-provider-migration", ctx
        );

        if (useNewProvider) {
            newProvider.send(notification);
        } else {
            legacyProvider.send(notification);
        }
    }
}
```

If the new provider experiences issues in production, disable the ops flag instantly from the admin panel -- no deployment needed.
