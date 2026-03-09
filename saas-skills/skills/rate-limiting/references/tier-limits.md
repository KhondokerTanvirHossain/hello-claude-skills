# Rate Limits Per Tier

## Global Rate Limits

| Tier | Requests/Minute | Requests/Hour | Requests/Day | Burst (per second) |
|------|-----------------|---------------|-------------|-------------------|
| Free | 100 | 3,000 | 50,000 | 10 |
| Pro | 1,000 | 30,000 | 500,000 | 50 |
| Enterprise | 10,000 | 300,000 | 5,000,000 | 200 |
| Unauthenticated | 20 | 500 | 5,000 | 5 |

## Per-Endpoint Overrides

Some endpoints have tighter limits to protect expensive operations:

### Write-Heavy Endpoints

| Endpoint | Method | Free | Pro | Enterprise |
|----------|--------|------|-----|------------|
| `/api/v1/projects` | POST | 10/min | 50/min | 200/min |
| `/api/v1/deployments` | POST | 5/min | 30/min | 100/min |
| `/api/v1/webhooks` | POST | 5/min | 20/min | 100/min |
| `/api/v1/bulk/*` | POST | 2/min | 10/min | 50/min |
| `/api/v1/imports` | POST | 1/min | 5/min | 20/min |

### Search and Report Endpoints

| Endpoint | Method | Free | Pro | Enterprise |
|----------|--------|------|-----|------------|
| `/api/v1/search` | GET | 30/min | 200/min | 1,000/min |
| `/api/v1/analytics/reports` | GET | 5/min | 30/min | 100/min |
| `/api/v1/exports` | POST | 2/min | 10/min | 50/min |

### Authentication Endpoints

| Endpoint | Method | All Tiers |
|----------|--------|-----------|
| `/api/v1/auth/login` | POST | 10/min per IP |
| `/api/v1/auth/register` | POST | 5/min per IP |
| `/api/v1/auth/forgot-password` | POST | 3/min per IP |
| `/api/v1/auth/verify-email` | POST | 5/min per IP |

## Response Headers

Every API response includes rate limit headers:

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 847
X-RateLimit-Reset: 1709942460
X-RateLimit-Policy: 1000;w=60
Retry-After: 12
```

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Max requests allowed in the current window | `1000` |
| `X-RateLimit-Remaining` | Requests remaining in the current window | `847` |
| `X-RateLimit-Reset` | Unix timestamp when the window resets | `1709942460` |
| `X-RateLimit-Policy` | Rate limit policy (requests;window in seconds) | `1000;w=60` |
| `Retry-After` | Seconds to wait before retrying (only on 429) | `12` |

## 429 Too Many Requests Response

When rate limit is exceeded, return RFC 7807 Problem Details:

```json
{
  "type": "https://api.yourapp.com/problems/rate-limit-exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded the rate limit of 100 requests per minute for the Free tier. Upgrade to Pro for 1,000 requests per minute.",
  "instance": "/api/v1/projects",
  "limit": 100,
  "remaining": 0,
  "resetAt": "2026-03-09T14:35:00Z",
  "retryAfter": 12,
  "tier": "free",
  "upgradeUrl": "https://app.yourapp.com/settings/billing/upgrade"
}
```

## Spring Boot Implementation

### Rate Limit Filter

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimitService rateLimitService;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {

        String clientKey = resolveClientKey(request);
        String endpoint = request.getMethod() + " " + request.getRequestURI();

        RateLimitResult result = rateLimitService.checkLimit(clientKey, endpoint);

        // Always set rate limit headers
        response.setHeader("X-RateLimit-Limit", String.valueOf(result.getLimit()));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.getRemaining()));
        response.setHeader("X-RateLimit-Reset", String.valueOf(result.getResetEpoch()));
        response.setHeader("X-RateLimit-Policy", result.getLimit() + ";w=60");

        if (!result.isAllowed()) {
            response.setStatus(429);
            response.setHeader("Retry-After", String.valueOf(result.getRetryAfter()));
            response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);

            var problem = ProblemDetail.forStatusAndDetail(
                HttpStatusCode.valueOf(429),
                String.format("You have exceeded the rate limit of %d requests per minute for the %s tier.",
                    result.getLimit(), result.getTier()));
            problem.setType(URI.create("https://api.yourapp.com/problems/rate-limit-exceeded"));
            problem.setTitle("Rate Limit Exceeded");
            problem.setProperty("limit", result.getLimit());
            problem.setProperty("remaining", 0);
            problem.setProperty("resetAt", Instant.ofEpochSecond(result.getResetEpoch()).toString());
            problem.setProperty("retryAfter", result.getRetryAfter());
            problem.setProperty("tier", result.getTier());
            problem.setProperty("upgradeUrl", "https://app.yourapp.com/settings/billing/upgrade");

            objectMapper.writeValue(response.getOutputStream(), problem);
            return;
        }

        chain.doFilter(request, response);
    }

    private String resolveClientKey(HttpServletRequest request) {
        // Authenticated: use tenant ID
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof TenantPrincipal tp) {
            return "tenant:" + tp.getTenantId();
        }
        // Unauthenticated: use IP
        return "ip:" + request.getRemoteAddr();
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        // Skip rate limiting for health checks and webhook endpoints
        return request.getRequestURI().startsWith("/actuator/")
            || request.getRequestURI().startsWith("/api/webhooks/");
    }
}
```

### Rate Limit Service (Sliding Window with Redis)

```java
@Service
public class RateLimitService {

    private final StringRedisTemplate redis;
    private final SubscriptionService subscriptionService;
    private final EndpointRateLimitConfig endpointConfig;

    public RateLimitResult checkLimit(String clientKey, String endpoint) {
        // Determine tier and applicable limit
        String tier = resolveTier(clientKey);
        int limit = endpointConfig.getLimitFor(endpoint, tier)
            .orElse(getGlobalLimit(tier));

        String redisKey = "ratelimit:" + clientKey + ":" + currentMinuteWindow();

        // Sliding window counter
        Long currentCount = redis.opsForValue().increment(redisKey);
        if (currentCount == 1) {
            redis.expire(redisKey, Duration.ofMinutes(1));
        }

        long remaining = Math.max(0, limit - currentCount);
        long resetEpoch = nextMinuteEpoch();
        boolean allowed = currentCount <= limit;
        int retryAfter = allowed ? 0 : (int)(resetEpoch - Instant.now().getEpochSecond());

        return new RateLimitResult(allowed, limit, (int) remaining, resetEpoch, retryAfter, tier);
    }

    private int getGlobalLimit(String tier) {
        return switch (tier) {
            case "free" -> 100;
            case "pro" -> 1000;
            case "enterprise" -> 10000;
            default -> 20; // unauthenticated
        };
    }

    private String currentMinuteWindow() {
        return String.valueOf(Instant.now().getEpochSecond() / 60);
    }

    private long nextMinuteEpoch() {
        long now = Instant.now().getEpochSecond();
        return ((now / 60) + 1) * 60;
    }
}
```

### Endpoint Override Configuration

```yaml
# application.yml
rate-limiting:
  endpoint-overrides:
    "POST /api/v1/projects":
      free: 10
      pro: 50
      enterprise: 200
    "POST /api/v1/deployments":
      free: 5
      pro: 30
      enterprise: 100
    "POST /api/v1/bulk/*":
      free: 2
      pro: 10
      enterprise: 50
    "GET /api/v1/search":
      free: 30
      pro: 200
      enterprise: 1000
    "POST /api/v1/exports":
      free: 2
      pro: 10
      enterprise: 50
  auth-endpoints:
    "POST /api/v1/auth/login": 10       # per IP
    "POST /api/v1/auth/register": 5     # per IP
    "POST /api/v1/auth/forgot-password": 3  # per IP
```

## Client-Side Handling (TypeScript)

```typescript
import { createClient } from 'openapi-fetch';

const client = createClient<paths>({ baseUrl: '/api/v1' });

async function fetchWithRateLimitHandling<T>(
  fetcher: () => Promise<{ data?: T; response: Response }>
): Promise<T> {
  const { data, response } = await fetcher();

  // Log rate limit status
  const remaining = response.headers.get('X-RateLimit-Remaining');
  const limit = response.headers.get('X-RateLimit-Limit');
  console.debug(`Rate limit: ${remaining}/${limit} remaining`);

  // Warn when approaching limit
  if (remaining && parseInt(remaining) < parseInt(limit!) * 0.1) {
    console.warn('Approaching rate limit, slow down requests');
  }

  if (response.status === 429) {
    const retryAfter = parseInt(response.headers.get('Retry-After') || '60');
    console.warn(`Rate limited. Retrying after ${retryAfter}s`);
    await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
    return fetchWithRateLimitHandling(fetcher); // retry
  }

  if (!data) {
    throw new Error(`API error: ${response.status}`);
  }

  return data;
}
```

## Monitoring

### Key Metrics to Track

| Metric | Alert Threshold | Description |
|--------|-----------------|-------------|
| `rate_limit_hits_total` | > 100/min for any single tenant | Total 429 responses served |
| `rate_limit_remaining_ratio` | < 10% for > 5 min | Ratio of remaining to limit |
| `rate_limit_bypass_attempts` | Any occurrence | Attempts to circumvent limits |
| `rate_limit_tier_distribution` | Unusual spikes | 429s broken down by tier |

### Prometheus Metrics

```java
@Component
public class RateLimitMetrics {

    private final Counter rateLimitHits = Counter.builder("rate_limit_hits_total")
        .description("Total rate limit exceeded responses")
        .tag("tier", "unknown")
        .register(Metrics.globalRegistry);

    private final Gauge rateLimitRemaining = Gauge.builder("rate_limit_remaining_ratio",
            () -> 0.0)
        .description("Ratio of remaining requests to limit")
        .register(Metrics.globalRegistry);

    public void recordHit(String tier, String endpoint) {
        rateLimitHits.increment();
        Counter.builder("rate_limit_hits_total")
            .tag("tier", tier)
            .tag("endpoint", endpoint)
            .register(Metrics.globalRegistry)
            .increment();
    }
}
```
