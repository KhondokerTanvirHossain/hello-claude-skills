---
name: api-documentation
description: >
  API documentation generation and maintenance patterns for Spring Boot 3.x
  microservices using SpringDoc OpenAPI, including annotation best practices,
  API grouping by audience, example values for requests and responses, developer
  portal structure, SDK code generation from specs, versioned documentation,
  CI validation of OpenAPI specs, and changelog management. Trigger: "API docs",
  "OpenAPI setup", "Swagger config", "developer portal", "SDK generation",
  "document this endpoint", "API changelog"
tech_stack:
  - Java 21
  - Spring Boot 3.x
  - SpringDoc OpenAPI
  - Gradle
  - React
  - TypeScript
tags:
  - api
  - documentation
  - openapi
  - swagger
  - developer-experience
  - saas
  - sdk-generation
---

# API Documentation Generation and Maintenance Patterns

## Purpose

Define standards for generating, maintaining, and publishing API documentation for Spring Boot microservices. For developer-facing SaaS, API documentation is a product feature that directly impacts adoption, reduces support burden, and builds developer trust. This skill covers SpringDoc OpenAPI configuration, annotation conventions, example bodies with realistic data, authentication documentation, API grouping by audience (public, admin, internal), versioning and deprecation patterns, client SDK generation from specs, developer portal structure, CI validation pipelines, and changelog management.

## When to Use

- Setting up API documentation for a new Spring Boot microservice
- Standardizing OpenAPI annotations across an existing codebase
- Building or improving a developer portal for external API consumers
- Generating client SDKs (TypeScript, Python, Go) from OpenAPI specs
- Documenting authentication flows (API keys, OAuth2, JWT)
- Managing API versioning and publishing migration guides
- Adding interactive "try it out" functionality to documentation
- Setting up CI validation to catch breaking API changes

## Workflow: Documentation Setup

### Step 1: SpringDoc OpenAPI Dependencies

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0")
    implementation("org.springdoc:springdoc-openapi-starter-common:2.3.0")
}
```

### Step 2: OpenAPI Configuration

```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI(
            @Value("${app.version}") String appVersion,
            @Value("${app.api.base-url}") String baseUrl) {

        return new OpenAPI()
            .info(new Info()
                .title("Acme Platform API")
                .version(appVersion)
                .description("""
                    The Acme Platform API allows you to programmatically manage projects,
                    pipelines, deployments, and team members. All API access is over HTTPS
                    and data is sent and received as JSON.

                    ## Authentication
                    All API requests require an API key passed in the `X-API-Key` header
                    or a JWT Bearer token in the `Authorization` header.

                    ## Rate Limits
                    Rate limits vary by plan tier. See the Rate Limiting section for details.

                    ## Errors
                    The API uses RFC 7807 Problem Details format for all error responses.
                    """)
                .contact(new Contact()
                    .name("API Support")
                    .email("api-support@acme.dev")
                    .url("https://docs.acme.dev/support"))
                .license(new License().name("Proprietary").url("https://acme.dev/terms")))
            .externalDocs(new ExternalDocumentation()
                .description("Full API Documentation")
                .url("https://docs.acme.dev"))
            .addServersItem(new Server().url(baseUrl).description("Production API"))
            .addServersItem(new Server().url("https://api.staging.acme.dev").description("Staging (test data)"))
            .addSecurityItem(new SecurityRequirement().addList("ApiKeyAuth"))
            .addSecurityItem(new SecurityRequirement().addList("BearerAuth"))
            .components(new Components()
                .addSecuritySchemes("ApiKeyAuth", new SecurityScheme()
                    .type(SecurityScheme.Type.APIKEY)
                    .in(SecurityScheme.In.HEADER)
                    .name("X-API-Key")
                    .description("API key from workspace settings"))
                .addSecuritySchemes("BearerAuth", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")
                    .description("JWT token from POST /api/v1/auth/login"))
                .addSchemas("ProblemDetail", new Schema<>()
                    .type("object")
                    .addProperty("type", new Schema<>().type("string").example("https://api.acme.dev/problems/validation-error"))
                    .addProperty("title", new Schema<>().type("string").example("Validation Failed"))
                    .addProperty("status", new Schema<>().type("integer").example(400))
                    .addProperty("detail", new Schema<>().type("string").example("One or more fields failed validation"))
                    .addProperty("instance", new Schema<>().type("string").example("/api/v1/projects"))
                    .required(List.of("type", "title", "status", "detail"))));
    }

    @Bean
    public GroupedOpenApi publicApi() {
        return GroupedOpenApi.builder()
            .group("public-api")
            .displayName("Public API")
            .pathsToMatch("/api/v1/**")
            .pathsToExclude("/api/v1/internal/**", "/api/webhooks/**")
            .build();
    }

    @Bean
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
            .group("admin-api")
            .displayName("Admin API")
            .pathsToMatch("/admin/api/v1/**")
            .build();
    }

    @Bean
    public GroupedOpenApi webhookApi() {
        return GroupedOpenApi.builder()
            .group("webhooks")
            .displayName("Webhook Events")
            .pathsToMatch("/api/webhooks/**")
            .build();
    }
}
```

**Application properties:**

```yaml
# application.yml
springdoc:
  api-docs:
    path: /api-docs
    enabled: true
  swagger-ui:
    path: /swagger-ui.html
    enabled: true
    try-it-out-enabled: true
    filter: true
    tags-sorter: alpha
    operations-sorter: method
    display-request-duration: true
  show-actuator: false
  default-produces-media-type: application/json
  default-consumes-media-type: application/json
```

### Step 3: Annotation Conventions

Every public API endpoint MUST have the minimum set of OpenAPI annotations.

**Controller-level tag:**

```java
@RestController
@RequestMapping("/api/v1/projects")
@Tag(name = "Projects", description = "Create, manage, and configure projects within your workspace")
public class ProjectController {
    // ...
}
```

**Endpoint-level operation with full annotations:**

```java
@Operation(
    summary = "Create a new project",
    description = """
        Creates a new project in the current workspace. A project acts as a container
        for pipelines, environments, and deployments. Each project can be linked to
        a source code repository for CI/CD integration.

        **Required permissions:** `project:create`
        """,
    operationId = "createProject"
)
@ApiResponses({
    @ApiResponse(
        responseCode = "201",
        description = "Project created successfully",
        content = @Content(
            mediaType = "application/json",
            schema = @Schema(implementation = ProjectResponse.class),
            examples = @ExampleObject(name = "New Project", value = """
                {
                    "id": "proj_abc123",
                    "name": "Backend API",
                    "slug": "backend-api",
                    "description": "Main backend API service",
                    "repository": {
                        "provider": "github",
                        "url": "https://github.com/acme/backend-api"
                    },
                    "created_at": "2024-03-01T10:30:00Z"
                }
                """)
        )
    ),
    @ApiResponse(
        responseCode = "400",
        description = "Invalid request body",
        content = @Content(
            mediaType = "application/json",
            schema = @Schema(ref = "#/components/schemas/ProblemDetail"),
            examples = @ExampleObject(value = """
                {
                    "type": "https://api.acme.dev/problems/validation-error",
                    "title": "Validation Failed",
                    "status": 400,
                    "detail": "One or more fields failed validation",
                    "errors": [
                        {"field": "name", "message": "must not be blank"}
                    ]
                }
                """)
        )
    ),
    @ApiResponse(responseCode = "401", description = "Authentication required"),
    @ApiResponse(responseCode = "403", description = "Insufficient permissions"),
    @ApiResponse(responseCode = "409", description = "Project with this name already exists"),
    @ApiResponse(responseCode = "429", description = "Rate limit exceeded")
})
@PostMapping
public ResponseEntity<ProjectResponse> createProject(
        @Valid @RequestBody CreateProjectRequest request) {
    // implementation
}
```

**DTO schema annotations with realistic examples:**

```java
@Schema(description = "Request to create a new project")
public record CreateProjectRequest(
    @Schema(
        description = "Project name (unique within workspace)",
        example = "Backend API",
        minLength = 1,
        maxLength = 64,
        requiredMode = Schema.RequiredMode.REQUIRED
    )
    @NotBlank @Size(max = 64)
    String name,

    @Schema(
        description = "Human-readable project description",
        example = "Main backend API service powering web and mobile apps",
        maxLength = 512,
        requiredMode = Schema.RequiredMode.NOT_REQUIRED
    )
    @Size(max = 512)
    String description,

    @Schema(
        description = "Repository URL for source code integration",
        example = "https://github.com/acme/backend-api",
        pattern = "^https://(github\\.com|gitlab\\.com|bitbucket\\.org)/.*$",
        requiredMode = Schema.RequiredMode.NOT_REQUIRED
    )
    String repositoryUrl
) {}
```

### Step 4: Authentication Documentation

Create a dedicated authentication section with curl examples.

```java
@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = """
    ## API Key Authentication (server-to-server)

    Include your API key in the `X-API-Key` header:
    ```
    curl -H "X-API-Key: ak_live_abc123..." https://api.acme.dev/api/v1/projects
    ```

    Create API keys in **Settings > API Keys** in your workspace dashboard.

    ## JWT Bearer Token (frontend/mobile apps)

    1. Obtain a token via `POST /api/v1/auth/login`
    2. Include the token in the `Authorization` header:
    ```
    curl -H "Authorization: Bearer eyJhbG..." https://api.acme.dev/api/v1/projects
    ```

    JWT tokens expire after 1 hour. Use the refresh endpoint for new tokens.
    """)
public class AuthController {
    // endpoints documented individually
}
```

### Step 5: API Versioning Documentation

```java
@Configuration
public class ApiVersioningConfig {

    @Bean
    public GroupedOpenApi v1Api() {
        return GroupedOpenApi.builder()
            .group("v1")
            .pathsToMatch("/api/v1/**")
            .addOpenApiCustomizer(openApi -> openApi.getInfo()
                .setTitle("Acme API v1")
                .setDescription("Current stable version"))
            .build();
    }

    @Bean
    public GroupedOpenApi v2Api() {
        return GroupedOpenApi.builder()
            .group("v2")
            .pathsToMatch("/api/v2/**")
            .addOpenApiCustomizer(openApi -> openApi.getInfo()
                .setTitle("Acme API v2 (Beta)")
                .setDescription("Next version with breaking changes from v1. See migration guide."))
            .build();
    }
}
```

**Deprecation annotation pattern:**

```java
@Operation(
    summary = "List projects (DEPRECATED)",
    deprecated = true,
    description = """
        **DEPRECATED:** This endpoint will be removed on 2026-09-01.
        Use `GET /api/v2/projects` instead, which supports cursor-based pagination.
        See the [Migration Guide](https://docs.acme.dev/api/migration/v1-to-v2).
        """
)
@GetMapping("/api/v1/projects")
public ResponseEntity<Page<ProjectResponse>> listProjectsV1(Pageable pageable) {
    return ResponseEntity.ok()
        .header("Sunset", "Mon, 01 Sep 2026 00:00:00 GMT")
        .header("Link", "</api/v2/projects>; rel=\"successor-version\"")
        .body(projectService.listProjects(pageable));
}
```

### Step 6: SDK Generation from Specs

```kotlin
// build.gradle.kts
plugins {
    id("org.openapi.generator") version "7.2.0"
}

openApiGenerate {
    generatorName.set("typescript-fetch")
    inputSpec.set("${layout.buildDirectory.get()}/api-docs/public-api.json")
    outputDir.set("${layout.buildDirectory.get()}/generated-sdk/typescript")
    configOptions.set(mapOf(
        "npmName" to "@acme/api-client",
        "npmVersion" to project.version.toString(),
        "supportsES6" to "true",
        "typescriptThreePlus" to "true",
        "withInterfaces" to "true",
        "useSingleRequestParameter" to "true"
    ))
}

tasks.register("exportOpenApiSpec") {
    group = "documentation"
    description = "Exports OpenAPI spec from running application"
    doLast {
        val specUrl = "http://localhost:8080/api-docs/public-api"
        val outputFile = file("${layout.buildDirectory.get()}/api-docs/public-api.json")
        outputFile.parentFile.mkdirs()
        outputFile.writeText(java.net.URI(specUrl).toURL().readText())
    }
}
```

### Step 7: Developer Portal Structure

```
docs/
  index.md                    # Getting started / quickstart
  authentication.md           # Auth methods, API keys, OAuth, curl examples
  rate-limiting.md            # Rate limit tiers, headers, best practices
  errors.md                   # RFC 7807 format, error codes, troubleshooting
  pagination.md               # Cursor vs offset patterns, code examples
  webhooks.md                 # Webhook setup, event types, signature verification
  api-reference/
    projects.md               # Auto-generated from OpenAPI spec
    pipelines.md
    deployments.md
    team.md
  sdks/
    typescript.md             # SDK installation, usage, code examples
    python.md
    go.md
  guides/
    first-api-call.md         # Step-by-step beginner tutorial
    ci-cd-integration.md      # Integration guide
    webhook-handling.md       # Webhook implementation walkthrough
  changelog/
    2026-03-01.md             # API changelog entries by date
    2026-02-15.md
  migration/
    v1-to-v2.md               # Breaking change migration guide
```

## CI Validation Pipeline

```yaml
# .github/workflows/api-docs.yml
name: API Documentation
on:
  pull_request:
    paths:
      - 'src/main/java/**/controller/**'
      - 'src/main/java/**/dto/**'

jobs:
  validate-openapi:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21
      - name: Start application
        run: ./gradlew bootRun &
      - name: Wait for startup
        run: |
          for i in $(seq 1 30); do
            curl -s http://localhost:8080/actuator/health && break || sleep 2
          done
      - name: Export OpenAPI spec
        run: curl -s http://localhost:8080/api-docs/public-api > openapi-pr.json
      - name: Validate spec schema
        uses: char0n/swagger-editor-validate@v1
        with:
          definition-file: openapi-pr.json
      - name: Check for breaking changes against main
        run: |
          git fetch origin main
          git show origin/main:openapi.json > openapi-main.json 2>/dev/null || echo '{}' > openapi-main.json
          npx @redocly/cli@latest diff openapi-pr.json openapi-main.json --severity error
```

## Rules

1. **Every public endpoint MUST have an `@Operation` annotation.** Include `summary` (short, imperative verb phrase), `description` (detailed, with permission notes), and `operationId` (unique, camelCase).
2. **Every request/response DTO MUST have `@Schema` annotations.** Include `description`, `example` (realistic data, not "string" or "0"), and `requiredMode` on every field.
3. **Provide at least one `@ExampleObject` for every request body and every success response.** Use realistic data that developers can copy-paste and test.
4. **Document all error responses.** Minimum: 400 (validation), 401 (auth), 403 (permissions), 404 (not found), 429 (rate limit). Include example error bodies.
5. **The OpenAPI spec is the single source of truth.** SDKs, docs, and mock servers are all generated from it. Keep the spec accurate.
6. **Deprecated endpoints MUST include `Sunset` and `Link` headers** pointing to the replacement endpoint.
7. **Run OpenAPI spec validation in CI.** Validate against the OpenAPI 3.1 schema and check for breaking changes on every PR.
8. **Changelog entries are mandatory for every API change.** New endpoints, changed fields, deprecations, and removals.
9. **Authentication docs must exist outside the OpenAPI spec.** Provide standalone auth docs with curl examples, SDK snippets, and common error troubleshooting.

## Examples

### Example 1: Pagination Documentation Pattern

```java
@Operation(
    summary = "List pipeline runs",
    description = """
        Returns a paginated list of pipeline runs for the specified project.
        Uses cursor-based pagination. Use the `cursor` from the response `meta`
        object to fetch the next page.
        """
)
@GetMapping
public ResponseEntity<CursorPage<PipelineRunResponse>> listPipelineRuns(
        @Parameter(description = "Project ID", required = true, example = "proj_abc123")
        @PathVariable String projectId,

        @Parameter(description = "Items per page (max 100)", example = "25")
        @RequestParam(defaultValue = "25") @Max(100) int limit,

        @Parameter(description = "Cursor for the next page (from previous response)")
        @RequestParam(required = false) String cursor,

        @Parameter(description = "Filter by status",
                   schema = @Schema(allowableValues = {"running", "succeeded", "failed", "canceled"}))
        @RequestParam(required = false) String status
) {
    // implementation
}
```

### Example 2: Webhook Event Documentation

```java
@Schema(description = "Webhook event payload delivered to your configured endpoint")
public record WebhookEvent(
    @Schema(description = "Unique event ID for idempotency", example = "evt_abc123def456")
    String id,

    @Schema(description = "Event type following `resource.action` pattern",
            example = "pipeline.completed",
            allowableValues = {
                "pipeline.started", "pipeline.completed", "pipeline.failed",
                "deployment.started", "deployment.completed", "deployment.failed",
                "project.created", "project.deleted",
                "team.member_added", "team.member_removed"
            })
    String type,

    @Schema(description = "ISO 8601 timestamp", example = "2024-03-01T10:30:00Z")
    Instant createdAt,

    @Schema(description = "Event payload (structure varies by event type)")
    Object data
) {}
```

### Example 3: Environment-Specific Swagger Configuration

```yaml
# application-dev.yml
springdoc:
  swagger-ui:
    try-it-out-enabled: true
    persist-authorization: true
    oauth:
      client-id: dev-swagger-client
    supported-submit-methods: [get, post, put, patch, delete]

# application-prod.yml
springdoc:
  swagger-ui:
    enabled: false    # Use developer portal instead
  api-docs:
    enabled: true     # Keep spec endpoint for SDK generation
```
