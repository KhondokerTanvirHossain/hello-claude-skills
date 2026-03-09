---
name: microservice-boundaries
description: Service decomposition and API contract design patterns for Spring Boot microservices including inter-service communication, data ownership, and distributed transaction handling
version: 1.0.0
tags: [microservices, spring-boot, decomposition, saga, api-contracts, distributed-systems]
globs:
  - "**/client/**/*.java"
  - "**/event/**/*.java"
  - "**/saga/**/*.java"
  - "**/contract/**/*.java"
  - "**/*Client.java"
  - "**/*Listener.java"
  - "**/*Publisher.java"
  - "**/docker-compose*.yml"
---

# Microservice Boundaries and Inter-Service Communication

## Purpose

Define how to decompose a system into microservices, establish clear data ownership, design API contracts, and handle distributed transactions. This skill provides decision frameworks for choosing synchronous vs asynchronous communication, implementing the saga pattern, managing shared data, and designing the Backend-for-Frontend (BFF) layer. The goal is building services that are independently deployable, loosely coupled, and aligned with bounded contexts.

## When to Use

- Decomposing a monolith into microservices
- Deciding whether logic belongs in Service A or Service B
- Choosing between REST calls and event-driven communication
- Implementing a business process that spans multiple services
- Designing a BFF layer for a frontend application
- Establishing data ownership rules across services
- Handling data consistency without distributed transactions (no 2PC)
- Defining contract testing strategy between services

## Workflow and Rules

### Rule 1: One Bounded Context = One Microservice (Usually)

Start with bounded context mapping from your domain analysis. Each bounded context typically maps to one microservice. A service owns its data, its business rules, and its API. Resist splitting bounded contexts into multiple services prematurely.

```
Context Map:

[Order Context] <-- Conformist -- [Inventory Context]
       |                                  |
   Partnership                      Customer/Supplier
       |                                  |
[Payment Context]                 [Shipping Context]
       |
  Anti-Corruption Layer
       |
[External Payment Gateway]
```

Resulting services:

```
order-service/          # Owns: orders, order items, order lifecycle
inventory-service/      # Owns: stock levels, reservations, warehouses
payment-service/        # Owns: payment records, refunds, payment methods
shipping-service/       # Owns: shipments, tracking, carrier integrations
notification-service/   # Owns: templates, delivery preferences, send history
bff-web/                # BFF for web frontend -- aggregates + transforms
bff-mobile/             # BFF for mobile app -- different data shape
```

### Rule 2: Database per Service Is Non-Negotiable

Each service owns its database schema. No shared databases. No reading another service's tables. If you need data from another service, you call its API or consume its events.

```yaml
# docker-compose.yml -- each service has its own database
services:
  order-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: orderdb
      POSTGRES_USER: order_svc
      POSTGRES_PASSWORD: ${ORDER_DB_PASSWORD}
    volumes:
      - order-data:/var/lib/postgresql/data

  inventory-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: inventorydb
      POSTGRES_USER: inventory_svc
      POSTGRES_PASSWORD: ${INVENTORY_DB_PASSWORD}
    volumes:
      - inventory-data:/var/lib/postgresql/data

  payment-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: paymentdb
      POSTGRES_USER: payment_svc
      POSTGRES_PASSWORD: ${PAYMENT_DB_PASSWORD}
    volumes:
      - payment-data:/var/lib/postgresql/data
```

Data that multiple services need should be replicated via events (eventual consistency), not shared via a common database.

### Rule 3: Synchronous Communication (REST/gRPC) for Queries

Use synchronous calls when the caller needs an immediate response and cannot proceed without it. Typical for reads and validation checks.

```java
// order-service calling inventory-service synchronously
@Component
public class InventoryServiceClient {

    private final RestClient restClient;

    public InventoryServiceClient(RestClient.Builder builder,
                                   @Value("${services.inventory.url}") String baseUrl) {
        this.restClient = builder.baseUrl(baseUrl).build();
    }

    public StockAvailability checkStock(String productId, int quantity) {
        var response = restClient.get()
            .uri("/api/v1/products/{productId}/stock", productId)
            .retrieve()
            .body(InventoryStockResponse.class);

        // Anti-corruption: translate external response to our domain type
        return new StockAvailability(
            new ProductId(UUID.fromString(productId)),
            response.available() >= quantity,
            response.available()
        );
    }
}
```

Always apply resilience patterns to synchronous calls:

```java
@Component
public class ResilientInventoryClient {

    private final InventoryServiceClient client;

    @CircuitBreaker(name = "inventory", fallbackMethod = "fallbackStock")
    @Retry(name = "inventory")
    @TimeLimiter(name = "inventory")
    public CompletableFuture<StockAvailability> checkStock(String productId, int quantity) {
        return CompletableFuture.supplyAsync(() -> client.checkStock(productId, quantity));
    }

    private CompletableFuture<StockAvailability> fallbackStock(String productId, int quantity, Throwable t) {
        // Graceful degradation: assume available and verify later
        return CompletableFuture.completedFuture(StockAvailability.unknown(productId));
    }
}
```

```yaml
# application.yml -- Resilience4j configuration
resilience4j:
  circuitbreaker:
    instances:
      inventory:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
  retry:
    instances:
      inventory:
        max-attempts: 3
        wait-duration: 500ms
        exponential-backoff-multiplier: 2
  timelimiter:
    instances:
      inventory:
        timeout-duration: 2s
```

### Rule 4: Asynchronous Communication (Events) for Commands and State Changes

Use events when the caller does not need an immediate response, when multiple services need to react to a state change, or when you need temporal decoupling. Events are the backbone of distributed transactions.

```java
// Domain event published to Kafka
public record OrderPlacedIntegrationEvent(
    String eventId,
    String orderId,
    String customerId,
    List<OrderItemPayload> items,
    BigDecimal totalAmount,
    String currency,
    Instant occurredAt
) {
    public record OrderItemPayload(
        String productId,
        int quantity,
        BigDecimal unitPrice
    ) {}
}
```

```java
// Kafka publisher in order-service
@Component
public class OrderEventKafkaPublisher {

    private final KafkaTemplate<String, Object> kafka;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent domainEvent) {
        var integrationEvent = mapToIntegrationEvent(domainEvent);
        kafka.send("order.events", domainEvent.orderId().toString(), integrationEvent);
    }
}
```

```java
// Kafka consumer in inventory-service
@Component
public class OrderEventsListener {

    private final ReserveStockUseCase reserveStock;

    @KafkaListener(topics = "order.events", groupId = "inventory-service")
    public void handleOrderPlaced(OrderPlacedIntegrationEvent event) {
        var command = new ReserveStockCommand(
            event.orderId(),
            event.items().stream()
                .map(i -> new StockReservation(i.productId(), i.quantity()))
                .toList()
        );
        reserveStock.execute(command);
    }
}
```

### Rule 5: Use the Saga Pattern for Distributed Transactions

When a business process spans multiple services, use the choreography-based saga (preferred for simple flows) or orchestration-based saga (for complex flows).

**Choreography Saga** (event chain):

```
Order Service          Inventory Service       Payment Service
     |                       |                       |
     |--- OrderPlaced ------>|                       |
     |                       |--- StockReserved ---->|
     |                       |                       |--- PaymentProcessed --->
     |<-- OrderConfirmed ----|                       |
     |                       |                       |
  [If payment fails:]        |                       |
     |                       |<-- PaymentFailed -----|
     |<-- StockReleased -----|                       |
     |--- OrderCancelled     |                       |
```

**Orchestration Saga** (central coordinator):

```java
// Saga orchestrator in order-service
@Component
public class PlaceOrderSaga {

    private final OrderRepository orderRepository;
    private final InventoryServiceClient inventoryClient;
    private final PaymentServiceClient paymentClient;
    private final ApplicationEventPublisher publisher;

    @Transactional
    public OrderResult execute(PlaceOrderCommand command) {
        var order = Order.create(command);

        try {
            // Step 1: Reserve inventory
            var reservation = inventoryClient.reserveStock(order.getItems());
            order.markInventoryReserved(reservation.reservationId());

            // Step 2: Process payment
            var payment = paymentClient.processPayment(order.getTotalAmount(), command.paymentMethod());
            order.markPaymentProcessed(payment.transactionId());

            // Step 3: Confirm order
            order.confirm();
            orderRepository.save(order);

            return OrderResult.success(order);

        } catch (InsufficientStockException e) {
            order.cancel("Insufficient stock: " + e.getMessage());
            orderRepository.save(order);
            return OrderResult.failed(order, "Insufficient stock");

        } catch (PaymentDeclinedException e) {
            // Compensate: release inventory
            inventoryClient.releaseReservation(order.getReservationId());
            order.cancel("Payment declined: " + e.getMessage());
            orderRepository.save(order);
            return OrderResult.failed(order, "Payment declined");
        }
    }
}
```

### Rule 6: The BFF Pattern Aggregates for Frontends

Each frontend (web, mobile, admin) gets its own BFF service that aggregates data from multiple backend services and shapes it for that specific UI.

```
[Web App] ----> [BFF-Web] ----> [Order Service]
                    |--------> [Inventory Service]
                    |--------> [Customer Service]

[Mobile App] --> [BFF-Mobile] --> [Order Service]  (different payload shape)
                      |---------> [Customer Service]
```

```java
// BFF-Web: aggregates data from multiple services for a single page view
@RestController
@RequestMapping("/bff/v1/orders")
public class OrderPageController {

    private final OrderServiceClient orderClient;
    private final CustomerServiceClient customerClient;
    private final ShippingServiceClient shippingClient;

    @GetMapping("/{orderId}")
    public OrderPageResponse getOrderPage(@PathVariable String orderId) {
        // Parallel calls to backend services
        var orderFuture = CompletableFuture.supplyAsync(() -> orderClient.getOrder(orderId));
        var customerFuture = orderFuture.thenCompose(order ->
            CompletableFuture.supplyAsync(() -> customerClient.getCustomer(order.customerId()))
        );
        var shippingFuture = CompletableFuture.supplyAsync(() -> shippingClient.getShipment(orderId));

        var order = orderFuture.join();
        var customer = customerFuture.join();
        var shipping = shippingFuture.join();

        // Shape response for web UI
        return OrderPageResponse.builder()
            .orderId(order.id())
            .status(order.status())
            .customerName(customer.fullName())
            .items(order.items().stream().map(this::toItemView).toList())
            .shippingStatus(shipping.status())
            .estimatedDelivery(shipping.estimatedDelivery())
            .build();
    }
}
```

### Rule 7: API-First Design with OpenAPI Contracts

Define the API contract before writing implementation code. Store OpenAPI specs in the repository and generate client code from them.

```
service-contracts/
  order-service-api.yaml      # OpenAPI 3.1 spec
  inventory-service-api.yaml
  payment-service-api.yaml
```

```yaml
# order-service-api.yaml (abbreviated)
openapi: 3.1.0
info:
  title: Order Service API
  version: 1.0.0

paths:
  /api/v1/orders:
    post:
      operationId: placeOrder
      summary: Place a new order
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PlaceOrderRequest'
      responses:
        '201':
          description: Order placed successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OrderResponse'
        '400':
          $ref: '#/components/responses/ValidationError'
        '409':
          $ref: '#/components/responses/ConflictError'
```

### Rule 8: Contract Testing Between Services

Use Spring Cloud Contract or Pact to verify that consumer expectations match producer implementations. This catches breaking changes before deployment.

```java
// Consumer side (order-service testing its inventory-service client)
@SpringBootTest
@AutoConfigureStubRunner(
    ids = "com.company:inventory-service:+:stubs:6565",
    stubsMode = StubRunnerProperties.StubsMode.LOCAL
)
class InventoryClientContractTest {

    @Autowired
    private InventoryServiceClient client;

    @Test
    void should_check_stock_availability() {
        var result = client.checkStock("product-123", 5);

        assertThat(result.isAvailable()).isTrue();
        assertThat(result.availableQuantity()).isGreaterThanOrEqualTo(5);
    }
}
```

### Rule 9: Shared Kernel for Cross-Cutting Types

When multiple services need the same types (event schemas, error formats), extract a shared library. Keep it minimal -- only truly shared types belong here.

```
shared-kernel/
  build.gradle.kts
  src/main/java/com/company/shared/
    event/
      DomainEvent.java               # Marker interface
      EventMetadata.java             # Common event envelope
    error/
      ProblemDetail.java             # RFC 7807 error format
    type/
      Money.java                     # Shared value object
      PageResponse.java              # Pagination wrapper
```

```kotlin
// shared-kernel/build.gradle.kts
plugins {
    id("java-conventions")
    `maven-publish`
}

// No Spring dependency -- pure Java types only
dependencies {
    compileOnly("com.fasterxml.jackson.core:jackson-annotations:2.18.1")
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }
}
```

Services depend on it as a library, not as a service:
```kotlin
dependencies {
    implementation("com.company:shared-kernel:1.0.0")
}
```

### Rule 10: Service Discovery and Configuration

Use Spring Cloud for service discovery in production, and direct URLs for local development.

```yaml
# application-local.yml (direct URLs for docker-compose development)
services:
  inventory:
    url: http://localhost:8081
  payment:
    url: http://localhost:8082
  shipping:
    url: http://localhost:8083

# application-prod.yml (Kubernetes DNS-based discovery)
services:
  inventory:
    url: http://inventory-service.default.svc.cluster.local:8080
  payment:
    url: http://payment-service.default.svc.cluster.local:8080
  shipping:
    url: http://shipping-service.default.svc.cluster.local:8080
```

## Examples

### Example: Decision Matrix -- Sync vs Async

| Scenario | Pattern | Reason |
|----------|---------|--------|
| Check stock before placing order | Sync (REST) | Caller needs immediate response to proceed |
| Notify customer of shipment | Async (Event) | Fire-and-forget, no response needed |
| Process payment during checkout | Sync (REST) | Caller must know if payment succeeded |
| Update search index after product change | Async (Event) | Eventually consistent is acceptable |
| Validate address via external API | Sync (REST) | Blocking validation step |
| Generate invoice after order confirmed | Async (Event) | Can happen independently |

### Example: Handling Data Duplication Across Services

Order Service needs customer name for display but Customer Service owns customer data:

```java
// Option A: Query at read time (sync call from BFF)
// Best when: Data changes frequently, consistency matters

// Option B: Cache via events (eventual consistency)
// Best when: Read-heavy, tolerance for stale data
@KafkaListener(topics = "customer.events", groupId = "order-service")
public void onCustomerUpdated(CustomerUpdatedEvent event) {
    customerLocalCache.save(new CustomerSnapshot(
        event.customerId(),
        event.fullName(),
        event.email()
    ));
}
```

### Example: Docker Compose for Local Multi-Service Development

```yaml
# docker-compose.yml
services:
  order-service:
    build: ./order-service
    ports: ["8080:8080"]
    environment:
      DATABASE_URL: jdbc:postgresql://order-db:5432/orderdb
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      SERVICES_INVENTORY_URL: http://inventory-service:8080
    depends_on:
      order-db: { condition: service_healthy }
      kafka: { condition: service_healthy }

  inventory-service:
    build: ./inventory-service
    ports: ["8081:8080"]
    environment:
      DATABASE_URL: jdbc:postgresql://inventory-db:5432/inventorydb
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    depends_on:
      inventory-db: { condition: service_healthy }
      kafka: { condition: service_healthy }

  kafka:
    image: confluentinc/cp-kafka:7.7.1
    ports: ["9092:9092"]
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:29093
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:29093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      CLUSTER_ID: "local-dev-cluster-id-001"
    healthcheck:
      test: kafka-broker-api-versions --bootstrap-server localhost:9092
      interval: 10s
      timeout: 5s
      retries: 5
```
