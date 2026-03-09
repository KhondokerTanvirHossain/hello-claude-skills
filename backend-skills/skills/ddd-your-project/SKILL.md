---
name: ddd-your-project
description: Domain-Driven Design implementation patterns for Java 21 + Spring Boot microservices including aggregate design, domain events, bounded context mapping, and repository patterns
version: 1.0.0
tags: [ddd, domain-driven-design, java-21, spring-boot, clean-architecture, microservices]
globs:
  - "**/domain/**/*.java"
  - "**/application/**/*.java"
  - "**/infrastructure/**/*.java"
  - "**/interfaces/**/*.java"
---

# Domain-Driven Design Implementation Patterns

## Purpose

Provide concrete, enforceable DDD implementation patterns for Java 21 + Spring Boot 3.x microservices. This skill defines how to structure packages, implement aggregates, publish domain events, design repository interfaces, and maintain bounded context boundaries. The goal is keeping the domain model pure (framework-free), pushing all infrastructure concerns to the outer layers, and making the ubiquitous language visible in code.

## When to Use

- Designing the package structure for a new microservice
- Implementing a new aggregate root or entity
- Creating value objects to replace primitive obsession
- Publishing and consuming domain events within or across bounded contexts
- Defining repository contracts in the domain layer
- Building anti-corruption layers between bounded contexts
- Reviewing existing code for DDD conformance
- Refactoring an anemic domain model into a rich one

## Package Structure

Every microservice follows a four-layer package structure aligned with Clean Architecture. The dependency rule is strict: inner layers never depend on outer layers.

```
com.company.orderservice/
  domain/                          # Innermost layer -- pure Java, zero dependencies
    model/
      order/                       # Aggregate folder (one per aggregate)
        Order.java                 # Aggregate root
        OrderId.java               # Typed ID (value object)
        OrderItem.java             # Entity within the aggregate
        OrderStatus.java           # Enum or value object
        Money.java                 # Value object
        OrderPlacedEvent.java      # Domain event
      customer/
        CustomerId.java            # Reference to another aggregate (ID only)
    repository/
      OrderRepository.java         # Interface ONLY -- no Spring annotations
    service/
      OrderDomainService.java      # Cross-aggregate domain logic
    exception/
      OrderAlreadyShippedException.java

  application/                     # Use cases / application services
    port/
      in/
        PlaceOrderUseCase.java     # Input port (interface)
        CancelOrderUseCase.java
      out/
        OrderPersistencePort.java  # Output port (interface)
        PaymentGatewayPort.java
        OrderEventPublisherPort.java
    service/
      PlaceOrderService.java       # Implements input port, orchestrates domain
      CancelOrderService.java
    dto/
      PlaceOrderCommand.java       # Command record
      OrderResult.java             # Result record

  infrastructure/                  # Outer layer -- frameworks live here
    persistence/
      jpa/
        OrderJpaEntity.java        # JPA entity (maps to DB, NOT the domain model)
        OrderJpaRepository.java    # Spring Data JPA repository
        OrderPersistenceAdapter.java  # Implements OrderPersistencePort
        OrderMapper.java           # Maps between domain and JPA entities
    messaging/
      kafka/
        OrderEventKafkaPublisher.java
        OrderEventKafkaListener.java
    external/
      payment/
        PaymentGatewayAdapter.java
        PaymentGatewayClient.java
        PaymentResponseMapper.java

  interfaces/                      # API / presentation layer
    rest/
      OrderController.java         # REST controller
      dto/
        PlaceOrderRequest.java     # API request DTO
        OrderResponse.java         # API response DTO
        OrderRequestMapper.java    # Maps API DTOs to application commands
    graphql/                       # If using GraphQL BFF
```

## Workflow and Rules

### Rule 1: Aggregate Roots Guard Invariants

All state mutations go through the aggregate root. External code never modifies child entities directly. The aggregate root validates invariants before allowing changes and emits domain events for significant state transitions.

```java
public class Order {

    private final OrderId id;
    private final CustomerId customerId;
    private final List<OrderItem> items;
    private OrderStatus status;
    private Money totalAmount;
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    // Private constructor -- use factory method
    private Order(OrderId id, CustomerId customerId, List<OrderItem> items) {
        this.id = Objects.requireNonNull(id);
        this.customerId = Objects.requireNonNull(customerId);
        this.items = new ArrayList<>(items);
        this.status = OrderStatus.DRAFT;
        this.totalAmount = calculateTotal();
    }

    // Factory method with validation
    public static Order create(OrderId id, CustomerId customerId, List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Order must contain at least one item");
        }
        var order = new Order(id, customerId, items);
        order.registerEvent(new OrderCreatedEvent(id, customerId, order.totalAmount));
        return order;
    }

    public void place() {
        if (status != OrderStatus.DRAFT) {
            throw new OrderAlreadyPlacedException(id);
        }
        if (items.isEmpty()) {
            throw new EmptyOrderException(id);
        }
        this.status = OrderStatus.PLACED;
        registerEvent(new OrderPlacedEvent(id, customerId, totalAmount, Instant.now()));
    }

    public void cancel(String reason) {
        if (status == OrderStatus.SHIPPED || status == OrderStatus.DELIVERED) {
            throw new OrderAlreadyShippedException(id);
        }
        this.status = OrderStatus.CANCELLED;
        registerEvent(new OrderCancelledEvent(id, reason, Instant.now()));
    }

    public void addItem(OrderItem item) {
        if (status != OrderStatus.DRAFT) {
            throw new OrderNotModifiableException(id, status);
        }
        this.items.add(item);
        this.totalAmount = calculateTotal();
    }

    // Return unmodifiable view -- protect aggregate boundary
    public List<OrderItem> getItems() {
        return Collections.unmodifiableList(items);
    }

    public List<DomainEvent> getDomainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    public void clearDomainEvents() {
        domainEvents.clear();
    }

    private void registerEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    private Money calculateTotal() {
        return items.stream()
            .map(OrderItem::subtotal)
            .reduce(Money.ZERO, Money::add);
    }
}
```

### Rule 2: Value Objects Use Java Records

Value objects are immutable, compared by value, and self-validating. Java 21 records are the default implementation.

```java
// Typed identifier -- prevents passing wrong ID types
public record OrderId(UUID value) {
    public OrderId {
        Objects.requireNonNull(value, "OrderId must not be null");
    }

    public static OrderId generate() {
        return new OrderId(UUID.randomUUID());
    }

    public static OrderId of(String raw) {
        return new OrderId(UUID.fromString(raw));
    }

    @Override
    public String toString() {
        return value.toString();
    }
}

// Money value object with currency safety
public record Money(BigDecimal amount, Currency currency) {
    public static final Money ZERO = new Money(BigDecimal.ZERO, Currency.getInstance("USD"));

    public Money {
        Objects.requireNonNull(amount, "Amount must not be null");
        Objects.requireNonNull(currency, "Currency must not be null");
        if (amount.scale() > 2) {
            amount = amount.setScale(2, RoundingMode.HALF_UP);
        }
    }

    public Money add(Money other) {
        assertSameCurrency(other);
        return new Money(this.amount.add(other.amount), this.currency);
    }

    public Money multiply(int quantity) {
        return new Money(this.amount.multiply(BigDecimal.valueOf(quantity)), this.currency);
    }

    public boolean isGreaterThan(Money other) {
        assertSameCurrency(other);
        return this.amount.compareTo(other.amount) > 0;
    }

    private void assertSameCurrency(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new CurrencyMismatchException(this.currency, other.currency);
        }
    }
}

// Address value object
public record Address(
    String street,
    String city,
    String state,
    String zipCode,
    String country
) {
    public Address {
        if (street == null || street.isBlank()) throw new IllegalArgumentException("Street required");
        if (zipCode == null || zipCode.isBlank()) throw new IllegalArgumentException("Zip code required");
        if (country == null || country.isBlank()) throw new IllegalArgumentException("Country required");
    }
}
```

### Rule 3: Domain Events Are Immutable Records

Domain events represent something that happened. They are named in past tense, carry only the data needed by consumers, and include a timestamp.

```java
// Base marker interface
public sealed interface DomainEvent permits
        OrderCreatedEvent, OrderPlacedEvent, OrderCancelledEvent, OrderShippedEvent {
    Instant occurredAt();
}

// Concrete event
public record OrderPlacedEvent(
    OrderId orderId,
    CustomerId customerId,
    Money totalAmount,
    Instant occurredAt
) implements DomainEvent {
    public OrderPlacedEvent {
        Objects.requireNonNull(orderId);
        Objects.requireNonNull(occurredAt);
    }
}
```

### Rule 4: Domain Events Are Published After Persistence

Use Spring's `ApplicationEventPublisher` for intra-service events. Events are collected on the aggregate and published by the application service after the persistence call succeeds. This avoids publishing events for failed transactions.

```java
@Service
@Transactional
public class PlaceOrderService implements PlaceOrderUseCase {

    private final OrderPersistencePort persistence;
    private final ApplicationEventPublisher eventPublisher;

    public PlaceOrderService(OrderPersistencePort persistence,
                              ApplicationEventPublisher eventPublisher) {
        this.persistence = persistence;
        this.eventPublisher = eventPublisher;
    }

    @Override
    public OrderResult execute(PlaceOrderCommand command) {
        var order = Order.create(
            OrderId.generate(),
            command.customerId(),
            command.toOrderItems()
        );
        order.place();

        // Persist first
        persistence.save(order);

        // Then publish events (after transaction commits ideally)
        order.getDomainEvents().forEach(eventPublisher::publishEvent);
        order.clearDomainEvents();

        return OrderResult.from(order);
    }
}
```

For guaranteed event delivery across services, use the Transactional Outbox pattern: persist events to an `outbox` table in the same transaction, then a separate publisher reads and sends them to Kafka.

### Rule 5: Repository Interface Lives in the Domain Layer

The domain defines what persistence operations it needs. The infrastructure provides the implementation. The domain repository interface uses domain types, never JPA entities or Spring annotations.

```java
// domain/repository/OrderRepository.java -- INTERFACE ONLY
public interface OrderRepository {
    Order findById(OrderId id);
    Optional<Order> findOptionalById(OrderId id);
    List<Order> findByCustomerId(CustomerId customerId);
    void save(Order order);
    void delete(OrderId id);
    boolean existsById(OrderId id);
}
```

```java
// infrastructure/persistence/jpa/OrderPersistenceAdapter.java
@Repository
class OrderPersistenceAdapter implements OrderPersistencePort {

    private final OrderJpaRepository jpaRepository;
    private final OrderMapper mapper;

    @Override
    public void save(Order order) {
        var entity = mapper.toJpaEntity(order);
        jpaRepository.save(entity);
    }

    @Override
    public Order findById(OrderId id) {
        return jpaRepository.findById(id.value())
            .map(mapper::toDomainModel)
            .orElseThrow(() -> new OrderNotFoundException(id));
    }
}
```

### Rule 6: JPA Entities Are Not Domain Entities

JPA entities (`@Entity`) live in the infrastructure layer. They are persistence representations, not the domain model. A mapper converts between them. This prevents JPA concerns (lazy loading, dirty checking, proxy objects) from leaking into the domain.

```java
// infrastructure/persistence/jpa/OrderJpaEntity.java
@Entity
@Table(name = "orders")
class OrderJpaEntity {
    @Id
    private UUID id;

    @Column(name = "customer_id", nullable = false)
    private UUID customerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @Column(name = "total_amount", nullable = false)
    private BigDecimal totalAmount;

    @Column(name = "currency", nullable = false, length = 3)
    private String currency;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItemJpaEntity> items = new ArrayList<>();

    // JPA requires no-arg constructor
    protected OrderJpaEntity() {}
}
```

### Rule 7: Anti-Corruption Layer for External Bounded Contexts

When communicating with another bounded context (e.g., Inventory Service), define your own representation of external concepts. Never let the external model leak into your domain.

```java
// domain/model/customer/CustomerId.java
// This is YOUR bounded context's view of a customer -- just an ID reference
public record CustomerId(UUID value) {
    public CustomerId {
        Objects.requireNonNull(value);
    }
}

// infrastructure/external/inventory/InventoryClient.java
// ACL: Translates external API response to your domain's language
@Component
class InventoryAntiCorruptionLayer {

    private final InventoryServiceClient client;

    StockAvailability checkAvailability(ProductId productId, int quantity) {
        // Call external service
        var response = client.getStock(productId.value().toString());

        // Translate external concepts to domain concepts
        return new StockAvailability(
            productId,
            response.getAvailableUnits() >= quantity,
            response.getAvailableUnits()
        );
    }
}
```

### Rule 8: Architecture Tests Enforce Layering

Use ArchUnit to prevent dependency violations. These tests run as part of the unit test suite.

```java
@AnalyzeClasses(packages = "com.company.orderservice")
class ArchitectureTest {

    @ArchTest
    static final ArchRule domain_should_not_depend_on_infrastructure =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..infrastructure..", "..interfaces..");

    @ArchTest
    static final ArchRule domain_should_not_use_spring =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAnyPackage(
                "org.springframework..",
                "jakarta.persistence..",
                "jakarta.transaction.."
            );

    @ArchTest
    static final ArchRule application_should_not_depend_on_infrastructure =
        noClasses()
            .that().resideInAPackage("..application..")
            .should().dependOnClassesThat()
            .resideInAnyPackage("..infrastructure..", "..interfaces..");

    @ArchTest
    static final ArchRule controllers_should_only_call_use_cases =
        classes()
            .that().resideInAPackage("..interfaces.rest..")
            .should().onlyDependOnClassesThat()
            .resideInAnyPackage(
                "..interfaces..",
                "..application.port.in..",
                "..application.dto..",
                "java..",
                "jakarta.validation..",
                "org.springframework.."
            );
}
```

## Examples

### Example: Full Aggregate Lifecycle

```java
// 1. Create aggregate
var orderId = OrderId.generate();
var customerId = new CustomerId(UUID.fromString("abc-123"));
var items = List.of(
    new OrderItem(new ProductId(UUID.randomUUID()), "Widget", new Money(new BigDecimal("29.99"), USD), 2)
);
var order = Order.create(orderId, customerId, items);

// 2. Transition state through domain methods
order.place();                          // DRAFT -> PLACED, emits OrderPlacedEvent

// 3. Persist and publish
repository.save(order);
order.getDomainEvents().forEach(publisher::publishEvent);
order.clearDomainEvents();
```

### Example: Handling Domain Events Across Bounded Contexts

```java
// Within same service -- use Spring event listener
@Component
class OrderPlacedNotificationHandler {

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent event) {
        // Send confirmation email, update analytics, etc.
    }
}

// Across services -- publish to Kafka via outbox
@Component
class OrderEventOutboxPublisher {

    private final OutboxRepository outbox;

    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent event) {
        outbox.save(new OutboxEntry(
            "order.placed",
            event.orderId().toString(),
            serialize(event)
        ));
    }
}
```

### Example: Value Object Replacing Primitive Obsession

Before (primitive obsession):
```java
public void createOrder(String customerId, String email, double amount, String currency) { ... }
```

After (value objects):
```java
public void createOrder(CustomerId customerId, EmailAddress email, Money amount) { ... }
```

Every important domain concept gets its own type. This makes illegal states unrepresentable and provides compile-time safety.
