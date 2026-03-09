# Onboarding Steps

## 5-Step Onboarding Checklist

Every new user progresses through these steps. The checklist is displayed prominently in the dashboard until all required steps are completed.

| Step | Title | Required | Estimated Time | Activation Weight |
|------|-------|----------|---------------|-------------------|
| 1 | Create your workspace | Yes | 30 seconds | 20% |
| 2 | Invite a team member | No | 1 minute | 15% |
| 3 | Create your first project | Yes | 2 minutes | 25% |
| 4 | Connect an integration | No | 3 minutes | 15% |
| 5 | Deploy to production | Yes | 5 minutes | 25% |

**Activation threshold**: A user is considered "activated" when they complete all required steps (steps 1, 3, 5) OR reach 60% activation weight.

## Step Details

### Step 1: Create Your Workspace

**Trigger**: Automatically shown after email verification or OAuth signup.

| Field | Value |
|-------|-------|
| `step_key` | `create-workspace` |
| `required` | `true` |
| `skip_allowed` | `false` |
| `auto_complete` | `false` |
| `cta_text` | "Create Workspace" |
| `cta_route` | `/onboarding/workspace` |
| `help_url` | `/docs/getting-started/workspace` |

**Completion criteria**:
- Workspace name provided (min 3 characters)
- Workspace slug generated
- Default environment ("production") created
- Subscription initialized (Free tier or trial)

```java
public record CreateWorkspaceCommand(
    @NotBlank @Size(min = 3, max = 50) String name,
    @Size(max = 100) String description
) {}
```

### Step 2: Invite a Team Member

**Trigger**: Shown after workspace creation. Can be skipped.

| Field | Value |
|-------|-------|
| `step_key` | `invite-team-member` |
| `required` | `false` |
| `skip_allowed` | `true` |
| `auto_complete` | `false` |
| `cta_text` | "Invite Team" |
| `cta_route` | `/settings/team/invite` |
| `help_url` | `/docs/team/invitations` |
| `skip_text` | "I'll do this later" |

**Completion criteria**:
- At least one invitation sent (does not need to be accepted)
- OR step explicitly skipped by user

**Skip behavior**:
- Record skip timestamp and reason
- Re-prompt after 7 days via email if still solo user
- Show subtle "Invite team" nudge in sidebar after skip

### Step 3: Create Your First Project

**Trigger**: Shown after workspace creation (parallel with step 2).

| Field | Value |
|-------|-------|
| `step_key` | `create-first-project` |
| `required` | `true` |
| `skip_allowed` | `false` |
| `auto_complete` | `false` |
| `cta_text` | "Create Project" |
| `cta_route` | `/projects/new` |
| `help_url` | `/docs/projects/create` |

**Completion criteria**:
- Project created with a name and at least one environment
- Project has at least one API key generated

**Progressive disclosure**: After this step, unlock the "Integrations" section in the sidebar.

### Step 4: Connect an Integration

**Trigger**: Shown after first project is created. Can be skipped.

| Field | Value |
|-------|-------|
| `step_key` | `connect-integration` |
| `required` | `false` |
| `skip_allowed` | `true` |
| `auto_complete` | `false` |
| `cta_text` | "Browse Integrations" |
| `cta_route` | `/integrations` |
| `help_url` | `/docs/integrations/overview` |
| `skip_text` | "Skip for now" |

**Completion criteria**:
- At least one integration connected (GitHub, Slack, Jira, etc.)
- OR step explicitly skipped

**Skip behavior**:
- Show integration suggestions contextually when user performs related actions
- Send "Top integrations for your stack" email on day 5

### Step 5: Deploy to Production

**Trigger**: Shown after first project creation. This is the "first value moment."

| Field | Value |
|-------|-------|
| `step_key` | `first-deploy` |
| `required` | `true` |
| `skip_allowed` | `false` |
| `auto_complete` | `true` |
| `cta_text` | "Deploy Now" |
| `cta_route` | `/projects/{projectId}/deploy` |
| `help_url` | `/docs/deployments/first-deploy` |

**Completion criteria**:
- At least one successful deployment to any environment
- Auto-completes when deployment status changes to `SUCCESS`

**Auto-complete logic**: Listen for `DeploymentCompletedEvent` and mark step done automatically.

## Completion Tracking

### Database Schema

```sql
CREATE TABLE onboarding_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    step_key        VARCHAR(50) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped')),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    skipped_at      TIMESTAMPTZ,
    skip_reason     VARCHAR(200),
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, step_key)
);

CREATE INDEX idx_onboarding_user   ON onboarding_progress(user_id);
CREATE INDEX idx_onboarding_tenant ON onboarding_progress(tenant_id);
CREATE INDEX idx_onboarding_status ON onboarding_progress(status);
```

### Tracking Events

Every interaction is also logged as an event for funnel analysis:

```sql
CREATE TABLE onboarding_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    event_type  VARCHAR(50) NOT NULL,
    step_key    VARCHAR(50),
    properties  JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_onboarding_events_user ON onboarding_events(user_id);
CREATE INDEX idx_onboarding_events_type ON onboarding_events(event_type);
CREATE INDEX idx_onboarding_events_date ON onboarding_events(created_at);
```

**Event types**:

| Event Type | When Fired | Properties |
|------------|-----------|------------|
| `onboarding.started` | User completes signup | `{ source: "oauth" \| "email" }` |
| `onboarding.step.viewed` | User sees a step in checklist | `{ step_key }` |
| `onboarding.step.started` | User clicks CTA for a step | `{ step_key }` |
| `onboarding.step.completed` | Step completion criteria met | `{ step_key, duration_seconds }` |
| `onboarding.step.skipped` | User clicks "Skip" | `{ step_key, reason? }` |
| `onboarding.completed` | All required steps done | `{ total_duration_seconds, steps_skipped }` |
| `onboarding.dismissed` | User closes checklist | `{ completion_percentage }` |
| `onboarding.reengaged` | User returns after abandonment | `{ days_since_last_activity }` |

### Progress Calculation

```java
@Service
public class OnboardingProgressService {

    private static final Map<String, Integer> STEP_WEIGHTS = Map.of(
        "create-workspace", 20,
        "invite-team-member", 15,
        "create-first-project", 25,
        "connect-integration", 15,
        "first-deploy", 25
    );

    public OnboardingStatus getStatus(UUID userId) {
        var steps = onboardingRepo.findByUserId(userId);

        int totalWeight = 0;
        int completedRequired = 0;
        int totalRequired = 3; // steps 1, 3, 5

        for (var step : steps) {
            if (step.getStatus() == StepStatus.COMPLETED || step.getStatus() == StepStatus.SKIPPED) {
                totalWeight += STEP_WEIGHTS.getOrDefault(step.getStepKey(), 0);
            }
            if (isRequired(step.getStepKey()) && step.getStatus() == StepStatus.COMPLETED) {
                completedRequired++;
            }
        }

        boolean activated = completedRequired == totalRequired || totalWeight >= 60;

        return new OnboardingStatus(
            steps,
            totalWeight,
            activated,
            completedRequired,
            totalRequired
        );
    }
}
```

## Skip Logic

### Rules for Skippable Steps

1. Only non-required steps can be skipped (steps 2 and 4)
2. Skipping records a timestamp but does not count toward "completed required" count
3. Skipped steps contribute to activation weight (so 60% threshold can still be reached)
4. Users can return to skipped steps at any time
5. Skipped steps trigger re-engagement reminders

### Skip Tracking

```java
@Transactional
public void skipStep(UUID userId, String stepKey) {
    var step = onboardingRepo.findByUserIdAndStepKey(userId, stepKey)
        .orElseThrow(() -> new StepNotFoundException(stepKey));

    if (step.isRequired()) {
        throw new CannotSkipRequiredStepException(stepKey);
    }

    step.setStatus(StepStatus.SKIPPED);
    step.setSkippedAt(Instant.now());
    onboardingRepo.save(step);

    eventPublisher.publish(new OnboardingStepSkippedEvent(userId, stepKey));
}
```

## Re-Engagement Triggers

When a user stalls during onboarding, these triggers fire to bring them back:

### Email Drip Schedule

| Trigger Condition | Delay | Email Subject | Content |
|-------------------|-------|---------------|---------|
| Signed up, no workspace created | 24 hours | "Let's get you set up" | Quick-start guide link |
| Workspace created, no project | 48 hours | "Create your first project in 2 minutes" | Video walkthrough |
| Project created, no deploy | 72 hours | "You're one step away from going live" | Deploy guide + support chat link |
| Steps 2 or 4 skipped | 7 days | "Unlock the full power of [Product]" | Integration/team benefits |
| All required done, checklist dismissed | 14 days | "Pro tips for power users" | Advanced features guide |
| No activity for 7+ days (incomplete) | 7 days | "We miss you! Your workspace is waiting" | Resume link + offer to help |
| No activity for 30+ days (incomplete) | 30 days | "Last chance to activate your account" | Final nudge + expiry warning |

### In-App Nudges

| Trigger Condition | Nudge Type | Location |
|-------------------|-----------|----------|
| Step 2 skipped, user on dashboard | Subtle banner | Top of dashboard |
| Step 4 skipped, user views project | Tooltip | Integrations sidebar item |
| Checklist < 60%, 3+ sessions | Modal | On 3rd session login |
| Deploy step pending, 5+ days | Coach mark | Deploy button in project view |

### Re-Engagement Service

```java
@Service
public class ReEngagementService {

    @Scheduled(cron = "0 0 9 * * *") // daily at 9 AM
    public void checkStaleOnboarding() {
        var staleUsers = onboardingRepo.findUsersWithIncompleteOnboarding(
            Duration.ofDays(1),  // at least 1 day since last activity
            Duration.ofDays(30)  // not older than 30 days
        );

        for (var user : staleUsers) {
            var status = progressService.getStatus(user.getId());
            var lastActivity = onboardingEventRepo.findLastActivity(user.getId());
            var daysSinceActivity = Duration.between(lastActivity, Instant.now()).toDays();

            EmailTemplate template = determineReEngagementEmail(status, daysSinceActivity);

            if (template != null && !alreadySent(user.getId(), template)) {
                emailService.sendOnboardingEmail(user.getEmail(), template, Map.of(
                    "userName", user.getDisplayName(),
                    "nextStep", status.getNextPendingStep().getTitle(),
                    "resumeUrl", buildResumeUrl(user.getId(), status.getNextPendingStep())
                ));

                eventPublisher.publish(new ReEngagementEmailSentEvent(
                    user.getId(), template.name(), daysSinceActivity));
            }
        }
    }
}
```

## React Checklist Component

```tsx
interface OnboardingStep {
  stepKey: string;
  title: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'skipped';
  required: boolean;
  skipAllowed: boolean;
  ctaText: string;
  ctaRoute: string;
}

export function OnboardingChecklist({ steps, progress }: {
  steps: OnboardingStep[];
  progress: number;
}) {
  const navigate = useNavigate();

  return (
    <div className="rounded-lg border bg-white p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold">Getting Started</h3>
        <span className="text-sm text-gray-500">{progress}% complete</span>
      </div>

      {/* Progress bar */}
      <div className="mb-6 h-2 rounded-full bg-gray-100">
        <div
          className="h-2 rounded-full bg-blue-600 transition-all duration-500"
          style={{ width: `${progress}%` }}
        />
      </div>

      {/* Steps */}
      <div className="space-y-3">
        {steps.map((step, index) => (
          <div
            key={step.stepKey}
            className={cn(
              'flex items-center gap-3 rounded-md p-3',
              step.status === 'completed' && 'bg-green-50',
              step.status === 'skipped' && 'bg-gray-50 opacity-60',
            )}
          >
            {/* Step indicator */}
            <div className={cn(
              'flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium',
              step.status === 'completed' ? 'bg-green-600 text-white' :
              step.status === 'skipped' ? 'bg-gray-300 text-gray-600' :
              'bg-blue-100 text-blue-700'
            )}>
              {step.status === 'completed' ? '✓' : index + 1}
            </div>

            {/* Step content */}
            <div className="flex-1">
              <p className={cn(
                'font-medium',
                step.status === 'completed' && 'line-through text-gray-500'
              )}>
                {step.title}
                {step.required && <span className="ml-1 text-red-500">*</span>}
              </p>
              <p className="text-sm text-gray-500">{step.description}</p>
            </div>

            {/* Actions */}
            {step.status === 'pending' && (
              <div className="flex gap-2">
                <button
                  onClick={() => navigate(step.ctaRoute)}
                  className="rounded-md bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
                >
                  {step.ctaText}
                </button>
                {step.skipAllowed && (
                  <button
                    onClick={() => skipStep(step.stepKey)}
                    className="text-sm text-gray-400 hover:text-gray-600"
                  >
                    Skip
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Funnel Analysis Query

```sql
-- Onboarding funnel: conversion at each step
SELECT
    step_key,
    COUNT(*) FILTER (WHERE status IN ('completed', 'skipped')) AS completed_or_skipped,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE status = 'skipped') AS skipped,
    COUNT(*) FILTER (WHERE status = 'pending') AS still_pending,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0),
        1
    ) AS completion_rate_pct,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (completed_at - started_at))
    ) FILTER (WHERE status = 'completed') AS median_duration_seconds
FROM onboarding_progress
WHERE created_at >= now() - INTERVAL '30 days'
GROUP BY step_key
ORDER BY
    CASE step_key
        WHEN 'create-workspace' THEN 1
        WHEN 'invite-team-member' THEN 2
        WHEN 'create-first-project' THEN 3
        WHEN 'connect-integration' THEN 4
        WHEN 'first-deploy' THEN 5
    END;
```
