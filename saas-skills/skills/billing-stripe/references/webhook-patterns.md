# Stripe Webhook Patterns

## Critical Webhooks

These are the Stripe events you MUST handle. Missing any of these will cause billing inconsistencies.

### Tier 1 -- Must Handle (Business-Critical)

| Event | When It Fires | What To Do |
|-------|---------------|------------|
| `checkout.session.completed` | Customer completes Checkout | Create/activate subscription, provision resources |
| `invoice.paid` | Recurring payment succeeds | Extend subscription period, reset usage counters |
| `invoice.payment_failed` | Payment attempt fails | Mark subscription `past_due`, notify customer, schedule retry |
| `customer.subscription.updated` | Plan change, quantity change, trial end | Sync tier/seat changes to local DB |
| `customer.subscription.deleted` | Subscription canceled (end of period) | Downgrade to Free tier, revoke premium features |
| `customer.subscription.trial_will_end` | 3 days before trial ends | Send trial-ending email, prompt for payment method |

### Tier 2 -- Should Handle (Important)

| Event | When It Fires | What To Do |
|-------|---------------|------------|
| `invoice.created` | Upcoming invoice finalized | Apply any credits/coupons, validate line items |
| `invoice.finalized` | Invoice locked for payment | Log for audit trail |
| `customer.updated` | Customer email/name changes | Sync customer profile |
| `payment_method.attached` | New payment method added | Update default payment method if first one |
| `payment_method.detached` | Payment method removed | Warn if last payment method removed |
| `charge.refunded` | Refund processed | Log refund, adjust usage if applicable |

### Tier 3 -- Nice to Have (Monitoring)

| Event | When It Fires | What To Do |
|-------|---------------|------------|
| `charge.succeeded` | Any successful charge | Metrics/analytics |
| `charge.failed` | Any failed charge | Alert/monitoring |
| `customer.discount.created` | Coupon applied | Log for analytics |
| `billing_portal.session.created` | Customer opens billing portal | Audit log |

## Webhook Endpoint Configuration

### Spring Boot Controller

```java
@RestController
@RequestMapping("/api/webhooks/stripe")
@Slf4j
public class StripeWebhookController {

    @Value("${stripe.webhook-secret}")
    private String webhookSecret;

    private final StripeEventHandler eventHandler;

    @PostMapping
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            log.warn("Invalid Stripe webhook signature: {}", e.getMessage());
            return ResponseEntity.status(400).body("Invalid signature");
        }

        log.info("Received Stripe event: type={}, id={}", event.getType(), event.getId());

        try {
            eventHandler.handle(event);
        } catch (Exception e) {
            log.error("Error processing Stripe event {}: {}", event.getId(), e.getMessage(), e);
            // Return 500 so Stripe retries
            return ResponseEntity.status(500).body("Processing error");
        }

        return ResponseEntity.ok("OK");
    }
}
```

## Signature Verification

NEVER skip signature verification. Every webhook request must be validated.

```java
// application.yml
stripe:
  api-key: ${STRIPE_API_KEY}
  webhook-secret: ${STRIPE_WEBHOOK_SECRET}  # whsec_... from Stripe Dashboard

// SecurityConfig.java -- exempt webhook endpoint from CSRF/JWT
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf
            .ignoringRequestMatchers("/api/webhooks/**"))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/webhooks/**").permitAll()
            // ... other rules
        )
        .build();
}
```

**Important**: Use the raw request body for signature verification. Do NOT parse JSON first. Spring Boot may need a filter to capture the raw body:

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RawBodyCaptureFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {
        if (request.getRequestURI().startsWith("/api/webhooks/")) {
            var wrappedRequest = new ContentCachingRequestWrapper(request);
            chain.doFilter(wrappedRequest, response);
        } else {
            chain.doFilter(request, response);
        }
    }
}
```

## Idempotency

Stripe may send the same event multiple times. Your handler MUST be idempotent.

### Idempotency Strategy

```java
@Service
public class StripeEventHandler {

    private final ProcessedEventRepository processedEventRepo;

    @Transactional
    public void handle(Event event) {
        // 1. Check if already processed
        if (processedEventRepo.existsByStripeEventId(event.getId())) {
            log.info("Skipping already-processed event: {}", event.getId());
            return;
        }

        // 2. Process the event
        switch (event.getType()) {
            case "checkout.session.completed" -> handleCheckoutCompleted(event);
            case "invoice.paid" -> handleInvoicePaid(event);
            case "invoice.payment_failed" -> handlePaymentFailed(event);
            case "customer.subscription.updated" -> handleSubscriptionUpdated(event);
            case "customer.subscription.deleted" -> handleSubscriptionDeleted(event);
            case "customer.subscription.trial_will_end" -> handleTrialEnding(event);
            default -> log.info("Unhandled event type: {}", event.getType());
        }

        // 3. Record as processed
        processedEventRepo.save(new ProcessedEvent(
            event.getId(),
            event.getType(),
            Instant.now()
        ));
    }
}
```

### Processed Events Table

```sql
CREATE TABLE stripe_processed_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id VARCHAR(100) NOT NULL UNIQUE,
    event_type      VARCHAR(100) NOT NULL,
    processed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata        JSONB DEFAULT '{}'
);

CREATE INDEX idx_stripe_events_id ON stripe_processed_events(stripe_event_id);

-- Cleanup: remove events older than 90 days
-- Run via scheduled job
DELETE FROM stripe_processed_events WHERE processed_at < now() - INTERVAL '90 days';
```

## Retry Behavior

Stripe retries failed webhooks (non-2xx response) with exponential backoff:

| Attempt | Delay After Previous |
|---------|---------------------|
| 1 | Immediate |
| 2 | 5 minutes |
| 3 | 30 minutes |
| 4 | 2 hours |
| 5 | 5 hours |
| 6 | 10 hours |
| 7+ | ~1 day (up to 3 days total) |

**Rules for retry handling:**

1. Return `200 OK` immediately after recording the event, even if downstream processing is async
2. Return `500` only if you genuinely failed to record the event -- this triggers a retry
3. Never return `400` unless signature verification fails -- Stripe will not retry 4xx responses
4. Process heavy work asynchronously to avoid timeout (Stripe times out after 20 seconds)

### Async Processing Pattern

```java
@Service
public class StripeEventHandler {

    private final ApplicationEventPublisher eventPublisher;
    private final ProcessedEventRepository processedEventRepo;

    @Transactional
    public void handle(Event event) {
        if (processedEventRepo.existsByStripeEventId(event.getId())) {
            return; // idempotent
        }

        // Record immediately
        processedEventRepo.save(new ProcessedEvent(event.getId(), event.getType(), Instant.now()));

        // Dispatch to async handler via Spring Events
        eventPublisher.publishEvent(new StripeEventReceived(event));
    }
}

@Component
@Slf4j
public class StripeEventAsyncProcessor {

    @Async
    @EventListener
    public void onStripeEvent(StripeEventReceived received) {
        var event = received.getEvent();
        try {
            switch (event.getType()) {
                case "checkout.session.completed" -> processCheckout(event);
                case "invoice.paid" -> processInvoicePaid(event);
                // ...
            }
        } catch (Exception e) {
            log.error("Async processing failed for event {}: {}", event.getId(), e.getMessage(), e);
            // Send to dead letter queue
            deadLetterQueue.enqueue(event);
        }
    }
}
```

## Event Ordering

Stripe does NOT guarantee event delivery order. Handle this:

| Scenario | Problem | Solution |
|----------|---------|----------|
| `subscription.updated` arrives before `checkout.session.completed` | Subscription does not exist locally yet | Check if subscription exists; if not, fetch from Stripe API and create |
| `invoice.paid` arrives twice | Duplicate payment processing | Idempotency check on `stripe_event_id` |
| `subscription.deleted` arrives before `subscription.updated` | Update overwrites deletion | Compare `event.created` timestamps; reject stale events |

### Timestamp Guard

```java
private void handleSubscriptionUpdated(Event event) {
    var stripeSubscription = deserializeSubscription(event);
    var localSubscription = subscriptionRepo
        .findByStripeSubscriptionId(stripeSubscription.getId())
        .orElse(null);

    if (localSubscription == null) {
        // Subscription not yet in our system -- fetch and create
        log.warn("Subscription {} not found locally, creating from Stripe", stripeSubscription.getId());
        createFromStripe(stripeSubscription);
        return;
    }

    // Reject stale events
    if (event.getCreated() < localSubscription.getLastStripeEventTimestamp()) {
        log.info("Skipping stale event for subscription {}", stripeSubscription.getId());
        return;
    }

    // Apply update
    localSubscription.setTier(SubscriptionTier.fromStripeProductId(
        stripeSubscription.getItems().getData().get(0).getPrice().getProduct()));
    localSubscription.setStatus(mapStatus(stripeSubscription.getStatus()));
    localSubscription.setLastStripeEventTimestamp(event.getCreated());
    subscriptionRepo.save(localSubscription);
}
```

## Dead Letter Queue

Events that fail processing after async retries go to a dead letter queue for manual review.

```sql
CREATE TABLE stripe_dead_letter_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id VARCHAR(100) NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    payload         JSONB NOT NULL,
    error_message   TEXT,
    retry_count     INT NOT NULL DEFAULT 0,
    max_retries     INT NOT NULL DEFAULT 3,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'retrying', 'failed', 'resolved')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_retry_at   TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX idx_dlq_status ON stripe_dead_letter_queue(status);
```

### DLQ Processing

```java
@Scheduled(fixedDelay = 300_000) // every 5 minutes
public void retryDeadLetterQueue() {
    var pending = dlqRepository.findByStatusAndRetryCountLessThan("pending", 3);

    for (var entry : pending) {
        try {
            entry.setStatus("retrying");
            entry.setRetryCount(entry.getRetryCount() + 1);
            entry.setLastRetryAt(Instant.now());
            dlqRepository.save(entry);

            var event = Event.GSON.fromJson(entry.getPayload().toString(), Event.class);
            eventHandler.handle(event);

            entry.setStatus("resolved");
            entry.setResolvedAt(Instant.now());
        } catch (Exception e) {
            if (entry.getRetryCount() >= entry.getMaxRetries()) {
                entry.setStatus("failed");
                entry.setErrorMessage(e.getMessage());
                // Alert ops team
                alertService.sendSlackAlert(
                    "Stripe DLQ event permanently failed: " + entry.getStripeEventId());
            } else {
                entry.setStatus("pending");
            }
        }
        dlqRepository.save(entry);
    }
}
```

## Testing Webhooks

### Local Development

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward events to local server
stripe listen --forward-to http://localhost:8080/api/webhooks/stripe

# Trigger specific events for testing
stripe trigger checkout.session.completed
stripe trigger invoice.paid
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted
```

### Integration Test

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class StripeWebhookIntegrationTest {

    @Test
    void shouldHandleCheckoutCompleted() throws Exception {
        var payload = loadFixture("stripe/checkout_session_completed.json");
        var signature = generateTestSignature(payload, testWebhookSecret);

        mockMvc.perform(post("/api/webhooks/stripe")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Stripe-Signature", signature)
                .content(payload))
            .andExpect(status().isOk());

        // Verify subscription was created
        var subscription = subscriptionRepo.findByTenantId(testTenantId);
        assertThat(subscription).isPresent();
        assertThat(subscription.get().getTier()).isEqualTo(SubscriptionTier.PRO);
    }

    @Test
    void shouldRejectInvalidSignature() throws Exception {
        mockMvc.perform(post("/api/webhooks/stripe")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Stripe-Signature", "invalid_signature")
                .content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void shouldBeIdempotent() throws Exception {
        var payload = loadFixture("stripe/invoice_paid.json");
        var signature = generateTestSignature(payload, testWebhookSecret);

        // Send same event twice
        mockMvc.perform(post("/api/webhooks/stripe")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Stripe-Signature", signature)
                .content(payload))
            .andExpect(status().isOk());

        mockMvc.perform(post("/api/webhooks/stripe")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Stripe-Signature", signature)
                .content(payload))
            .andExpect(status().isOk());

        // Verify only processed once
        assertThat(processedEventRepo.count()).isEqualTo(1);
    }
}
```
