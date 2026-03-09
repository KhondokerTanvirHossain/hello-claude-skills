---
name: billing-stripe
description: Stripe billing integration patterns for Spring Boot SaaS applications including subscription management, usage-based billing, webhook handling, and plan tier management
tech_stack:
  - Java 21
  - Spring Boot 3.x
  - PostgreSQL
  - Stripe API
  - Gradle
tags:
  - billing
  - stripe
  - subscriptions
  - payments
  - saas
  - webhooks
---

# Stripe Billing Integration Patterns

## Purpose

Provide battle-tested patterns for integrating Stripe billing into a Spring Boot SaaS application. This covers the full billing lifecycle: plan modeling, subscription management, usage-based metering, webhook processing, invoice handling, and customer portal setup. The goal is a billing system that is reliable, idempotent, auditable, and aligned with SaaS pricing best practices.

## When to Use

- Building a new SaaS product that needs subscription billing from day one.
- Migrating from a homegrown billing system to Stripe.
- Adding usage-based billing (metered) to an existing subscription model.
- Implementing plan tier upgrades/downgrades with proration.
- Setting up webhook handlers for Stripe events.
- Building an admin dashboard for billing operations (refunds, credits, invoice management).
- Integrating Stripe Customer Portal for self-service billing management.

## Plan and Tier Modeling

### PostgreSQL Schema

```sql
-- Plans represent your pricing tiers (synced with Stripe Products/Prices)
CREATE TABLE billing_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_product_id VARCHAR(64) NOT NULL UNIQUE,
    name            VARCHAR(64) NOT NULL,
    slug            VARCHAR(32) NOT NULL UNIQUE,
    tier            VARCHAR(16) NOT NULL CHECK (tier IN ('FREE', 'STARTER', 'PRO', 'ENTERPRISE')),
    billing_model   VARCHAR(16) NOT NULL CHECK (billing_model IN ('flat', 'per_seat', 'metered', 'hybrid')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    features        JSONB NOT NULL DEFAULT '{}',
    limits          JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Price variants for each plan (monthly, annual, etc.)
CREATE TABLE billing_prices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id         UUID NOT NULL REFERENCES billing_plans(id),
    stripe_price_id VARCHAR(64) NOT NULL UNIQUE,
    interval        VARCHAR(8) NOT NULL CHECK (interval IN ('month', 'year')),
    amount_cents    INTEGER NOT NULL,
    currency        VARCHAR(3) NOT NULL DEFAULT 'usd',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tenant subscription state (source of truth is Stripe, this is a local cache)
CREATE TABLE tenant_subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL UNIQUE REFERENCES tenants(id),
    stripe_customer_id  VARCHAR(64) NOT NULL UNIQUE,
    stripe_subscription_id VARCHAR(64) UNIQUE,
    plan_id             UUID REFERENCES billing_plans(id),
    status              VARCHAR(24) NOT NULL DEFAULT 'trialing'
                        CHECK (status IN ('trialing', 'active', 'past_due', 'canceled', 'unpaid', 'incomplete', 'incomplete_expired', 'paused')),
    current_period_start TIMESTAMPTZ,
    current_period_end   TIMESTAMPTZ,
    trial_end           TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
    seats_quantity      INTEGER NOT NULL DEFAULT 1,
    metadata            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Usage records for metered billing
CREATE TABLE usage_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    metric_name     VARCHAR(64) NOT NULL,
    quantity        BIGINT NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    reported_to_stripe BOOLEAN NOT NULL DEFAULT FALSE,
    stripe_usage_record_id VARCHAR(64),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reported_at     TIMESTAMPTZ
);

-- Webhook event log for idempotency and debugging
CREATE TABLE stripe_webhook_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id VARCHAR(64) NOT NULL UNIQUE,
    event_type      VARCHAR(64) NOT NULL,
    payload         JSONB NOT NULL,
    processing_status VARCHAR(16) NOT NULL DEFAULT 'received'
                    CHECK (processing_status IN ('received', 'processing', 'processed', 'failed', 'skipped')),
    error_message   TEXT,
    processed_at    TIMESTAMPTZ,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_usage_records_tenant_metric ON usage_records(tenant_id, metric_name, recorded_at);
CREATE INDEX idx_webhook_events_type ON stripe_webhook_events(event_type, received_at);
CREATE INDEX idx_webhook_events_status ON stripe_webhook_events(processing_status);
```

### Plan Features and Limits Configuration

```java
// Domain model for plan limits
public record PlanLimits(
    int maxSeats,
    int maxProjects,
    long maxStorageBytes,
    int apiRequestsPerHour,
    int maxWebhooksPerProject,
    boolean customDomains,
    boolean ssoEnabled,
    boolean auditLog,
    boolean prioritySupport
) {
    public static PlanLimits forTier(String tier) {
        return switch (tier) {
            case "FREE" -> new PlanLimits(1, 3, 1_073_741_824L, 1000, 5, false, false, false, false);
            case "STARTER" -> new PlanLimits(5, 10, 10_737_418_240L, 5000, 20, false, false, false, false);
            case "PRO" -> new PlanLimits(25, 50, 107_374_182_400L, 25000, 100, true, true, true, false);
            case "ENTERPRISE" -> new PlanLimits(Integer.MAX_VALUE, Integer.MAX_VALUE, Long.MAX_VALUE, 100000, Integer.MAX_VALUE, true, true, true, true);
            default -> throw new IllegalArgumentException("Unknown tier: " + tier);
        };
    }
}
```

## Workflow: Subscription Lifecycle

```
TRIAL --> ACTIVE --> (PAST_DUE --> ACTIVE | CANCELED) --> CANCELED
                 --> CANCEL_AT_PERIOD_END --> CANCELED
```

### Step 1: Customer and Subscription Creation

```java
@Service
@RequiredArgsConstructor
@Transactional
public class BillingService {

    private final StripeClient stripeClient;
    private final TenantSubscriptionRepository subscriptionRepository;
    private final BillingPriceRepository priceRepository;

    public TenantSubscription createSubscription(UUID tenantId, String planSlug, String billingInterval, String paymentMethodId) {
        Tenant tenant = tenantRepository.findByIdOrThrow(tenantId);
        BillingPrice price = priceRepository.findByPlanSlugAndInterval(planSlug, billingInterval)
            .orElseThrow(() -> new PlanNotFoundException(planSlug, billingInterval));

        // Create or retrieve Stripe customer
        String stripeCustomerId = getOrCreateStripeCustomer(tenant);

        // Attach payment method
        PaymentMethod paymentMethod = PaymentMethod.retrieve(paymentMethodId);
        paymentMethod.attach(PaymentMethodAttachParams.builder()
            .setCustomer(stripeCustomerId)
            .build());

        // Set as default payment method
        Customer.retrieve(stripeCustomerId).update(
            CustomerUpdateParams.builder()
                .setInvoiceSettings(CustomerUpdateParams.InvoiceSettings.builder()
                    .setDefaultPaymentMethod(paymentMethodId)
                    .build())
                .build()
        );

        // Create subscription with trial if applicable
        SubscriptionCreateParams.Builder subParams = SubscriptionCreateParams.builder()
            .setCustomer(stripeCustomerId)
            .addItem(SubscriptionCreateParams.Item.builder()
                .setPrice(price.getStripePriceId())
                .build())
            .setPaymentBehavior(SubscriptionCreateParams.PaymentBehavior.DEFAULT_INCOMPLETE)
            .addExpand("latest_invoice.payment_intent")
            .putMetadata("tenant_id", tenantId.toString());

        if (price.getPlan().getTier().equals("STARTER") || price.getPlan().getTier().equals("PRO")) {
            subParams.setTrialPeriodDays(14L);
        }

        Subscription stripeSubscription = Subscription.create(subParams.build());

        // Save local record (webhook will also update this, but we want immediate consistency)
        TenantSubscription localSub = TenantSubscription.builder()
            .tenantId(tenantId)
            .stripeCustomerId(stripeCustomerId)
            .stripeSubscriptionId(stripeSubscription.getId())
            .planId(price.getPlan().getId())
            .status(stripeSubscription.getStatus())
            .currentPeriodStart(Instant.ofEpochSecond(stripeSubscription.getCurrentPeriodStart()))
            .currentPeriodEnd(Instant.ofEpochSecond(stripeSubscription.getCurrentPeriodEnd()))
            .trialEnd(stripeSubscription.getTrialEnd() != null
                ? Instant.ofEpochSecond(stripeSubscription.getTrialEnd()) : null)
            .build();

        return subscriptionRepository.save(localSub);
    }
}
```

### Step 2: Webhook Handling

**Controller with signature verification:**

```java
@RestController
@RequestMapping("/api/webhooks/stripe")
@RequiredArgsConstructor
@Slf4j
public class StripeWebhookController {

    @Value("${stripe.webhook.secret}")
    private String webhookSecret;

    private final StripeWebhookProcessor processor;

    @PostMapping
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            log.warn("Stripe webhook signature verification failed", e);
            return ResponseEntity.status(400).body("Invalid signature");
        }

        processor.process(event);

        // Always return 200 quickly. Processing happens async if needed.
        return ResponseEntity.ok("received");
    }
}
```

**Idempotent event processor:**

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class StripeWebhookProcessor {

    private final StripeWebhookEventRepository eventRepository;
    private final Map<String, StripeEventHandler> handlers;

    @Transactional
    public void process(Event event) {
        // Idempotency check: skip if already processed
        if (eventRepository.existsByStripeEventId(event.getId())) {
            log.info("Skipping duplicate Stripe event: {}", event.getId());
            return;
        }

        // Persist the event for audit trail
        StripeWebhookEvent record = StripeWebhookEvent.builder()
            .stripeEventId(event.getId())
            .eventType(event.getType())
            .payload(event.toJson())
            .processingStatus("processing")
            .build();
        eventRepository.save(record);

        try {
            StripeEventHandler handler = handlers.get(event.getType());
            if (handler != null) {
                handler.handle(event);
                record.setProcessingStatus("processed");
            } else {
                log.debug("No handler for Stripe event type: {}", event.getType());
                record.setProcessingStatus("skipped");
            }
        } catch (Exception e) {
            log.error("Failed to process Stripe event: {} ({})", event.getId(), event.getType(), e);
            record.setProcessingStatus("failed");
            record.setErrorMessage(e.getMessage());
            throw e; // Rethrow so Stripe retries
        } finally {
            record.setProcessedAt(Instant.now());
            eventRepository.save(record);
        }
    }
}
```

**Event handler for subscription updates:**

```java
@Component("customer.subscription.updated")
@RequiredArgsConstructor
public class SubscriptionUpdatedHandler implements StripeEventHandler {

    private final TenantSubscriptionRepository subscriptionRepository;
    private final BillingPlanRepository planRepository;
    private final TenantEventPublisher eventPublisher;

    @Override
    @Transactional
    public void handle(Event event) {
        Subscription subscription = (Subscription) event.getDataObjectDeserializer()
            .getObject().orElseThrow();

        TenantSubscription localSub = subscriptionRepository
            .findByStripeSubscriptionId(subscription.getId())
            .orElseThrow(() -> new SubscriptionNotFoundException(subscription.getId()));

        String previousStatus = localSub.getStatus();
        localSub.setStatus(subscription.getStatus());
        localSub.setCurrentPeriodStart(Instant.ofEpochSecond(subscription.getCurrentPeriodStart()));
        localSub.setCurrentPeriodEnd(Instant.ofEpochSecond(subscription.getCurrentPeriodEnd()));
        localSub.setCancelAtPeriodEnd(subscription.getCancelAtPeriodEnd());

        subscriptionRepository.save(localSub);

        // Publish domain events for downstream services
        if (!previousStatus.equals(subscription.getStatus())) {
            eventPublisher.publish(new SubscriptionStatusChanged(
                localSub.getTenantId(),
                previousStatus,
                subscription.getStatus()
            ));
        }
    }
}
```

### Critical Webhook Events to Handle

| Event | Action |
|-------|--------|
| `customer.subscription.created` | Create local subscription record, start onboarding |
| `customer.subscription.updated` | Sync status, detect plan changes, handle downgrades |
| `customer.subscription.deleted` | Mark subscription canceled, trigger offboarding flow |
| `customer.subscription.trial_will_end` | Send trial ending notification (3 days before) |
| `invoice.payment_succeeded` | Update subscription status to active, send receipt |
| `invoice.payment_failed` | Mark as past_due, send dunning email, apply grace period |
| `invoice.finalized` | Store invoice snapshot for audit trail |
| `customer.updated` | Sync customer metadata (email, name, tax ID) |
| `payment_method.attached` | Update default payment method in local records |

### Step 3: Usage-Based Metering

```java
@Service
@RequiredArgsConstructor
public class UsageMeteringService {

    private final UsageRecordRepository usageRepository;
    private final TenantSubscriptionRepository subscriptionRepository;

    /**
     * Record a usage event. This is called from business logic whenever
     * a metered action occurs (API call, storage upload, etc.).
     */
    @Transactional
    public void recordUsage(UUID tenantId, String metricName, long quantity) {
        String idempotencyKey = "%s:%s:%s:%d".formatted(
            tenantId, metricName, Instant.now().truncatedTo(ChronoUnit.MINUTES), quantity
        );

        UsageRecord record = UsageRecord.builder()
            .tenantId(tenantId)
            .metricName(metricName)
            .quantity(quantity)
            .idempotencyKey(idempotencyKey)
            .build();

        usageRepository.save(record);
    }

    /**
     * Report accumulated usage to Stripe. Run by a scheduled job every hour.
     */
    @Scheduled(fixedRate = 3600000) // every hour
    @Transactional
    public void reportUsageToStripe() {
        List<UsageRecord> unreported = usageRepository
            .findByReportedToStripeFalse();

        // Group by tenant + metric to batch
        Map<String, List<UsageRecord>> grouped = unreported.stream()
            .collect(Collectors.groupingBy(r -> r.getTenantId() + ":" + r.getMetricName()));

        for (var entry : grouped.entrySet()) {
            UUID tenantId = entry.getValue().get(0).getTenantId();
            long totalQuantity = entry.getValue().stream().mapToLong(UsageRecord::getQuantity).sum();

            TenantSubscription sub = subscriptionRepository.findByTenantId(tenantId).orElseThrow();

            // Find the metered subscription item
            Subscription stripeSub = Subscription.retrieve(sub.getStripeSubscriptionId());
            String subscriptionItemId = stripeSub.getItems().getData().stream()
                .filter(item -> item.getPrice().getRecurring().getUsageType().equals("metered"))
                .findFirst()
                .orElseThrow()
                .getId();

            UsageRecordCreateOnSubscriptionItemParams params = UsageRecordCreateOnSubscriptionItemParams.builder()
                .setQuantity(totalQuantity)
                .setTimestamp(Instant.now().getEpochSecond())
                .setAction(UsageRecordCreateOnSubscriptionItemParams.Action.INCREMENT)
                .build();

            com.stripe.model.UsageRecord.createOnSubscriptionItem(subscriptionItemId, params, null);

            // Mark as reported
            entry.getValue().forEach(r -> {
                r.setReportedToStripe(true);
                r.setReportedAt(Instant.now());
            });
            usageRepository.saveAll(entry.getValue());
        }
    }
}
```

### Step 4: Plan Change with Proration

```java
public TenantSubscription changePlan(UUID tenantId, String newPlanSlug, String billingInterval) {
    TenantSubscription localSub = subscriptionRepository.findByTenantId(tenantId).orElseThrow();
    BillingPrice newPrice = priceRepository.findByPlanSlugAndInterval(newPlanSlug, billingInterval).orElseThrow();

    Subscription stripeSub = Subscription.retrieve(localSub.getStripeSubscriptionId());
    String existingItemId = stripeSub.getItems().getData().get(0).getId();

    SubscriptionUpdateParams params = SubscriptionUpdateParams.builder()
        .addItem(SubscriptionUpdateParams.Item.builder()
            .setId(existingItemId)
            .setPrice(newPrice.getStripePriceId())
            .build())
        .setProrationBehavior(SubscriptionUpdateParams.ProrationBehavior.CREATE_PRORATIONS)
        .putMetadata("plan_change_reason", "user_initiated")
        .build();

    Subscription updated = stripeSub.update(params);

    // Local state will be synced by the customer.subscription.updated webhook
    // but update immediately for UX responsiveness
    localSub.setPlanId(newPrice.getPlan().getId());
    localSub.setStatus(updated.getStatus());
    return subscriptionRepository.save(localSub);
}
```

### Step 5: Stripe Customer Portal

```java
@PostMapping("/api/v1/billing/portal-session")
public ResponseEntity<Map<String, String>> createPortalSession(@AuthenticationPrincipal UserPrincipal user) {
    TenantSubscription sub = subscriptionRepository.findByTenantId(user.getTenantId()).orElseThrow();

    SessionCreateParams params = SessionCreateParams.builder()
        .setCustomer(sub.getStripeCustomerId())
        .setReturnUrl("https://app.example.com/settings/billing")
        .build();

    Session session = Session.create(params);

    return ResponseEntity.ok(Map.of("url", session.getUrl()));
}
```

## Rules

1. **Stripe is the source of truth for billing state.** Your local database is a cache. Always reconcile via webhooks. Never trust local state for billing decisions without verifying against Stripe.
2. **Every webhook handler MUST be idempotent.** Stripe may deliver the same event multiple times. Use `stripe_event_id` as a deduplication key.
3. **Never store full card numbers.** Use Stripe Elements or Checkout for PCI compliance. Your backend should only handle Stripe tokens and payment method IDs.
4. **Always verify webhook signatures.** Reject any webhook that fails signature verification. Use the endpoint-specific signing secret.
5. **Handle `past_due` gracefully.** Implement a grace period (typically 7-14 days) with dunning emails before restricting access. Never immediately lock out a paying customer.
6. **Log all billing operations.** Every plan change, refund, and credit must have an audit trail entry with the actor, timestamp, and reason.
7. **Test with Stripe test mode.** Use test API keys and Stripe CLI for local webhook testing. Never use production keys in development or staging.
8. **Use Stripe metadata to link entities.** Always set `tenant_id` in Stripe customer and subscription metadata so webhooks can be correlated to your domain.
9. **Proration MUST be explicit.** Always set `proration_behavior` when modifying subscriptions. Never rely on Stripe defaults.

## PCI Compliance Considerations

- Use Stripe Elements or Stripe Checkout on the frontend. This keeps card data off your servers entirely.
- Never log request bodies that might contain payment information.
- Your Spring Boot application should be SAQ-A or SAQ-A-EP compliant at most.
- Serve all billing pages over HTTPS.
- Use Content Security Policy headers to restrict which domains can load scripts on billing pages.

## Examples

### Example 1: Complete checkout flow (React frontend)

```tsx
function CheckoutForm({ planSlug, interval }: { planSlug: string; interval: 'month' | 'year' }) {
  const stripe = useStripe();
  const elements = useElements();
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;
    setLoading(true);

    const { error, paymentMethod } = await stripe.createPaymentMethod({
      type: 'card',
      card: elements.getElement(CardElement)!,
    });

    if (error) {
      toast.error(error.message);
      setLoading(false);
      return;
    }

    const response = await api.post('/api/v1/billing/subscribe', {
      planSlug,
      interval,
      paymentMethodId: paymentMethod.id,
    });

    if (response.data.status === 'active' || response.data.status === 'trialing') {
      toast.success('Subscription created!');
      router.push('/dashboard');
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit}>
      <CardElement options={{ style: { base: { fontSize: '16px' } } }} />
      <button type="submit" disabled={!stripe || loading}>
        {loading ? 'Processing...' : 'Subscribe'}
      </button>
    </form>
  );
}
```

### Example 2: Dunning email trigger on payment failure

```java
@Component("invoice.payment_failed")
@RequiredArgsConstructor
public class PaymentFailedHandler implements StripeEventHandler {

    private final TenantSubscriptionRepository subscriptionRepository;
    private final EmailService emailService;
    private final GracePeriodService gracePeriodService;

    @Override
    @Transactional
    public void handle(Event event) {
        Invoice invoice = (Invoice) event.getDataObjectDeserializer().getObject().orElseThrow();
        String customerId = invoice.getCustomer();

        TenantSubscription sub = subscriptionRepository.findByStripeCustomerId(customerId).orElseThrow();
        sub.setStatus("past_due");
        subscriptionRepository.save(sub);

        // Start grace period (7 days before restricting access)
        gracePeriodService.startGracePeriod(sub.getTenantId(), Duration.ofDays(7));

        // Send dunning email
        emailService.sendPaymentFailedEmail(
            sub.getTenantId(),
            invoice.getAmountDue(),
            invoice.getNextPaymentAttempt() != null
                ? Instant.ofEpochSecond(invoice.getNextPaymentAttempt()) : null
        );
    }
}
```
