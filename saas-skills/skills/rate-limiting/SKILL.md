---
name: rate-limiting
description: Rate limiting implementation patterns for Spring Boot APIs including per-tenant limits, plan-based tiers, token bucket algorithm, and rate limit headers
tech_stack:
  - Java 21
  - Spring Boot 3.x
  - Redis
  - PostgreSQL
  - Gradle
tags:
  - rate-limiting
  - api
  - redis
  - throttling
  - saas
  - performance
---

# Rate Limiting Implementation Patterns

## Purpose

Provide production-ready rate limiting patterns for SaaS APIs built with Spring Boot. Rate limiting protects backend services from abuse, ensures fair resource distribution across tenants, enforces plan-tier boundaries, and provides a predictable API experience. This skill covers algorithm selection, distributed implementation with Redis, per-tenant and per-plan configuration, response header conventions, and graceful degradation strategies.

## When to Use

- Protecting public and authenticated API endpoints from abuse and accidental overload.
- Enforcing different API rate limits based on subscription plan tier (Free, Starter, Pro, Enterprise).
- Implementing per-API-key rate limits for third-party integrations.
- Adding burst allowance on top of sustained rate limits.
- Providing standardized rate limit headers so API consumers can self-throttle.
- Building admin controls to temporarily increase or decrease limits for specific tenants.

## Algorithm Selection

### Token Bucket (Recommended for SaaS APIs)

The token bucket algorithm is the best fit for SaaS APIs because it naturally supports burst traffic while enforcing sustained rate limits.

**How it works:**
- A bucket holds up to `maxTokens` tokens (the burst capacity).
- Tokens are added at a fixed rate of `refillRate` tokens per `refillInterval`.
- Each request consumes one token. If the bucket is empty, the request is rejected.
- Buckets are per-tenant (or per-API-key, per-user, per-IP depending on use case).

**Advantages:**
- Allows short bursts (a user can make 10 rapid requests if they haven't used the API recently).
- Simple to implement in Redis with atomic operations.
- Intuitive for API consumers to understand.

### Sliding Window (Alternative for Strict Limits)

Use a sliding window counter when you need strict per-second or per-minute enforcement without any burst tolerance. This is more appropriate for financial APIs or compliance-sensitive endpoints.

## Workflow: Implementation

### Step 1: Define Tier-Based Rate Limits

```java
public record RateLimitConfig(
    int requestsPerHour,
    int requestsPerMinute,
    int burstCapacity,
    int refillRatePerSecond
) {
    public static RateLimitConfig forTier(String tier) {
        return switch (tier) {
            case "FREE"       -> new RateLimitConfig(1000,   20,   5,   1);
            case "STARTER"    -> new RateLimitConfig(5000,   100,  20,  2);
            case "PRO"        -> new RateLimitConfig(25000,  500,  50,  10);
            case "ENTERPRISE" -> new RateLimitConfig(100000, 2000, 200, 40);
            default -> throw new IllegalArgumentException("Unknown tier: " + tier);
        };
    }
}
```

### Step 2: Redis-Backed Token Bucket

**Lua script for atomic token bucket operations:**

```lua
-- rate_limit.lua
-- KEYS[1] = rate limit key (e.g., "ratelimit:tenant:{tenantId}")
-- ARGV[1] = max tokens (burst capacity)
-- ARGV[2] = refill rate (tokens per second)
-- ARGV[3] = current timestamp in milliseconds
-- ARGV[4] = tokens to consume (usually 1)
-- Returns: {allowed (0 or 1), remaining tokens, reset timestamp in ms}

local key = KEYS[1]
local maxTokens = tonumber(ARGV[1])
local refillRate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
local tokens = tonumber(bucket[1])
local lastRefill = tonumber(bucket[2])

-- Initialize bucket if it doesn't exist
if tokens == nil then
    tokens = maxTokens
    lastRefill = now
end

-- Calculate tokens to add since last refill
local elapsed = (now - lastRefill) / 1000.0 -- convert ms to seconds
local tokensToAdd = elapsed * refillRate
tokens = math.min(maxTokens, tokens + tokensToAdd)

-- Check if request can be served
local allowed = 0
local remaining = tokens

if tokens >= requested then
    tokens = tokens - requested
    remaining = tokens
    allowed = 1
end

-- Calculate reset time (when bucket will be full again)
local tokensNeeded = maxTokens - tokens
local resetInMs = 0
if tokensNeeded > 0 and refillRate > 0 then
    resetInMs = math.ceil((tokensNeeded / refillRate) * 1000)
end
local resetTimestamp = now + resetInMs

-- Update bucket state
redis.call('HMSET', key, 'tokens', tokens, 'last_refill', now)
redis.call('PEXPIRE', key, math.ceil(maxTokens / refillRate) * 1000 + 1000) -- TTL = time to full refill + 1s buffer

return {allowed, math.floor(remaining), resetTimestamp}
```

**Redis rate limiter service:**

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class RedisRateLimiter {

    private final StringRedisTemplate redisTemplate;
    private final DefaultRedisScript<List<Long>> rateLimitScript;

    @PostConstruct
    void init() {
        // Load the Lua script
        rateLimitScript = new DefaultRedisScript<>();
        rateLimitScript.setLocation(new ClassPathResource("scripts/rate_limit.lua"));
        rateLimitScript.setResultType((Class) List.class);
    }

    public RateLimitResult tryConsume(String key, RateLimitConfig config) {
        List<Long> result = redisTemplate.execute(
            rateLimitScript,
            List.of("ratelimit:" + key),
            String.valueOf(config.burstCapacity()),
            String.valueOf(config.refillRatePerSecond()),
            String.valueOf(System.currentTimeMillis()),
            "1"
        );

        boolean allowed = result.get(0) == 1L;
        long remaining = result.get(1);
        long resetTimestamp = result.get(2);

        return new RateLimitResult(allowed, config.burstCapacity(), remaining, resetTimestamp);
    }

    public record RateLimitResult(
        boolean allowed,
        long limit,
        long remaining,
        long resetTimestampMs
    ) {
        public long resetEpochSeconds() {
            return resetTimestampMs / 1000;
        }
    }
}
```

### Step 3: Spring Boot Filter

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10) // Run early, but after security filters
@RequiredArgsConstructor
@Slf4j
public class RateLimitFilter extends OncePerRequestFilter {

    private final RedisRateLimiter rateLimiter;
    private final TenantContextHolder tenantContextHolder;
    private final PlanLimitResolver planLimitResolver;
    private final ObjectMapper objectMapper;

    private static final Set<String> EXCLUDED_PATHS = Set.of(
        "/health", "/ready", "/metrics", "/api/webhooks"
    );

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return EXCLUDED_PATHS.stream().anyMatch(path::startsWith);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String rateLimitKey = resolveRateLimitKey(request);
        RateLimitConfig config = resolveConfig(request);

        RedisRateLimiter.RateLimitResult result = rateLimiter.tryConsume(rateLimitKey, config);

        // Always set rate limit headers, even on allowed requests
        setRateLimitHeaders(response, result, config);

        if (!result.allowed()) {
            log.warn("Rate limit exceeded for key: {} (limit: {}/hr)", rateLimitKey, config.requestsPerHour());
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);

            Map<String, Object> errorBody = Map.of(
                "error", "rate_limit_exceeded",
                "message", "API rate limit exceeded. Please retry after the reset time.",
                "retry_after_seconds", Math.max(1, (result.resetTimestampMs() - System.currentTimeMillis()) / 1000)
            );
            objectMapper.writeValue(response.getOutputStream(), errorBody);
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String resolveRateLimitKey(HttpServletRequest request) {
        // Priority: API key > Authenticated tenant > IP address
        String apiKey = request.getHeader("X-API-Key");
        if (apiKey != null) {
            return "apikey:" + apiKey;
        }

        TenantContext ctx = tenantContextHolder.getContext();
        if (ctx != null && ctx.getTenantId() != null) {
            return "tenant:" + ctx.getTenantId();
        }

        // Fallback to IP for unauthenticated requests
        String ip = getClientIp(request);
        return "ip:" + ip;
    }

    private RateLimitConfig resolveConfig(HttpServletRequest request) {
        TenantContext ctx = tenantContextHolder.getContext();
        if (ctx != null && ctx.getPlanTier() != null) {
            return RateLimitConfig.forTier(ctx.getPlanTier());
        }
        // Unauthenticated requests get the most restrictive limits
        return RateLimitConfig.forTier("FREE");
    }

    private void setRateLimitHeaders(HttpServletResponse response, RedisRateLimiter.RateLimitResult result, RateLimitConfig config) {
        response.setHeader("X-RateLimit-Limit", String.valueOf(config.requestsPerHour()));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.remaining()));
        response.setHeader("X-RateLimit-Reset", String.valueOf(result.resetEpochSeconds()));

        if (!result.allowed()) {
            long retryAfterSeconds = Math.max(1, (result.resetTimestampMs() - System.currentTimeMillis()) / 1000);
            response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
        }
    }

    private String getClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
```

### Step 4: Rate Limit Response Headers

Every API response MUST include these headers:

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests allowed per hour for the current plan | `5000` |
| `X-RateLimit-Remaining` | Remaining requests in the current window | `4832` |
| `X-RateLimit-Reset` | Unix timestamp (seconds) when the rate limit resets | `1709769600` |
| `Retry-After` | Seconds to wait before retrying (only on 429 responses) | `42` |

### Step 5: Per-Endpoint Rate Limits

Some endpoints need stricter limits than the global tier-based limits. Use a custom annotation:

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface EndpointRateLimit {
    int requestsPerMinute();
    String key() default ""; // additional key suffix for scoping
}

@Aspect
@Component
@RequiredArgsConstructor
public class EndpointRateLimitAspect {

    private final RedisRateLimiter rateLimiter;
    private final TenantContextHolder tenantContextHolder;

    @Around("@annotation(endpointRateLimit)")
    public Object checkEndpointRateLimit(ProceedingJoinPoint joinPoint, EndpointRateLimit endpointRateLimit) throws Throwable {
        TenantContext ctx = tenantContextHolder.getContext();
        String key = "endpoint:" + joinPoint.getSignature().toShortString() + ":" + ctx.getTenantId();

        if (!endpointRateLimit.key().isEmpty()) {
            key += ":" + endpointRateLimit.key();
        }

        RateLimitConfig config = new RateLimitConfig(
            endpointRateLimit.requestsPerMinute() * 60,
            endpointRateLimit.requestsPerMinute(),
            endpointRateLimit.requestsPerMinute() / 2,
            endpointRateLimit.requestsPerMinute() / 60
        );

        RedisRateLimiter.RateLimitResult result = rateLimiter.tryConsume(key, config);
        if (!result.allowed()) {
            throw new RateLimitExceededException(key, config.requestsPerMinute());
        }

        return joinPoint.proceed();
    }
}
```

**Usage:**

```java
@RestController
@RequestMapping("/api/v1/exports")
public class ExportController {

    @EndpointRateLimit(requestsPerMinute = 5)
    @PostMapping("/generate")
    public ResponseEntity<ExportJob> generateExport(@RequestBody ExportRequest request) {
        // Expensive operation, limited to 5 per minute per tenant
    }
}
```

## Graceful Degradation

When Redis is unavailable, the rate limiter MUST NOT block requests. Implement a fallback:

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class ResilientRateLimiter {

    private final RedisRateLimiter redisRateLimiter;

    @CircuitBreaker(name = "rateLimiter", fallbackMethod = "allowWithWarning")
    public RedisRateLimiter.RateLimitResult tryConsume(String key, RateLimitConfig config) {
        return redisRateLimiter.tryConsume(key, config);
    }

    private RedisRateLimiter.RateLimitResult allowWithWarning(String key, RateLimitConfig config, Throwable t) {
        log.warn("Rate limiter Redis unavailable, allowing request for key: {}. Error: {}", key, t.getMessage());
        // Return an "allowed" result but with unknown remaining count
        return new RedisRateLimiter.RateLimitResult(true, config.burstCapacity(), -1, 0);
    }
}
```

## Burst Allowance Pattern

SaaS APIs should allow reasonable bursts. The token bucket naturally handles this, but document it clearly for API consumers:

```
Sustained rate: 100 requests/minute (PRO tier)
Burst capacity: 50 requests (can be used instantly)
Refill rate: ~1.67 tokens/second

Scenario:
- User has been idle for 30 seconds -> bucket has 50 tokens
- User sends 50 requests in 1 second -> all succeed (burst consumed)
- User sends request 51 -> rejected (429), must wait ~0.6 seconds
- After 10 seconds of waiting, bucket has ~17 tokens
```

## Rules

1. **Rate limit headers are mandatory on every API response.** Even successful responses must include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset`.
2. **Use HTTP 429 (Too Many Requests) exclusively.** Never use 403 or 503 for rate limiting.
3. **Include `Retry-After` on 429 responses.** This tells clients exactly when they can retry.
4. **Rate limiting MUST be applied before expensive operations.** The filter runs early in the chain, before authentication if using IP-based limiting for unauthenticated endpoints.
5. **Redis failures MUST NOT cause API outages.** Use circuit breakers. When Redis is down, allow traffic through and log a warning.
6. **Never rate limit health check or webhook endpoints.** These are critical for operations and should always be accessible.
7. **Per-tenant limits take precedence over per-IP limits.** An authenticated request should be rate limited by tenant/API-key, not by IP.
8. **Log rate limit violations.** Track which tenants hit limits frequently -- this signals either abuse or a need to upsell.
9. **Provide a rate limit status endpoint.** Let API consumers check their current usage without consuming a request.

## Testing Rate Limits

```java
@SpringBootTest
@Testcontainers
class RateLimitFilterIntegrationTest {

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldReturnRateLimitHeaders() throws Exception {
        mockMvc.perform(get("/api/v1/projects")
                .header("Authorization", "Bearer test-token"))
            .andExpect(status().isOk())
            .andExpect(header().exists("X-RateLimit-Limit"))
            .andExpect(header().exists("X-RateLimit-Remaining"))
            .andExpect(header().exists("X-RateLimit-Reset"));
    }

    @Test
    void shouldReturn429WhenRateLimitExceeded() throws Exception {
        // Exhaust the rate limit
        for (int i = 0; i < 25; i++) {
            mockMvc.perform(get("/api/v1/projects")
                .header("Authorization", "Bearer free-tier-token"));
        }

        // Next request should be rejected
        mockMvc.perform(get("/api/v1/projects")
                .header("Authorization", "Bearer free-tier-token"))
            .andExpect(status().isTooManyRequests())
            .andExpect(header().exists("Retry-After"))
            .andExpect(jsonPath("$.error").value("rate_limit_exceeded"));
    }
}
```

## Examples

### Example 1: Rate limit status endpoint

```java
@GetMapping("/api/v1/rate-limit/status")
public ResponseEntity<RateLimitStatus> getRateLimitStatus(@AuthenticationPrincipal UserPrincipal user) {
    TenantContext ctx = tenantContextHolder.getContext();
    RateLimitConfig config = RateLimitConfig.forTier(ctx.getPlanTier());

    // Peek at current bucket state without consuming a token
    RedisRateLimiter.RateLimitResult result = rateLimiter.peek("tenant:" + ctx.getTenantId(), config);

    return ResponseEntity.ok(new RateLimitStatus(
        config.requestsPerHour(),
        result.remaining(),
        config.burstCapacity(),
        config.refillRatePerSecond(),
        Instant.ofEpochSecond(result.resetEpochSeconds())
    ));
}
```

### Example 2: Temporary rate limit override for a specific tenant

```java
@PostMapping("/admin/api/v1/tenants/{tenantId}/rate-limit-override")
@PreAuthorize("hasRole('ADMIN')")
public ResponseEntity<Void> setRateLimitOverride(
        @PathVariable UUID tenantId,
        @RequestBody RateLimitOverrideRequest request) {

    // Store override in Redis with expiration
    String key = "ratelimit:override:" + tenantId;
    redisTemplate.opsForValue().set(key,
        objectMapper.writeValueAsString(request.config()),
        Duration.ofHours(request.durationHours()));

    return ResponseEntity.noContent().build();
}
```
