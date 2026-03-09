---
name: gradle-spring-conventions
description: Gradle build conventions and Spring Boot 3.x project structure patterns for Java 21 microservices including multi-module setup, dependency management, and build optimization
version: 1.0.0
tags: [gradle, spring-boot, java-21, build, microservices, docker]
globs:
  - "build.gradle.kts"
  - "settings.gradle.kts"
  - "gradle/libs.versions.toml"
  - "buildSrc/**/*.kts"
  - "**/build.gradle.kts"
  - "gradle.properties"
  - "Dockerfile"
---

# Gradle + Spring Boot 3.x Conventions

## Purpose

Establish consistent Gradle build conventions for Java 21 + Spring Boot 3.x microservices. This skill enforces a standardized multi-module project structure, centralized dependency management via version catalogs, optimized build performance, and reproducible Docker image creation. Following these conventions ensures every microservice in the ecosystem builds, tests, and packages identically.

## When to Use

- Creating a new Spring Boot 3.x microservice from scratch
- Adding a new module to an existing multi-module Gradle project
- Configuring dependency management across multiple services
- Setting up CI-friendly build configurations
- Optimizing Gradle build performance (caching, parallel execution, daemon tuning)
- Building Docker images for deployment
- Splitting unit tests from integration tests in the build lifecycle

## Project Structure

Every microservice follows this multi-module layout:

```
service-name/
  settings.gradle.kts
  build.gradle.kts                    # Root build with shared config
  gradle.properties                    # Build tuning and version props
  gradle/
    libs.versions.toml                 # Version catalog (single source of truth)
  buildSrc/
    build.gradle.kts                   # Convention plugins build
    src/main/kotlin/
      java-conventions.gradle.kts      # Shared Java compilation config
      spring-conventions.gradle.kts    # Shared Spring Boot config
      test-conventions.gradle.kts      # Test separation config
  app/
    build.gradle.kts                   # Spring Boot application module
    src/main/java/
    src/main/resources/
    src/test/java/                     # Unit tests
    src/integrationTest/java/          # Integration tests
  domain/
    build.gradle.kts                   # Pure domain logic, no Spring deps
    src/main/java/
    src/test/java/
  infrastructure/
    build.gradle.kts                   # DB, messaging, external APIs
    src/main/java/
    src/test/java/
    src/integrationTest/java/
```

## Workflow and Rules

### Rule 1: Always Use Kotlin DSL

All Gradle build files use `.gradle.kts` (Kotlin DSL), never Groovy `.gradle` files. Kotlin DSL provides type safety, IDE autocompletion, and refactoring support.

### Rule 2: Version Catalog Is the Single Source of Truth

Every dependency version lives in `gradle/libs.versions.toml`. No version strings appear in `build.gradle.kts` files. No `ext` blocks for version management.

```toml
# gradle/libs.versions.toml
[versions]
java = "21"
spring-boot = "3.3.5"
spring-dependency-management = "1.1.6"
spring-cloud = "2023.0.3"
postgresql = "42.7.4"
flyway = "10.21.0"
jooq = "3.19.15"
testcontainers = "1.20.4"
archunit = "1.3.0"
mapstruct = "1.6.3"
springdoc = "2.7.0"
jackson-bom = "2.18.1"

[libraries]
spring-boot-starter-web = { module = "org.springframework.boot:spring-boot-starter-web" }
spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
spring-boot-starter-validation = { module = "org.springframework.boot:spring-boot-starter-validation" }
spring-boot-starter-actuator = { module = "org.springframework.boot:spring-boot-starter-actuator" }
spring-boot-starter-security = { module = "org.springframework.boot:spring-boot-starter-security" }
spring-boot-starter-test = { module = "org.springframework.boot:spring-boot-starter-test" }
spring-boot-devtools = { module = "org.springframework.boot:spring-boot-devtools" }
spring-boot-docker-compose = { module = "org.springframework.boot:spring-boot-docker-compose" }
spring-cloud-bom = { module = "org.springframework.cloud:spring-cloud-dependencies", version.ref = "spring-cloud" }
postgresql = { module = "org.postgresql:postgresql", version.ref = "postgresql" }
flyway-core = { module = "org.flywaydb:flyway-core", version.ref = "flyway" }
flyway-postgresql = { module = "org.flywaydb:flyway-database-postgresql", version.ref = "flyway" }
testcontainers-bom = { module = "org.testcontainers:testcontainers-bom", version.ref = "testcontainers" }
testcontainers-postgresql = { module = "org.testcontainers:postgresql" }
testcontainers-junit-jupiter = { module = "org.testcontainers:junit-jupiter" }
archunit-junit5 = { module = "com.tngtech.archunit:archunit-junit5", version.ref = "archunit" }
mapstruct = { module = "org.mapstruct:mapstruct", version.ref = "mapstruct" }
mapstruct-processor = { module = "org.mapstruct:mapstruct-processor", version.ref = "mapstruct" }
springdoc-openapi-starter = { module = "org.springdoc:springdoc-openapi-starter-webmvc-ui", version.ref = "springdoc" }

[plugins]
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }
spring-dependency-management = { id = "io.spring.dependency-management", version.ref = "spring-dependency-management" }
jib = { id = "com.google.cloud.tools.jib", version = "3.4.4" }
```

### Rule 3: Convention Plugins for Shared Configuration

Use `buildSrc` convention plugins to avoid duplicating configuration across modules.

```kotlin
// buildSrc/build.gradle.kts
plugins {
    `kotlin-dsl`
}

repositories {
    gradlePluginPortal()
}
```

```kotlin
// buildSrc/src/main/kotlin/java-conventions.gradle.kts
plugins {
    java
    jacoco
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
    options.compilerArgs.addAll(listOf(
        "-parameters",           // Preserve parameter names for Spring
        "--enable-preview",      // Enable preview features if needed
        "-Xlint:all",
        "-Xlint:-processing"     // Suppress annotation processor warnings
    ))
}

jacoco {
    toolVersion = "0.8.12"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true)   // For CI integration (SonarQube, Codecov)
        html.required.set(true)
    }
}
```

```kotlin
// buildSrc/src/main/kotlin/test-conventions.gradle.kts
plugins {
    java
}

// Create integration test source set
sourceSets {
    create("integrationTest") {
        compileClasspath += sourceSets.main.get().output + sourceSets.test.get().output
        runtimeClasspath += sourceSets.main.get().output + sourceSets.test.get().output
    }
}

configurations["integrationTestImplementation"].extendsFrom(configurations.testImplementation.get())
configurations["integrationTestRuntimeOnly"].extendsFrom(configurations.testRuntimeOnly.get())

tasks.test {
    useJUnitPlatform {
        excludeTags("integration")
    }
    maxParallelForks = (Runtime.getRuntime().availableProcessors() / 2).coerceAtLeast(1)
    jvmArgs("-XX:+EnableDynamicAgentLoading")  // Suppress Mockito/ByteBuddy warnings on Java 21
}

val integrationTest by tasks.registering(Test::class) {
    description = "Runs integration tests."
    group = "verification"
    testClassesDirs = sourceSets["integrationTest"].output.classesDirs
    classpath = sourceSets["integrationTest"].runtimeClasspath
    useJUnitPlatform {
        includeTags("integration")
    }
    shouldRunAfter(tasks.test)
    jvmArgs("-XX:+EnableDynamicAgentLoading")
}

tasks.check {
    dependsOn(integrationTest)
}
```

### Rule 4: Root Build File Applies Shared Config

```kotlin
// build.gradle.kts (root)
plugins {
    alias(libs.plugins.spring.boot) apply false
    alias(libs.plugins.spring.dependency.management) apply false
}

allprojects {
    group = "com.company.servicename"
    version = "0.0.1-SNAPSHOT"

    repositories {
        mavenCentral()
    }
}

subprojects {
    apply(plugin = "java-conventions")
    apply(plugin = "test-conventions")
}
```

### Rule 5: Domain Module Has Zero Framework Dependencies

The `domain` module contains only pure Java code. No Spring, no JPA annotations, no framework coupling.

```kotlin
// domain/build.gradle.kts
plugins {
    id("java-conventions")
    id("test-conventions")
}

dependencies {
    // Only allowed: Java standard library, small utility libs
    // NO Spring, NO JPA, NO infrastructure concerns
    testImplementation(libs.spring.boot.starter.test)  // JUnit5 + AssertJ only
}
```

### Rule 6: App Module Wires Everything Together

```kotlin
// app/build.gradle.kts
plugins {
    id("java-conventions")
    id("test-conventions")
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spring.dependency.management)
    alias(libs.plugins.jib)
}

dependencies {
    implementation(project(":domain"))
    implementation(project(":infrastructure"))

    implementation(libs.spring.boot.starter.web)
    implementation(libs.spring.boot.starter.actuator)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.springdoc.openapi.starter)

    developmentOnly(libs.spring.boot.devtools)
    developmentOnly(libs.spring.boot.docker.compose)

    testImplementation(libs.spring.boot.starter.test)

    "integrationTestImplementation"(libs.testcontainers.junit.jupiter)
    "integrationTestImplementation"(libs.testcontainers.postgresql)
}

jib {
    from {
        image = "eclipse-temurin:21-jre-alpine"
    }
    to {
        image = "ghcr.io/company/${project.name}"
        tags = setOf("latest", project.version.toString())
    }
    container {
        jvmFlags = listOf(
            "-XX:+UseZGC",
            "-XX:MaxRAMPercentage=75.0",
            "-Djava.security.egd=file:/dev/./urandom"
        )
        ports = listOf("8080")
        creationTime.set("USE_CURRENT_TIMESTAMP")
        labels.set(mapOf("maintainer" to "platform-team@company.com"))
    }
}
```

### Rule 7: Gradle Properties for Build Performance

```properties
# gradle.properties
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.jvmargs=-Xmx2g -XX:+UseZGC -XX:+HeapDumpOnOutOfMemoryError
org.gradle.workers.max=4

# Spring Boot
spring-boot.build-image.imageName=ghcr.io/company/${project.name}

# Disable Kotlin DSL precompiled script plugins warnings
systemProp.org.gradle.kotlin.dsl.precompiled.accessors.strict=true
```

### Rule 8: Settings File Configures Module Inclusion and Plugin Management

```kotlin
// settings.gradle.kts
rootProject.name = "order-service"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenCentral()
    }
}

include("domain", "infrastructure", "app")
```

### Rule 9: Profile-Based Application Configuration

```
app/src/main/resources/
  application.yml                  # Shared defaults
  application-local.yml            # Local dev (Docker Compose)
  application-test.yml             # Test profile (Testcontainers)
  application-staging.yml          # Staging overrides
  application-prod.yml             # Production (env vars only)
```

Production config references environment variables only -- never hardcoded secrets:

```yaml
# application.yml
spring:
  application:
    name: order-service
  datasource:
    url: ${DATABASE_URL:jdbc:postgresql://localhost:5432/orderdb}
    username: ${DATABASE_USERNAME:order_user}
    password: ${DATABASE_PASSWORD:changeme}
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate
  flyway:
    enabled: true
    locations: classpath:db/migration

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized

server:
  port: ${SERVER_PORT:8080}
  shutdown: graceful

springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui
```

### Rule 10: GitHub Actions Build Integration

```yaml
# .github/workflows/build.yml
name: Build & Test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21

      - uses: gradle/actions/setup-gradle@v4
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Build and Test
        run: ./gradlew build --no-daemon --scan

      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
        with:
          files: "**/build/test-results/**/*.xml"

      - name: Build Docker Image
        if: github.ref == 'refs/heads/main'
        run: ./gradlew jib --no-daemon
```

## Examples

### Example: Adding a New Dependency

Never add versions directly. Add to the version catalog first, then reference the alias.

```toml
# gradle/libs.versions.toml -- add entry
[versions]
resilience4j = "2.2.0"

[libraries]
resilience4j-spring-boot3 = { module = "io.github.resilience4j:resilience4j-spring-boot3", version.ref = "resilience4j" }
resilience4j-circuitbreaker = { module = "io.github.resilience4j:resilience4j-circuitbreaker", version.ref = "resilience4j" }
```

```kotlin
// infrastructure/build.gradle.kts -- reference alias
dependencies {
    implementation(libs.resilience4j.spring.boot3)
    implementation(libs.resilience4j.circuitbreaker)
}
```

### Example: Running Only Unit Tests Locally

```bash
./gradlew test                     # Unit tests only (fast)
./gradlew integrationTest          # Integration tests only
./gradlew check                    # Both unit + integration
./gradlew test --tests "*.OrderServiceTest"  # Single test class
```

### Example: Creating a New Module

1. Create the directory: `mkdir -p notification/src/main/java`
2. Add `notification/build.gradle.kts` with appropriate convention plugins
3. Add to `settings.gradle.kts`: `include("notification")`
4. Wire into dependent modules via `implementation(project(":notification"))`
