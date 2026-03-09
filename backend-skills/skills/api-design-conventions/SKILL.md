---
name: api-design-conventions
description: >
  REST API design standards for Spring Boot 3.x microservices including URL naming,
  HTTP method semantics, RFC 7807 Problem Details error format, cursor-based and
  offset pagination, filtering/sorting query parameters, versioning strategy, HATEOAS
  links, Jakarta Bean Validation, OpenAPI/SpringDoc annotations, rate limit headers,
  and security configuration. Trigger: "design an API", "add endpoint", "error format",
  "pagination", "API versioning", "request validation", "HATEOAS"
version: 1.0.0
tags: [rest-api, spring-boot, openapi, error-handling, pagination, java-21, validation, hateoas]
globs:
  - "**/*Controller.java"
  - "**/*RestController.java"
  - "**/dto/**/*.java"
  - "**/exception/**/*.java"
  - "**/config/Web*.java"
  - "**/openapi/**"
  - "**/resources/api-docs/**"
---

# REST API Design Conventions

## Purpose

Establish consistent, predictable REST API design standards across all Spring Boot 3.x microservices in a Clean Architecture + DDD ecosystem. This skill defines URL naming rules, HTTP method semantics, the standard error response format (RFC 7807 Problem Details), dual pagination strategies (cursor-based for feeds, offset-based for admin UIs), filtering and sorting conventions, versioning policy, HATEOAS discoverability links, request validation with Jakarta Bean Validation, OpenAPI documentation annotations, rate limit response headers, and Spring Security configuration for API endpoints. Following these conventions ensures every service in the platform behaves predictably and is self-documenting.

## When to Use

- Designing a new REST endpoint for any microservice
- Adding error handling to controllers or a global exception handler
- Implementing paginated list endpoints (choose cursor vs. offset)
- Setting up filtering and sorting query parameters
- Documenting APIs with OpenAPI/SpringDoc annotations
- Reviewing API designs for consistency across services
- Setting up request validation with Jakarta Bean Validation
- Deciding on an API versioning strategy for breaking changes
- Adding rate limit headers to API responses
- Configuring Spring Security for stateless JWT-based API auth

## Workflow and Rules

### Rule 1: URL Naming Conventions

All URLs follow these patterns with no exceptions.

```
Base pattern:  /api/v{version}/{resource-name}

Resources use:
  - Lowercase kebab-case: /api/v1/order-items  (NOT /api/v1/orderItems)
  - Plural nouns: /api/v1/orders  (NOT /api/v1/order)
  - No trailing slashes: /api/v1/orders  (NOT /api/v1/orders/)
  - No verbs in URLs: /api/v1/orders  (NOT /api/v1/create-order)
  - No file extensions: /api/v1/orders  (NOT /api/v1/orders.json)

Nested resources for parent-child relationships:
  /api/v1/orders/{orderId}/items
  /api/v1/orders/{orderId}/items/{itemId}
  /api/v1/customers/{customerId}/addresses

Maximum nesting depth: 2 levels. Beyond that, promote to top-level:
  BAD:  /api/v1/customers/{id}/orders/{id}/items/{id}/reviews
  GOOD: /api/v1/order-item-reviews?orderId={orderId}

Actions that do not map to CRUD use a sub-resource verb:
  POST /api/v1/orders/{orderId}/cancel
  POST /api/v1/orders/{orderId}/submit
  POST /api/v1/payments/{paymentId}/refund
```

### Rule 2: HTTP Method Semantics

| Method | Usage | Idempotent | Request Body | Success Code |
|--------|-------|------------|--------------|--------------|
| GET | Retrieve resource(s) | Yes | No | 200 |
| POST | Create new resource | No | Yes | 201 |
| PUT | Full replacement of resource | Yes | Yes | 200 |
| PATCH | Partial update of resource | No | Yes (partial) | 200 |
| DELETE | Remove resource | Yes | No | 204 |

POST for creation MUST return a `Location` header pointing to the created resource.

```java
@RestController
@RequestMapping("/api/v1/orders")
@Tag(name = "Orders", description = "Order management operations")
@RequiredArgsConstructor
public class OrderController {

    private final PlaceOrderUseCase placeOrder;
    private final GetOrderUseCase getOrder;
    private final ListOrdersUseCase listOrders;
    private final CancelOrderUseCase cancelOrder;

    // GET -- single resource
    @GetMapping("/{orderId}")
    @Operation(summary = "Get order by ID", operationId = "getOrder")
    public ResponseEntity<OrderResponse> getOrder(@PathVariable UUID orderId) {
        var order = getOrder.execute(orderId);
        return ResponseEntity.ok(OrderResponse.from(order));
    }

    // GET -- paginated collection
    @GetMapping
    @Operation(summary = "List orders with filtering and pagination", operationId = "listOrders")
    public ResponseEntity<PageResponse<OrderSummaryResponse>> listOrders(
            @Valid OrderFilterRequest filter,
            @Valid PaginationRequest pagination) {
        var page = listOrders.execute(filter.toQuery(), pagination.toPageable());
        return ResponseEntity.ok(PageResponse.from(page, OrderSummaryResponse::from));
    }

    // POST -- create, return 201 + Location header
    @PostMapping
    @Operation(summary = "Place a new order", operationId = "placeOrder")
    public ResponseEntity<OrderResponse> placeOrder(
            @Valid @RequestBody PlaceOrderRequest request) {
        var result = placeOrder.execute(request.toCommand());
        var location = URI.create("/api/v1/orders/" + result.orderId());
        return ResponseEntity.created(location).body(OrderResponse.from(result));
    }

    // POST -- action on existing resource (non-CRUD)
    @PostMapping("/{orderId}/cancel")
    @Operation(summary = "Cancel an existing order", operationId = "cancelOrder")
    public ResponseEntity<OrderResponse> cancelOrder(
            @PathVariable UUID orderId,
            @Valid @RequestBody CancelOrderRequest request) {
        var result = cancelOrder.execute(orderId, request.reason());
        return ResponseEntity.ok(OrderResponse.from(result));
    }

    // DELETE -- remove, return 204 No Content
    @DeleteMapping("/{orderId}")
    @Operation(summary = "Delete a draft order", operationId = "deleteOrder")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable UUID orderId) {
        deleteOrder.execute(orderId);
    }
}
```

### Rule 3: Standard Error Response Format (RFC 7807)

All error responses use the RFC 7807 Problem Details format. Spring Boot 3.x has built-in support via `ProblemDetail`. Enable it in configuration and use a global exception handler.

```yaml
# application.yml
spring:
  mvc:
    problemdetails:
      enabled: true
```

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    // Domain exception -> 404
    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource Not Found");
        problem.setType(URI.create("https://api.company.com/problems/resource-not-found"));
        problem.setProperty("resourceType", ex.getResourceType());
        problem.setProperty("resourceId", ex.getResourceId());
        return problem;
    }

    // Domain exception -> 409 Conflict
    @ExceptionHandler(BusinessRuleViolationException.class)
    public ProblemDetail handleConflict(BusinessRuleViolationException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
        problem.setTitle("Business Rule Violation");
        problem.setType(URI.create("https://api.company.com/problems/business-rule-violation"));
        problem.setProperty("rule", ex.getRuleName());
        return problem;
    }

    // Bean Validation errors -> 400 with field-level details
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {

        var problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation Failed");
        problem.setType(URI.create("https://api.company.com/problems/validation-error"));
        problem.setDetail("One or more fields failed validation");

        var fieldErrors = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> Map.of(
                "field", fe.getField(),
                "message", Objects.requireNonNull(fe.getDefaultMessage()),
                "rejectedValue", String.valueOf(fe.getRejectedValue())
            ))
            .toList();

        problem.setProperty("errors", fieldErrors);
        return ResponseEntity.badRequest().body(problem);
    }

    // Catch-all for unexpected errors -> 500
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        var problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred. Please try again later."
        );
        problem.setTitle("Internal Server Error");
        problem.setType(URI.create("https://api.company.com/problems/internal-error"));
        return problem;
    }
}
```

Error response example:

```json
{
  "type": "https://api.company.com/problems/validation-error",
  "title": "Validation Failed",
  "status": 400,
  "detail": "One or more fields failed validation",
  "instance": "/api/v1/orders",
  "errors": [
    {
      "field": "items",
      "message": "must not be empty",
      "rejectedValue": "[]"
    },
    {
      "field": "customerId",
      "message": "must not be null",
      "rejectedValue": "null"
    }
  ]
}
```

### Rule 4: Pagination -- Cursor-Based and Offset Strategies

Choose the strategy based on the use case.

**Offset-based** -- for admin UIs and backoffice where total counts matter:

```
GET /api/v1/orders?page=0&size=20&sort=createdAt,desc
```

```java
public record PaginationRequest(
    @Min(0) @RequestParam(defaultValue = "0") int page,
    @Min(1) @Max(100) @RequestParam(defaultValue = "20") int size,
    @RequestParam(defaultValue = "createdAt,desc") String sort
) {
    public Pageable toPageable() {
        var parts = sort.split(",");
        var direction = parts.length > 1 ? Sort.Direction.fromString(parts[1]) : Sort.Direction.DESC;
        return PageRequest.of(page, size, Sort.by(direction, parts[0]));
    }
}

public record PageResponse<T>(
    List<T> content,
    PageMetadata metadata
) {
    public record PageMetadata(
        int page, int size, long totalElements, int totalPages, boolean hasNext, boolean hasPrevious
    ) {}

    public static <T, S> PageResponse<T> from(Page<S> page, Function<S, T> mapper) {
        return new PageResponse<>(
            page.getContent().stream().map(mapper).toList(),
            new PageMetadata(
                page.getNumber(), page.getSize(), page.getTotalElements(),
                page.getTotalPages(), page.hasNext(), page.hasPrevious()
            )
        );
    }
}
```

**Cursor-based** -- for infinite scroll, real-time feeds, large datasets:

```
GET /api/v1/orders?cursor=eyJpZCI6MTAwfQ&limit=20
```

```java
public record CursorPageResponse<T>(
    List<T> content,
    String nextCursor,
    boolean hasMore
) {
    public static <T> CursorPageResponse<T> of(
            List<T> items, int limit, Function<T, String> cursorExtractor) {
        boolean hasMore = items.size() > limit;
        var content = hasMore ? items.subList(0, limit) : items;
        var nextCursor = hasMore
            ? Base64.getEncoder().encodeToString(cursorExtractor.apply(content.getLast()).getBytes())
            : null;
        return new CursorPageResponse<>(content, nextCursor, hasMore);
    }
}
```

### Rule 5: Filtering and Sorting Query Parameters

Use flat query parameters for filtering. Never put filters in the request body for GET requests.

```
GET /api/v1/orders?status=PLACED&customerId=abc123&createdAfter=2024-01-01&sort=totalAmount,asc
```

```java
public record OrderFilterRequest(
    @RequestParam(required = false) OrderStatus status,
    @RequestParam(required = false) UUID customerId,
    @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdAfter,
    @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate createdBefore,
    @RequestParam(required = false) @Size(max = 100) String search
) {
    public OrderQuery toQuery() {
        return OrderQuery.builder()
            .status(status)
            .customerId(customerId != null ? new CustomerId(customerId) : null)
            .createdAfter(createdAfter != null ? createdAfter.atStartOfDay(ZoneOffset.UTC).toInstant() : null)
            .createdBefore(createdBefore != null ? createdBefore.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant() : null)
            .searchTerm(search)
            .build();
    }
}
```

Sorting rules:
- Default sort is always specified: `sort=createdAt,desc`
- Only allow sorting on indexed columns
- Validate sort field names against an allowlist to prevent injection

### Rule 6: Request Validation with Jakarta Bean Validation

Validate all incoming requests at the controller layer. Custom validators for domain-specific rules.

```java
public record PlaceOrderRequest(
    @NotNull(message = "Customer ID is required")
    UUID customerId,

    @NotEmpty(message = "Order must contain at least one item")
    @Size(max = 50, message = "Order cannot contain more than 50 items")
    @Valid
    List<OrderItemRequest> items,

    @Valid
    @NotNull(message = "Shipping address is required")
    AddressRequest shippingAddress,

    @Size(max = 500, message = "Notes must not exceed 500 characters")
    String notes
) {
    public PlaceOrderCommand toCommand() {
        return new PlaceOrderCommand(
            new CustomerId(customerId),
            items.stream().map(OrderItemRequest::toItem).toList(),
            shippingAddress.toAddress(),
            notes
        );
    }
}

public record AddressRequest(
    @NotBlank(message = "Street is required") @Size(max = 200) String street,
    @NotBlank(message = "City is required") @Size(max = 100) String city,
    @NotBlank(message = "State is required") @Size(max = 50) String state,
    @NotBlank(message = "Zip code is required")
    @Pattern(regexp = "^\\d{5}(-\\d{4})?$", message = "Invalid US zip code format")
    String zipCode,
    @NotBlank(message = "Country is required")
    @Size(min = 2, max = 2, message = "Country must be ISO 3166-1 alpha-2 code")
    String country
) {}
```

### Rule 7: API Versioning Strategy

Use URL path versioning (`/api/v1/`). It is explicit, easy to route, and works with all HTTP clients.

- Major version in URL path: `/api/v1/`, `/api/v2/`
- Minor, non-breaking changes do not bump the version
- Support at most 2 major versions simultaneously
- Deprecate old versions with a `Sunset` header and 6-month notice
- New fields added to response bodies are non-breaking (additive)
- Removing or renaming fields is breaking and requires a version bump

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderControllerV1 {

    @GetMapping("/{orderId}")
    public ResponseEntity<OrderResponseV1> getOrder(@PathVariable UUID orderId) {
        var order = getOrderUseCase.execute(orderId);
        return ResponseEntity.ok()
            .header("Sunset", "Sat, 01 Sep 2026 00:00:00 GMT")
            .header("Deprecation", "true")
            .header("Link", "</api/v2/orders/" + orderId + ">; rel=\"successor-version\"")
            .body(OrderResponseV1.from(order));
    }
}
```

### Rule 8: HATEOAS Links for Discoverability

Add links only when they provide genuine navigational or state-discovery value. Do not over-engineer.

```java
public record OrderResponse(
    UUID orderId,
    String status,
    BigDecimal totalAmount,
    String currency,
    Instant createdAt,
    Map<String, String> links
) {
    public static OrderResponse from(OrderResult order) {
        var links = new LinkedHashMap<String, String>();
        links.put("self", "/api/v1/orders/" + order.orderId());
        links.put("items", "/api/v1/orders/" + order.orderId() + "/items");

        if (order.canBeCancelled()) {
            links.put("cancel", "/api/v1/orders/" + order.orderId() + "/cancel");
        }
        if (order.canBeShipped()) {
            links.put("ship", "/api/v1/orders/" + order.orderId() + "/ship");
        }

        return new OrderResponse(
            order.orderId(), order.status().name(),
            order.totalAmount().amount(), order.totalAmount().currency().getCurrencyCode(),
            order.createdAt(), links
        );
    }
}
```

### Rule 9: Rate Limit Response Headers

Every API response includes rate limit headers. The API gateway sets real values; the application provides defaults.

```java
@Component
public class StandardHeadersFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        var httpResponse = (HttpServletResponse) response;

        // Security headers
        httpResponse.setHeader("X-Content-Type-Options", "nosniff");
        httpResponse.setHeader("X-Frame-Options", "DENY");
        httpResponse.setHeader("Cache-Control", "no-store");

        // Rate limiting headers
        httpResponse.setHeader("X-RateLimit-Limit", "1000");
        httpResponse.setHeader("X-RateLimit-Remaining", "999");
        httpResponse.setHeader("X-RateLimit-Reset", String.valueOf(
            Instant.now().plus(1, ChronoUnit.MINUTES).getEpochSecond()
        ));

        // Request tracing
        var requestId = ((HttpServletRequest) request).getHeader("X-Request-Id");
        if (requestId == null) {
            requestId = UUID.randomUUID().toString();
        }
        httpResponse.setHeader("X-Request-Id", requestId);

        chain.doFilter(request, response);
    }
}
```

### Rule 10: OpenAPI Documentation with SpringDoc

Every controller is annotated with OpenAPI metadata. The generated spec is the single source of truth.

```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenApi() {
        return new OpenAPI()
            .info(new Info()
                .title("Order Service API")
                .version("1.0.0")
                .description("API for managing customer orders")
                .contact(new Contact().name("Platform Team").email("platform@company.com"))
                .license(new License().name("Internal Use Only")))
            .addServersItem(new Server().url("https://api.company.com").description("Production"))
            .addServersItem(new Server().url("http://localhost:8080").description("Local Development"))
            .components(new Components()
                .addSecuritySchemes("bearerAuth",
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")));
    }
}
```

```yaml
# application.yml
springdoc:
  api-docs:
    path: /api-docs
    enabled: true
  swagger-ui:
    path: /swagger-ui
    enabled: true
    tags-sorter: alpha
    operations-sorter: method
  default-produces-media-type: application/json
  default-consumes-media-type: application/json
  show-actuator: false
```

### Rule 11: Spring Security for API Endpoints

Stateless JWT-based security with public access for health checks and docs.

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/api-docs/**", "/swagger-ui/**").permitAll()
                .requestMatchers("/api/v1/**").authenticated()
                .anyRequest().denyAll()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .build();
    }
}
```

### Rule 12: Health Check and Actuator Endpoints

Every service exposes standardized health and info endpoints.

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
```

## Examples

### Example 1: Complete Error Response Catalog

| HTTP Status | When to Use | Example Scenario |
|-------------|-------------|------------------|
| 400 Bad Request | Validation failure, malformed JSON | Missing required field, invalid email format |
| 401 Unauthorized | Missing or invalid authentication | Expired JWT, no Authorization header |
| 403 Forbidden | Authenticated but not authorized | User accessing another user's resource |
| 404 Not Found | Resource does not exist | Order ID not in database |
| 409 Conflict | State conflict | Cancelling an already-shipped order |
| 422 Unprocessable Entity | Semantic validation failure | Order total exceeds credit limit |
| 429 Too Many Requests | Rate limit exceeded | More than 1000 requests/minute |
| 500 Internal Server Error | Unexpected server failure | Database connection failed |
| 502 Bad Gateway | Downstream service failure | Payment gateway timeout |
| 503 Service Unavailable | Service temporarily down | During deployment/maintenance |

### Example 2: Full Order Lifecycle Request/Response

Create:
```
POST /api/v1/orders
Content-Type: application/json
Authorization: Bearer eyJhbG...

{
  "customerId": "a1b2c3d4-...",
  "items": [{ "productId": "prod-001", "quantity": 2 }],
  "shippingAddress": {
    "street": "123 Main St", "city": "Portland",
    "state": "OR", "zipCode": "97201", "country": "US"
  }
}

Response: 201 Created
Location: /api/v1/orders/order-789
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 998
```

List with filters:
```
GET /api/v1/orders?status=PLACED&page=0&size=20&sort=createdAt,desc

Response: 200 OK
{
  "content": [...],
  "metadata": {
    "page": 0, "size": 20, "totalElements": 143,
    "totalPages": 8, "hasNext": true, "hasPrevious": false
  }
}
```

### Example 3: Cursor-Based Pagination for Activity Feed

```
GET /api/v1/activity-feed?limit=25

Response: 200 OK
{
  "content": [
    { "id": "evt-100", "type": "ORDER_PLACED", "timestamp": "2024-03-01T10:30:00Z" },
    ...
  ],
  "nextCursor": "eyJpZCI6Ijc1In0=",
  "hasMore": true
}

GET /api/v1/activity-feed?cursor=eyJpZCI6Ijc1In0=&limit=25

Response: 200 OK
{
  "content": [...],
  "nextCursor": "eyJpZCI6IjUwIn0=",
  "hasMore": true
}
```
