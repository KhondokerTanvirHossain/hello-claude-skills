---
name: user-onboarding
description: >
  User onboarding flow patterns for developer-facing SaaS including OAuth and email
  signup, email verification, workspace creation, onboarding checklist UI,
  progressive disclosure, time-to-first-value optimization, welcome email drip
  sequences, in-app guidance tooltips, activation rate measurement, and cohort
  analysis queries. Trigger: "onboarding flow", "signup page", "activation metrics",
  "trial conversion", "welcome wizard", "first-value moment"
tech_stack:
  - Java 21
  - Spring Boot 3.x
  - React
  - TypeScript
  - PostgreSQL
tags:
  - onboarding
  - activation
  - user-experience
  - saas
  - conversion
  - progressive-disclosure
---

# User Onboarding Flow Patterns

## Purpose

Define consistent, measurable onboarding patterns for developer-facing SaaS products. A well-designed onboarding flow directly impacts trial-to-paid conversion, user activation, and long-term retention. This skill covers the full onboarding journey: from signup (OAuth + email) through email verification, workspace creation, guided checklists, first-value-moment identification, progressive disclosure, welcome email drip campaigns, in-app guidance, and activation metric tracking with cohort analysis. Every design decision optimizes for getting the user to their "aha moment" as fast as possible.

## When to Use

- Building a new SaaS product and designing the signup and setup flow
- Improving trial-to-paid conversion rates by reducing time-to-first-value
- Adding workspace/organization multi-tenancy to an existing product
- Implementing an onboarding checklist or wizard to guide new users
- Setting up activation metrics and funnel tracking
- Designing email drip campaigns triggered by onboarding progress
- Integrating OAuth providers (Google, GitHub) alongside email/password signup
- Adding in-app guidance (tooltips, coachmarks) for feature discovery
- Running cohort analysis on activation rates

## Workflow: Onboarding Journey

```
SIGNUP --> EMAIL VERIFICATION --> WORKSPACE CREATION --> ONBOARDING WIZARD --> FIRST VALUE MOMENT --> ACTIVATED
         (non-blocking)          (required)              (guided checklist)   (tracked event)       (composite metric)
```

### Step 1: Signup Flow

Support both OAuth and email/password. For developer SaaS, GitHub OAuth is essential.

**Backend: Registration endpoint**

```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "User registration and login")
public class AuthController {

    private final UserRegistrationService registrationService;
    private final OAuthService oAuthService;

    @PostMapping("/register")
    @Operation(summary = "Register with email and password")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        User user = registrationService.register(
            request.email(), request.password(), request.fullName(),
            RegistrationSource.EMAIL
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(AuthResponse.fromUser(user));
    }

    @PostMapping("/oauth/{provider}")
    @Operation(summary = "OAuth callback for GitHub/Google login")
    public ResponseEntity<AuthResponse> oAuthCallback(
            @PathVariable String provider,
            @RequestBody OAuthCallbackRequest request) {
        OAuthUserInfo userInfo = oAuthService.exchangeCode(provider, request.code());
        User user = registrationService.findOrCreateOAuthUser(
            userInfo, RegistrationSource.valueOf(provider.toUpperCase())
        );
        return ResponseEntity.ok(AuthResponse.fromUser(user));
    }
}
```

**Registration service with onboarding initialization:**

```java
@Service
@RequiredArgsConstructor
@Transactional
public class UserRegistrationService {

    private final UserRepository userRepository;
    private final OnboardingTracker onboardingTracker;
    private final EmailService emailService;
    private final AnalyticsService analyticsService;

    public User register(String email, String password, String fullName, RegistrationSource source) {
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(email);
        }

        User user = User.builder()
            .email(email)
            .passwordHash(passwordEncoder.encode(password))
            .fullName(fullName)
            .registrationSource(source)
            .emailVerified(source != RegistrationSource.EMAIL) // OAuth users are pre-verified
            .build();

        user = userRepository.save(user);

        // Initialize onboarding checklist
        onboardingTracker.initializeOnboarding(user.getId());

        // Track signup event
        analyticsService.track(user.getId(), "user_signed_up", Map.of(
            "source", source.name(),
            "timestamp", Instant.now().toString()
        ));

        // Send verification email (skip for OAuth)
        if (source == RegistrationSource.EMAIL) {
            emailService.sendVerificationEmail(user);
        }

        return user;
    }
}
```

**PostgreSQL schema for onboarding tracking:**

```sql
CREATE TABLE onboarding_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id       UUID REFERENCES tenants(id),
    step_key        VARCHAR(64) NOT NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped')),
    completed_at    TIMESTAMPTZ,
    skipped_at      TIMESTAMPTZ,
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, step_key)
);

CREATE TABLE onboarding_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    tenant_id       UUID REFERENCES tenants(id),
    event_type      VARCHAR(64) NOT NULL,
    event_data      JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE activation_metrics (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id),
    tenant_id         UUID REFERENCES tenants(id),
    metric_name       VARCHAR(64) NOT NULL,
    metric_value      NUMERIC,
    first_achieved_at TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, metric_name)
);

CREATE INDEX idx_onboarding_progress_user ON onboarding_progress(user_id);
CREATE INDEX idx_onboarding_events_user_created ON onboarding_events(user_id, created_at);
CREATE INDEX idx_activation_metrics_user ON activation_metrics(user_id);
```

### Step 2: Workspace/Organization Creation

After signup, the user creates or joins a workspace. This is the multi-tenancy boundary.

```java
@Service
@RequiredArgsConstructor
@Transactional
public class WorkspaceSetupService {

    private final TenantRepository tenantRepository;
    private final TenantMembershipRepository membershipRepository;
    private final OnboardingTracker onboardingTracker;
    private final BillingService billingService;

    public Tenant createWorkspace(UUID userId, CreateWorkspaceRequest request) {
        Tenant tenant = Tenant.builder()
            .name(request.workspaceName())
            .slug(slugify(request.workspaceName()))
            .ownerId(userId)
            .planTier("FREE")
            .trialEndsAt(Instant.now().plus(14, ChronoUnit.DAYS)) // 14-day trial
            .settings(TenantSettings.defaults())
            .build();

        tenant = tenantRepository.save(tenant);

        // Add creator as OWNER
        membershipRepository.save(TenantMembership.builder()
            .tenantId(tenant.getId())
            .userId(userId)
            .role(TenantRole.OWNER)
            .invitedBy(userId)
            .acceptedAt(Instant.now())
            .build());

        // Create Stripe customer for billing
        billingService.createCustomer(tenant);

        // Mark onboarding step complete
        onboardingTracker.completeStep(userId, "create_workspace", Map.of(
            "tenant_id", tenant.getId().toString(),
            "workspace_name", tenant.getName()
        ));

        return tenant;
    }
}
```

### Step 3: Onboarding Checklist UI (React)

**Step definitions:**

```typescript
// types/onboarding.ts
export interface OnboardingStep {
  key: string;
  title: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'skipped';
  completedAt?: string;
  order: number;
  required: boolean;
  actionUrl?: string;
  actionLabel?: string;
}

export const ONBOARDING_STEPS: Omit<OnboardingStep, 'status' | 'completedAt'>[] = [
  {
    key: 'verify_email',
    title: 'Verify your email',
    description: 'Confirm your email address to unlock all features.',
    order: 1,
    required: true,
  },
  {
    key: 'create_workspace',
    title: 'Create your workspace',
    description: 'Set up your organization for team collaboration.',
    order: 2,
    required: true,
    actionUrl: '/onboarding/workspace',
    actionLabel: 'Create Workspace',
  },
  {
    key: 'create_first_project',
    title: 'Create your first project',
    description: 'Projects organize your work and connect to your codebase.',
    order: 3,
    required: true,
    actionUrl: '/projects/new',
    actionLabel: 'New Project',
  },
  {
    key: 'connect_repository',
    title: 'Connect a repository',
    description: 'Link a GitHub or GitLab repo to enable CI/CD integration.',
    order: 4,
    required: false,
    actionUrl: '/settings/integrations',
    actionLabel: 'Connect Repo',
  },
  {
    key: 'invite_team_members',
    title: 'Invite your team',
    description: 'Collaboration works best with teammates. Invite at least one.',
    order: 5,
    required: false,
    actionUrl: '/settings/team',
    actionLabel: 'Invite Members',
  },
];
```

**Checklist component:**

```tsx
// components/OnboardingChecklist.tsx
import { CheckCircle, Circle, ChevronRight, X } from 'lucide-react';

export function OnboardingChecklist({ onDismiss }: { onDismiss: () => void }) {
  const [expanded, setExpanded] = useState(true);
  const { data, isLoading } = useOnboardingProgress();

  if (isLoading || !data) return null;

  const { steps } = data;
  const completedCount = steps.filter((s) => s.status === 'completed').length;
  const progressPercent = Math.round((completedCount / steps.length) * 100);

  if (completedCount === steps.length) return null;

  return (
    <div className="bg-white border border-gray-200 rounded-lg shadow-sm p-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <h3 className="text-sm font-semibold text-gray-900">Get Started</h3>
          <span className="text-xs text-gray-500">
            {completedCount}/{steps.length} completed
          </span>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setExpanded(!expanded)} className="text-gray-400 hover:text-gray-600">
            <ChevronRight className={`h-4 w-4 transition-transform ${expanded ? 'rotate-90' : ''}`} />
          </button>
          <button onClick={onDismiss} className="text-gray-400 hover:text-gray-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="w-full bg-gray-100 rounded-full h-1.5 mb-4">
        <div
          className="bg-blue-600 h-1.5 rounded-full transition-all duration-500"
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      {expanded && (
        <div className="space-y-2">
          {steps.map((step) => (
            <OnboardingStepItem key={step.key} step={step} />
          ))}
        </div>
      )}
    </div>
  );
}
```

### Step 4: First-Value-Moment Tracking

The first-value-moment (FVM) is the earliest point where the user experiences the core product value. Track it with domain events.

```java
@Service
@RequiredArgsConstructor
public class ActivationService {

    private final ActivationMetricRepository metricRepository;
    private final OnboardingTracker onboardingTracker;
    private final AnalyticsService analyticsService;
    private final EmailService emailService;

    @EventListener
    @Transactional
    public void onFirstPipelineCompleted(PipelineCompletedEvent event) {
        UUID userId = event.getTriggeredByUserId();

        boolean isFirst = !metricRepository.existsByUserIdAndMetricName(userId, "first_pipeline_completed");

        if (isFirst) {
            metricRepository.save(ActivationMetric.builder()
                .userId(userId)
                .tenantId(event.getTenantId())
                .metricName("first_pipeline_completed")
                .metricValue(1.0)
                .firstAchievedAt(Instant.now())
                .build());

            onboardingTracker.completeStep(userId, "run_first_pipeline", Map.of(
                "pipeline_id", event.getPipelineId().toString(),
                "duration_seconds", String.valueOf(event.getDurationSeconds())
            ));

            analyticsService.track(userId, "activation_first_value_moment", Map.of(
                "metric", "first_pipeline_completed",
                "hours_since_signup", String.valueOf(hoursSinceSignup(userId))
            ));

            emailService.sendFirstValueMomentEmail(userId, "pipeline");
        }
    }

    public boolean isUserActivated(UUID userId) {
        Set<String> required = Set.of("first_pipeline_completed", "first_project_created", "email_verified");
        Set<String> achieved = metricRepository.findByUserId(userId).stream()
            .map(ActivationMetric::getMetricName)
            .collect(Collectors.toSet());
        return achieved.containsAll(required);
    }
}
```

### Step 5: Welcome Email Drip Sequence

Scheduled job sends contextual emails based on onboarding state. Runs daily.

```java
@Service
@RequiredArgsConstructor
public class OnboardingEmailScheduler {

    private final OnboardingProgressRepository progressRepository;
    private final ActivationService activationService;
    private final EmailService emailService;

    @Scheduled(cron = "0 0 10 * * *") // 10 AM UTC daily
    @Transactional(readOnly = true)
    public void sendOnboardingEmails() {
        Instant now = Instant.now();

        // Day 1: Signed up but no workspace
        progressRepository.findUsersWithIncompleteStep("create_workspace",
                now.minus(1, ChronoUnit.DAYS), now.minus(6, ChronoUnit.HOURS))
            .forEach(uid -> emailService.sendDripEmail(uid, "onboarding_day1_workspace"));

        // Day 3: Workspace created but no project
        progressRepository.findUsersWithCompletedStepButNotNext(
                "create_workspace", "create_first_project",
                now.minus(3, ChronoUnit.DAYS), now.minus(2, ChronoUnit.DAYS))
            .forEach(uid -> emailService.sendDripEmail(uid, "onboarding_day3_project"));

        // Day 7: Not activated
        progressRepository.findUsersNotActivatedAfterDays(7)
            .forEach(uid -> emailService.sendDripEmail(uid, "onboarding_day7_nudge"));

        // Day 10: Trial ending in 4 days, not activated
        progressRepository.findTrialUsersEndingIn(4).stream()
            .filter(uid -> !activationService.isUserActivated(uid))
            .forEach(uid -> emailService.sendDripEmail(uid, "trial_ending_not_activated"));
    }
}
```

### Step 6: Progressive Disclosure

Do not overwhelm new users. Show features as they complete onboarding steps.

```tsx
// hooks/useProgressiveDisclosure.ts
export function useProgressiveDisclosure() {
  const { data: onboarding } = useOnboardingProgress();

  const completedSteps = useMemo(() => {
    if (!onboarding) return new Set<string>();
    return new Set(
      onboarding.steps.filter((s) => s.status === 'completed').map((s) => s.key)
    );
  }, [onboarding]);

  return {
    showAdvancedSettings: completedSteps.has('create_first_project'),
    showTeamFeatures: completedSteps.has('invite_team_members'),
    showIntegrations: completedSteps.has('connect_repository'),
    showBillingUpgrade: completedSteps.has('run_first_pipeline'),
    showAnalytics: completedSteps.size >= 4,
    isFullyOnboarded: completedSteps.size === ONBOARDING_STEPS.length,
  };
}
```

### Step 7: In-App Guidance (Tooltips and Coachmarks)

```tsx
// components/CoachMark.tsx
export function CoachMark({
  targetRef,
  title,
  description,
  step,
  totalSteps,
  onNext,
  onDismiss,
}: CoachMarkProps) {
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    if (targetRef.current) {
      const rect = targetRef.current.getBoundingClientRect();
      setPosition({ top: rect.bottom + 8, left: rect.left });
    }
  }, [targetRef]);

  return createPortal(
    <div className="fixed z-50" style={position}>
      <div className="bg-blue-900 text-white rounded-lg shadow-xl p-4 max-w-xs">
        <p className="text-xs text-blue-300 mb-1">Step {step} of {totalSteps}</p>
        <h4 className="font-semibold text-sm mb-1">{title}</h4>
        <p className="text-xs text-blue-100 mb-3">{description}</p>
        <div className="flex justify-between">
          <button onClick={onDismiss} className="text-xs text-blue-300 hover:text-white">
            Skip tour
          </button>
          <button onClick={onNext} className="text-xs bg-white text-blue-900 px-3 py-1 rounded font-medium">
            {step === totalSteps ? 'Done' : 'Next'}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}
```

## Rules

1. **Minimize time to first value.** Every screen, field, and step between signup and the first value moment must justify its existence. If it can be deferred, defer it.
2. **Make the default path frictionless.** OAuth signup should require zero additional info beyond what the provider gives. Email signup: email, password, name only.
3. **Never block onboarding on email verification.** Let users explore immediately. Restrict sensitive operations (invites, billing) until verified, but do not gate the core product.
4. **Track every onboarding step as an analytics event.** You cannot improve what you do not measure. Every step fires an event with timestamps for funnel analysis.
5. **Onboarding is a product feature, not an afterthought.** Allocate engineering time like any other feature. Treat onboarding funnel conversion rate as a KPI.
6. **Allow skipping non-critical steps.** Power users should bypass the wizard. Mark steps as required or optional explicitly.
7. **Drip emails must be contextual.** Never send "create your first project" to a user with three projects. Check current state before sending.
8. **Show progress, not just next steps.** Progress bars and completed indicators reduce abandonment and provide motivation.

## Examples

### Example 1: OAuth Signup with Immediate Workspace Creation

```tsx
function SignupPage() {
  const [step, setStep] = useState<'signup' | 'workspace'>('signup');

  if (step === 'workspace') {
    return <WorkspaceSetupForm onComplete={() => router.push('/dashboard')} />;
  }

  return (
    <div className="max-w-md mx-auto mt-16">
      <h1 className="text-2xl font-bold text-center mb-8">Get started for free</h1>

      <button onClick={() => initiateOAuth('github')}
        className="w-full flex items-center justify-center gap-2 bg-gray-900 text-white rounded-lg py-3 mb-3">
        <GitHubIcon className="h-5 w-5" /> Continue with GitHub
      </button>

      <button onClick={() => initiateOAuth('google')}
        className="w-full flex items-center justify-center gap-2 border border-gray-300 rounded-lg py-3 mb-6">
        <GoogleIcon className="h-5 w-5" /> Continue with Google
      </button>

      <Divider text="or" />
      <EmailSignupForm onComplete={() => setStep('workspace')} />
    </div>
  );
}
```

### Example 2: Activation Funnel Cohort Analysis

```sql
SELECT
    DATE_TRUNC('week', u.created_at) AS cohort_week,
    COUNT(DISTINCT u.id) AS signups,
    COUNT(DISTINCT CASE WHEN op_ws.status = 'completed' THEN u.id END) AS workspace_created,
    COUNT(DISTINCT CASE WHEN op_proj.status = 'completed' THEN u.id END) AS project_created,
    COUNT(DISTINCT CASE WHEN op_pipe.status = 'completed' THEN u.id END) AS pipeline_run,
    ROUND(
        COUNT(DISTINCT CASE WHEN op_pipe.status = 'completed' THEN u.id END)::NUMERIC /
        NULLIF(COUNT(DISTINCT u.id), 0) * 100, 1
    ) AS activation_rate_pct
FROM users u
LEFT JOIN onboarding_progress op_ws ON u.id = op_ws.user_id AND op_ws.step_key = 'create_workspace'
LEFT JOIN onboarding_progress op_proj ON u.id = op_proj.user_id AND op_proj.step_key = 'create_first_project'
LEFT JOIN onboarding_progress op_pipe ON u.id = op_pipe.user_id AND op_pipe.step_key = 'run_first_pipeline'
WHERE u.created_at >= NOW() - INTERVAL '12 weeks'
GROUP BY cohort_week
ORDER BY cohort_week DESC;
```

### Example 3: Trial-to-Paid Conversion Optimization

```java
@EventListener
@Transactional
public void onTrialEndingSoon(TrialEndingSoonEvent event) {
    UUID tenantId = event.getTenantId();
    boolean activated = activationService.isTenantActivated(tenantId);

    if (activated) {
        emailService.sendTrialEndingActivatedEmail(tenantId, event.getDaysRemaining());
    } else {
        List<String> incompleteSteps = onboardingTracker.getIncompleteRequiredSteps(tenantId);
        emailService.sendTrialEndingNotActivatedEmail(tenantId, event.getDaysRemaining(), incompleteSteps);

        if (hasShowedEngagement(tenantId)) {
            trialExtensionService.offerExtension(tenantId, 7);
        }
    }
}
```
