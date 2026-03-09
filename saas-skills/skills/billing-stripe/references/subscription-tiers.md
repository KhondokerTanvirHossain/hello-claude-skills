# Subscription Tiers

## Tier Overview

| | Free | Pro | Enterprise |
|---|---|---|---|
| **Price (monthly)** | $0 | $29/seat/mo | Custom |
| **Price (annual)** | $0 | $24/seat/mo (billed annually) | Custom |
| **Seats** | 1 | Up to 25 | Unlimited |
| **Trial** | N/A | 14-day free trial | 30-day POC |
| **Support** | Community | Email (24h SLA) | Dedicated CSM + Slack |

## Stripe Product and Price IDs

### Products

| Tier | Stripe Product ID | Environment |
|------|-------------------|-------------|
| Free | `prod_free_001` | Production |
| Pro | `prod_pro_001` | Production |
| Enterprise | `prod_ent_001` | Production |
| Free | `prod_free_test_001` | Staging/Test |
| Pro | `prod_pro_test_001` | Staging/Test |
| Enterprise | `prod_ent_test_001` | Staging/Test |

### Prices

| Tier | Billing Cycle | Stripe Price ID | Amount |
|------|---------------|-----------------|--------|
| Free | -- | -- | $0 |
| Pro | Monthly | `price_pro_monthly` | $29.00/seat |
| Pro | Annual | `price_pro_annual` | $288.00/seat/year |
| Enterprise | Monthly | `price_ent_monthly` | Custom |
| Enterprise | Annual | `price_ent_annual` | Custom |

### Metered Usage Prices

| Feature | Stripe Price ID | Unit | Included Free | Pro Included | Enterprise Included |
|---------|-----------------|------|---------------|-------------|-------------------|
| API Calls | `price_meter_api` | per 1,000 calls | 1,000/mo | 50,000/mo | Unlimited |
| Storage | `price_meter_storage` | per GB | 500 MB | 50 GB | Unlimited |
| Webhooks | `price_meter_webhooks` | per 1,000 events | 500/mo | 25,000/mo | Unlimited |

## Feature Entitlements Per Tier

### Core Features

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Projects | 3 | Unlimited | Unlimited |
| API keys | 1 | 10 | Unlimited |
| Team members | 1 | 25 | Unlimited |
| Environments | 1 (prod only) | 3 (dev/staging/prod) | Unlimited |
| Audit log retention | 7 days | 90 days | 1 year |
| Custom domain | No | Yes | Yes |
| SSO (SAML/OIDC) | No | No | Yes |
| Role-based access | Basic (admin/member) | Full (custom roles) | Full + custom policies |
| SLA | None | 99.9% | 99.99% |

### API Features

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Rate limit | 100 req/min | 1,000 req/min | 10,000 req/min |
| Batch API | No | Yes | Yes |
| Webhooks | 3 endpoints | 25 endpoints | Unlimited |
| GraphQL API | No | Yes | Yes |
| Dedicated IP | No | No | Yes |

### Analytics Features

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Dashboard | Basic | Advanced | Custom |
| Data export | CSV | CSV + JSON + API | All + warehouse sync |
| Real-time analytics | No | Yes | Yes |
| Custom reports | No | 5 | Unlimited |

## Application Configuration

### Spring Boot Tier Enum

```java
public enum SubscriptionTier {
    FREE("free", "prod_free_001", "price_free_none"),
    PRO("pro", "prod_pro_001", "price_pro_monthly"),
    ENTERPRISE("enterprise", "prod_ent_001", "price_ent_monthly");

    private final String key;
    private final String stripeProductId;
    private final String defaultStripePriceId;

    // constructor, getters...

    public static SubscriptionTier fromStripeProductId(String productId) {
        return Arrays.stream(values())
            .filter(t -> t.stripeProductId.equals(productId))
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException(
                "Unknown Stripe product: " + productId));
    }
}
```

### Tier Limits Configuration

```yaml
# application.yml
subscription:
  tiers:
    free:
      max-projects: 3
      max-api-keys: 1
      max-team-members: 1
      max-environments: 1
      rate-limit-per-minute: 100
      max-webhook-endpoints: 3
      storage-gb: 0.5
      api-calls-per-month: 1000
      audit-log-retention-days: 7
    pro:
      max-projects: -1  # unlimited
      max-api-keys: 10
      max-team-members: 25
      max-environments: 3
      rate-limit-per-minute: 1000
      max-webhook-endpoints: 25
      storage-gb: 50
      api-calls-per-month: 50000
      audit-log-retention-days: 90
    enterprise:
      max-projects: -1
      max-api-keys: -1
      max-team-members: -1
      max-environments: -1
      rate-limit-per-minute: 10000
      max-webhook-endpoints: -1
      storage-gb: -1
      api-calls-per-month: -1
      audit-log-retention-days: 365
```

## Upgrade and Downgrade Rules

### Upgrade (Free -> Pro, Pro -> Enterprise)

1. **Immediate access**: New features unlock instantly upon successful payment
2. **Prorated billing**: Stripe calculates proration automatically (`proration_behavior: create_prorations`)
3. **Data retention**: All existing data preserved
4. **Trial credit**: If upgrading during trial, unused trial days are not credited
5. **Seat-based**: New seat count takes effect immediately

```java
public SubscriptionUpdateResult upgrade(UUID tenantId, SubscriptionTier newTier, BillingCycle cycle) {
    var subscription = subscriptionRepository.findByTenantId(tenantId)
        .orElseThrow(() -> new SubscriptionNotFoundException(tenantId));

    if (newTier.ordinal() <= subscription.getTier().ordinal()) {
        throw new InvalidUpgradeException("Can only upgrade to a higher tier");
    }

    // Update Stripe subscription
    var stripeSubscription = Subscription.retrieve(subscription.getStripeSubscriptionId());
    var params = SubscriptionUpdateParams.builder()
        .addItem(SubscriptionUpdateParams.Item.builder()
            .setId(stripeSubscription.getItems().getData().get(0).getId())
            .setPrice(newTier.getPriceId(cycle))
            .build())
        .setProrationBehavior(SubscriptionUpdateParams.ProrationBehavior.CREATE_PRORATIONS)
        .build();

    stripeSubscription.update(params);

    // Update local subscription record
    subscription.setTier(newTier);
    subscription.setBillingCycle(cycle);
    subscription.setUpdatedAt(Instant.now());
    subscriptionRepository.save(subscription);

    // Publish domain event for downstream services
    eventPublisher.publish(new SubscriptionUpgradedEvent(tenantId, newTier));

    return new SubscriptionUpdateResult(subscription, "Upgrade successful");
}
```

### Downgrade (Enterprise -> Pro, Pro -> Free)

1. **End of billing period**: Downgrade takes effect at end of current billing cycle
2. **Grace period**: 7-day grace period to re-upgrade without data loss
3. **Data limits**: If data exceeds new tier limits, existing data is preserved but user cannot create new items until under limit
4. **Feature access**: Premium features remain accessible until billing period ends
5. **Notification**: Send email 3 days before downgrade takes effect

| Scenario | Behavior |
|----------|----------|
| Projects exceed new limit | Read-only access to excess projects, cannot create new |
| Team members exceed new limit | Owner must remove members before downgrade completes |
| API keys exceed new limit | Excess keys deactivated (oldest first) |
| Webhooks exceed new limit | Excess endpoints paused |
| Storage exceeds new limit | Read-only until under limit, no new uploads |

### Trial Configuration

```yaml
trial:
  duration-days: 14
  tier: pro  # trial gets Pro features
  require-payment-method: false  # no card required to start trial
  extend-eligible: true  # sales can extend trial
  max-extension-days: 14  # maximum 14-day extension
  convert-to-on-expiry: free  # revert to Free if no payment after trial
  reminder-emails:
    - days-before-expiry: 7
    - days-before-expiry: 3
    - days-before-expiry: 1
    - days-after-expiry: 1  # "Your trial ended" email
```

## Database Schema

```sql
CREATE TABLE subscriptions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    tier                    VARCHAR(20) NOT NULL DEFAULT 'free'
                                CHECK (tier IN ('free', 'pro', 'enterprise')),
    billing_cycle           VARCHAR(10) CHECK (billing_cycle IN ('monthly', 'annual')),
    status                  VARCHAR(20) NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active', 'trialing', 'past_due', 'canceled', 'paused')),
    stripe_customer_id      VARCHAR(100),
    stripe_subscription_id  VARCHAR(100),
    stripe_product_id       VARCHAR(100),
    stripe_price_id         VARCHAR(100),
    trial_start             TIMESTAMPTZ,
    trial_end               TIMESTAMPTZ,
    current_period_start    TIMESTAMPTZ,
    current_period_end      TIMESTAMPTZ,
    cancel_at_period_end    BOOLEAN NOT NULL DEFAULT false,
    seat_count              INT NOT NULL DEFAULT 1,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id)
);

CREATE INDEX idx_sub_tenant   ON subscriptions(tenant_id);
CREATE INDEX idx_sub_stripe   ON subscriptions(stripe_subscription_id);
CREATE INDEX idx_sub_status   ON subscriptions(status);
```
