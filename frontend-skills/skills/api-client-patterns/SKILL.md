---
name: api-client-patterns
description: |
  Type-safe API client with OpenAPI codegen for React + TypeScript applications.
  Trigger phrases: "api client", "openapi codegen", "type-safe api", "api layer setup",
  "request interceptor", "error handling api", "retry policy", "tanstack query api",
  "msw mock", "cache invalidation", "api client patterns"
version: 1.0.0
tags:
  - api-client
  - openapi
  - codegen
  - typescript
  - react-query
  - tanstack-query
  - msw
  - error-handling
  - interceptors
globs:
  - "src/api/**/*.ts"
  - "src/clients/**/*.ts"
  - "src/interceptors/**/*.ts"
  - "src/generated/**/*.ts"
  - "src/queries/**/*.ts"
  - "src/mutations/**/*.ts"
  - "openapi-config.*"
---

# API Client Patterns

## Purpose

Define conventions for building type-safe API clients in React + TypeScript applications that consume Spring Boot REST APIs. This skill covers the full lifecycle of API communication: generating TypeScript types from OpenAPI specifications using openapi-typescript and openapi-fetch, wrapping HTTP clients with consistent interceptors for authentication and error handling, implementing retry logic for transient failures, mapping backend error responses (RFC 7807) to typed frontend error models, managing cache invalidation with TanStack Query, and mocking API calls with MSW for tests.

## When to Use

- Setting up the API client layer for a new React + TypeScript frontend project.
- Generating TypeScript types and client code from a Spring Boot service's OpenAPI spec.
- Implementing request interceptors for auth tokens, trace IDs, or tenant context.
- Implementing response interceptors for error normalization, token refresh, or logging.
- Adding retry logic for transient network failures or 5xx responses.
- Mapping Spring Boot's error response format (RFC 7807 Problem Details) to a typed frontend error model.
- Setting up MSW (Mock Service Worker) for API mocking in tests and Storybook.
- Designing cache invalidation strategies with TanStack Query.
- Handling API versioning when consuming multiple versions of a backend service.

## Workflow and Rules

### Rule 1: OpenAPI Spec-First Workflow

Each Spring Boot microservice exposes an OpenAPI 3.x specification via springdoc-openapi. The frontend project generates TypeScript types from these specs at build time. The spec is the single source of truth for the API contract.

**Project structure for generated code:**

```
src/
  generated/
    project-service/
      types.ts          # Generated request/response types
      schemas.ts         # Generated Zod schemas (optional runtime validation)
    billing-service/
      types.ts
    user-service/
      types.ts
  api/
    client.ts           # Configured openapi-fetch client instances
    errors.ts           # Error types and mapping
    interceptors/
      auth.ts           # Auth token injection
      trace.ts          # Request tracing headers
      tenant.ts         # Multi-tenant context
    retry.ts            # Retry logic
  queries/              # TanStack Query hooks (read operations)
  mutations/            # TanStack Query mutation hooks (write operations)
specs/
  project-service.yaml  # Committed OpenAPI specs
  billing-service.yaml
  user-service.yaml
```

**Codegen tool selection: openapi-typescript + openapi-fetch**

Use `openapi-typescript` for type generation and `openapi-fetch` for the runtime client. This combination provides:
- Zero runtime overhead for types (compile-time only)
- Full path-level type safety (autocomplete on paths, methods, params, and body)
- No code generation for runtime client (uses native fetch, typed via generics)

```bash
npm install openapi-fetch
npm install -D openapi-typescript
```

**Codegen configuration:**

```json
// package.json scripts
{
  "scripts": {
    "codegen": "npm-run-all codegen:*",
    "codegen:project-service": "openapi-typescript specs/project-service.yaml -o src/generated/project-service/types.ts",
    "codegen:billing-service": "openapi-typescript specs/billing-service.yaml -o src/generated/billing-service/types.ts",
    "codegen:user-service": "openapi-typescript specs/user-service.yaml -o src/generated/user-service/types.ts",
    "codegen:check": "npm run codegen && git diff --exit-code src/generated/"
  }
}
```

**CI pipeline for spec sync:**

```yaml
# .github/workflows/sync-api-specs.yml
name: Sync API Specs
on:
  repository_dispatch:
    types: [api-spec-updated]
  workflow_dispatch:
    inputs:
      service:
        description: 'Service name'
        required: true
        type: choice
        options: [project-service, billing-service, user-service]

jobs:
  sync-specs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download latest spec
        run: |
          SERVICE=${{ github.event.client_payload.service || inputs.service }}
          curl -f -o "specs/${SERVICE}.yaml" \
            "${{ vars.SPEC_REGISTRY_URL }}/${SERVICE}/latest/openapi.yaml"
      - name: Generate TypeScript types
        run: |
          npm ci
          npm run codegen
      - name: Create PR if types changed
        uses: peter-evans/create-pull-request@v6
        with:
          branch: "chore/update-api-types-${{ github.run_id }}"
          title: "chore: update generated API types for ${{ github.event.client_payload.service || inputs.service }}"
          commit-message: "chore: regenerate API types from latest spec"
```

**Rules for generated code:**

- Generated files are committed to the repository and treated as source code.
- Never manually edit files in `src/generated/`. They are overwritten on regeneration.
- The `codegen:check` script runs in CI to ensure generated code is up to date.
- Breaking spec changes produce TypeScript compile errors, surfacing them in PRs.

### Rule 2: Client Structure with openapi-fetch

Create typed client instances per service using `openapi-fetch`. The client uses `createClient<paths>()` which provides autocomplete and type checking for every API call.

```typescript
// src/api/client.ts
import createClient from 'openapi-fetch';
import type { paths as ProjectPaths } from '@/generated/project-service/types';
import type { paths as BillingPaths } from '@/generated/billing-service/types';
import type { paths as UserPaths } from '@/generated/user-service/types';
import { authMiddleware } from '@/api/interceptors/auth';
import { traceMiddleware } from '@/api/interceptors/trace';
import { errorMiddleware } from '@/api/interceptors/error';

// Primary BFF client (most frontend code uses this)
const bffBaseUrl = import.meta.env.VITE_BFF_URL ?? '/api';

export const projectClient = createClient<ProjectPaths>({
  baseUrl: bffBaseUrl,
});

export const billingClient = createClient<BillingPaths>({
  baseUrl: bffBaseUrl,
});

export const userClient = createClient<UserPaths>({
  baseUrl: bffBaseUrl,
});

// Register middleware on all clients
[projectClient, billingClient, userClient].forEach((client) => {
  client.use(traceMiddleware);
  client.use(authMiddleware);
  client.use(errorMiddleware);
});
```

**Usage with full type safety:**

```typescript
// Every path, method, param, and response type is inferred from the OpenAPI spec
const { data, error } = await projectClient.GET('/api/v1/projects/{projectId}', {
  params: {
    path: { projectId: 'proj_abc123' },
  },
});
// data is typed as ProjectResponse | undefined
// error is typed as the error union from the spec
```

### Rule 3: Auth Token Injection via Middleware

openapi-fetch uses a middleware pattern (not Axios interceptors). Each middleware receives the request and can modify it before sending.

```typescript
// src/api/interceptors/auth.ts
import type { Middleware } from 'openapi-fetch';
import { getAccessToken, refreshAccessToken, isTokenExpired } from '@/auth/tokenManager';

export const authMiddleware: Middleware = {
  async onRequest({ request }) {
    // Skip auth for public endpoints
    if (request.headers.get('X-Public-Endpoint') === 'true') {
      request.headers.delete('X-Public-Endpoint');
      return request;
    }

    let token = getAccessToken();

    // Proactively refresh if token expires within 60 seconds
    if (token && isTokenExpired(token, 60)) {
      try {
        token = await refreshAccessToken();
      } catch {
        // Let the request proceed; 401 handler will redirect to login
      }
    }

    if (token) {
      request.headers.set('Authorization', `Bearer ${token}`);
    }

    return request;
  },
};
```

**Trace ID middleware:**

```typescript
// src/api/interceptors/trace.ts
import type { Middleware } from 'openapi-fetch';

export const traceMiddleware: Middleware = {
  async onRequest({ request }) {
    const traceId = crypto.randomUUID();
    request.headers.set('X-Trace-Id', traceId);
    request.headers.set('X-Request-Start', Date.now().toString());
    return request;
  },
};
```

### Rule 4: Error Type Unions and Mapping

Define a structured error model that maps Spring Boot RFC 7807 Problem Details to typed TypeScript errors.

```typescript
// src/api/errors.ts

/**
 * Canonical frontend error type. All API errors are normalized to this shape
 * before reaching React components or TanStack Query error handlers.
 */
export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly traceId: string,
    public readonly fieldErrors?: Record<string, string[]>,
    public readonly retryable: boolean = false,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get isValidationError(): boolean {
    return this.status === 400 && !!this.fieldErrors;
  }
  get isAuthError(): boolean {
    return this.status === 401;
  }
  get isForbidden(): boolean {
    return this.status === 403;
  }
  get isNotFound(): boolean {
    return this.status === 404;
  }
  get isRateLimited(): boolean {
    return this.status === 429;
  }
  get isConflict(): boolean {
    return this.status === 409;
  }
}

/**
 * RFC 7807 Problem Detail shape from Spring Boot 3.x
 */
interface ProblemDetail {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance?: string;
  errors?: Array<{ field: string; message: string; rejectedValue?: string }>;
  [key: string]: unknown;
}

function isProblemDetail(data: unknown): data is ProblemDetail {
  return (
    typeof data === 'object' &&
    data !== null &&
    'type' in data &&
    'title' in data &&
    'status' in data
  );
}

export function normalizeError(status: number, body: unknown, traceId: string): ApiError {
  if (isProblemDetail(body)) {
    const fieldErrors = body.errors?.reduce<Record<string, string[]>>((acc, e) => {
      (acc[e.field] ??= []).push(e.message);
      return acc;
    }, {});

    return new ApiError(
      status,
      body.type.split('/').pop() ?? 'UNKNOWN',
      body.detail ?? body.title,
      traceId,
      fieldErrors,
      status >= 500,
    );
  }

  return new ApiError(
    status,
    `HTTP_${status}`,
    status >= 500
      ? 'An internal error occurred. Please try again.'
      : 'An unexpected error occurred.',
    traceId,
    undefined,
    status >= 500,
  );
}
```

**Error middleware:**

```typescript
// src/api/interceptors/error.ts
import type { Middleware } from 'openapi-fetch';
import { normalizeError } from '@/api/errors';

export const errorMiddleware: Middleware = {
  async onResponse({ response }) {
    if (response.ok) return response;

    const traceId = response.headers.get('x-trace-id') ?? 'unknown';

    // Handle 401 globally: redirect to login
    if (response.status === 401) {
      window.dispatchEvent(new CustomEvent('auth:session-expired'));
    }

    // Handle 403: emit event for "access denied" toast
    if (response.status === 403) {
      window.dispatchEvent(new CustomEvent('auth:forbidden'));
    }

    const body = await response.json().catch(() => null);
    throw normalizeError(response.status, body, traceId);
  },
};
```

### Rule 5: Retry and Timeout Policies

Retry transient failures (network errors, 502/503/504) with exponential backoff. Never retry mutations unless explicitly marked as idempotent.

```typescript
// src/api/retry.ts
import type { Middleware } from 'openapi-fetch';

interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  retryableStatuses: Set<number>;
}

const DEFAULT_RETRY: RetryConfig = {
  maxRetries: 3,
  baseDelayMs: 300,
  maxDelayMs: 5_000,
  retryableStatuses: new Set([502, 503, 504]),
};

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

export function createRetryMiddleware(config: Partial<RetryConfig> = {}): Middleware {
  const cfg = { ...DEFAULT_RETRY, ...config };

  return {
    async onResponse({ request, response }) {
      if (response.ok) return response;
      if (!SAFE_METHODS.has(request.method)) return response;
      if (!cfg.retryableStatuses.has(response.status)) return response;

      let lastResponse = response;
      for (let attempt = 1; attempt <= cfg.maxRetries; attempt++) {
        const delay = Math.min(
          cfg.baseDelayMs * Math.pow(2, attempt - 1) + Math.random() * 100,
          cfg.maxDelayMs,
        );
        await new Promise((r) => setTimeout(r, delay));

        lastResponse = await fetch(request.clone());
        if (lastResponse.ok) return lastResponse;
        if (!cfg.retryableStatuses.has(lastResponse.status)) return lastResponse;
      }

      return lastResponse;
    },
  };
}
```

**Timeout configuration is set per-request or globally:**

```typescript
// Global timeout via AbortController
export function fetchWithTimeout(url: string, init: RequestInit, timeoutMs = 15_000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...init, signal: controller.signal }).finally(() => clearTimeout(timeout));
}
```

### Rule 6: MSW for Mocking in Tests

Use MSW (Mock Service Worker) to mock API calls in tests and Storybook. Handlers are organized per service and mirror the OpenAPI spec structure.

```typescript
// src/mocks/handlers/project-service.ts
import { http, HttpResponse } from 'msw';

export const projectHandlers = [
  // GET /api/v1/projects
  http.get('/api/v1/projects', ({ request }) => {
    const url = new URL(request.url);
    const page = Number(url.searchParams.get('page') ?? '0');
    const size = Number(url.searchParams.get('size') ?? '20');

    return HttpResponse.json({
      content: Array.from({ length: size }, (_, i) => ({
        id: `proj_${page * size + i}`,
        name: `Project ${page * size + i + 1}`,
        status: 'ACTIVE',
        createdAt: '2026-01-15T10:00:00Z',
        updatedAt: '2026-03-09T08:30:00Z',
      })),
      metadata: {
        page,
        size,
        totalElements: 48,
        totalPages: Math.ceil(48 / size),
        hasNext: page < Math.ceil(48 / size) - 1,
        hasPrevious: page > 0,
      },
    });
  }),

  // GET /api/v1/projects/:id
  http.get('/api/v1/projects/:projectId', ({ params }) => {
    return HttpResponse.json({
      id: params.projectId,
      name: 'Test Project',
      description: 'A mock project for testing',
      status: 'ACTIVE',
      createdAt: '2026-01-15T10:00:00Z',
    });
  }),

  // POST /api/v1/projects -- validation error example
  http.post('/api/v1/projects', async ({ request }) => {
    const body = await request.json() as Record<string, unknown>;

    if (!body.name || (body.name as string).length < 3) {
      return HttpResponse.json(
        {
          type: 'https://api.example.com/problems/validation-error',
          title: 'Validation Failed',
          status: 400,
          detail: 'One or more fields failed validation',
          errors: [
            { field: 'name', message: 'must be at least 3 characters' },
          ],
        },
        { status: 400 },
      );
    }

    return HttpResponse.json(
      { id: 'proj_new', name: body.name, status: 'ACTIVE' },
      { status: 201 },
    );
  }),
];
```

**Test setup:**

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { projectHandlers } from './handlers/project-service';
import { billingHandlers } from './handlers/billing-service';

export const server = setupServer(...projectHandlers, ...billingHandlers);

// src/setupTests.ts (Vitest / Jest)
import { server } from './mocks/server';
beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### Rule 7: Cache Invalidation with TanStack Query

Use TanStack Query for server state management. Define query key factories for consistent key management and predictable invalidation.

```typescript
// src/queries/keys.ts
export const projectKeys = {
  all: ['projects'] as const,
  lists: () => [...projectKeys.all, 'list'] as const,
  list: (filters: ProjectFilters) => [...projectKeys.lists(), filters] as const,
  details: () => [...projectKeys.all, 'detail'] as const,
  detail: (id: string) => [...projectKeys.details(), id] as const,
};
```

**Query hooks:**

```typescript
// src/queries/useProjects.ts
import { useQuery } from '@tanstack/react-query';
import { projectClient } from '@/api/client';
import { projectKeys } from '@/queries/keys';

export function useProjects(filters: ProjectFilters) {
  return useQuery({
    queryKey: projectKeys.list(filters),
    queryFn: async () => {
      const { data, error } = await projectClient.GET('/api/v1/projects', {
        params: { query: filters },
      });
      if (error) throw error;
      return data;
    },
    staleTime: 30_000, // 30 seconds
  });
}
```

**Mutation with cache invalidation:**

```typescript
// src/mutations/useCreateProject.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { projectClient } from '@/api/client';
import { projectKeys } from '@/queries/keys';
import type { ApiError } from '@/api/errors';

export function useCreateProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: CreateProjectInput) => {
      const { data, error } = await projectClient.POST('/api/v1/projects', {
        body: input,
      });
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      // Invalidate all project lists (any filter combination)
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}
```

**Cache invalidation patterns:**

| Mutation                | Invalidation Strategy                                   |
|-------------------------|---------------------------------------------------------|
| Create project          | Invalidate all project lists                            |
| Update project          | Invalidate specific detail + all lists                  |
| Delete project          | Remove from cache optimistically + invalidate lists     |
| Archive project         | Invalidate specific detail + all lists                  |
| Invite team member      | Invalidate project detail + members list                |
| Change billing plan     | Invalidate billing queries + entitlement queries        |

## Rules

1. **Spec-first.** Never hand-write API types. Generate them from the OpenAPI spec. If the spec is wrong, fix the spec.
2. **Single client instance per service.** All requests to a service go through its typed client. No raw `fetch()` calls scattered in components.
3. **Middleware for cross-cutting concerns.** Auth, tracing, and error normalization are handled in middleware, not in individual query hooks.
4. **Never retry mutations.** Only GET/HEAD/OPTIONS are retried by default. Mutations require explicit idempotency keys to opt in.
5. **Query keys are structured.** Use the key factory pattern. Never construct query keys as ad-hoc string arrays in components.
6. **MSW mirrors the spec.** Mock handlers must return the same shape as the real API. Use the generated types to type-check handler responses.
7. **Errors are typed.** Every catch block and error boundary should expect `ApiError`, not `unknown` or raw `AxiosError`.
8. **staleTime is intentional.** Every query hook must set `staleTime` explicitly based on the data's expected freshness. Do not rely on the default (0).

## Examples

### Example 1: Form with validation error mapping

```typescript
function CreateProjectForm() {
  const form = useForm<CreateProjectInput>({ resolver: zodResolver(schema) });
  const createProject = useCreateProject();

  const onSubmit = form.handleSubmit(async (data) => {
    try {
      await createProject.mutateAsync(data);
      toast.success('Project created');
    } catch (err) {
      if (err instanceof ApiError && err.isValidationError && err.fieldErrors) {
        Object.entries(err.fieldErrors).forEach(([field, messages]) => {
          form.setError(field as keyof CreateProjectInput, {
            type: 'server',
            message: messages[0],
          });
        });
      }
    }
  });

  return <form onSubmit={onSubmit}>{/* ... */}</form>;
}
```

### Example 2: Optimistic delete with rollback

```typescript
export function useDeleteProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (projectId: string) => {
      const { error } = await projectClient.DELETE('/api/v1/projects/{projectId}', {
        params: { path: { projectId } },
      });
      if (error) throw error;
    },
    onMutate: async (projectId) => {
      await queryClient.cancelQueries({ queryKey: projectKeys.lists() });
      const previous = queryClient.getQueriesData({ queryKey: projectKeys.lists() });
      // Optimistically remove from all cached lists
      queryClient.setQueriesData(
        { queryKey: projectKeys.lists() },
        (old: any) => ({
          ...old,
          content: old.content.filter((p: any) => p.id !== projectId),
        }),
      );
      return { previous };
    },
    onError: (_err, _id, context) => {
      // Rollback on failure
      context?.previous.forEach(([key, data]) => {
        queryClient.setQueryData(key, data);
      });
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: projectKeys.lists() });
    },
  });
}
```

### Example 3: Environment-specific client config

```typescript
// src/api/config.ts
interface ApiConfig {
  bffBaseUrl: string;
  timeout: number;
  retryMaxAttempts: number;
}

const configs: Record<string, ApiConfig> = {
  development: {
    bffBaseUrl: 'http://localhost:3001/api',
    timeout: 30_000,
    retryMaxAttempts: 1,
  },
  staging: {
    bffBaseUrl: 'https://staging-api.example.com',
    timeout: 15_000,
    retryMaxAttempts: 2,
  },
  production: {
    bffBaseUrl: 'https://api.example.com',
    timeout: 10_000,
    retryMaxAttempts: 3,
  },
};

export function getApiConfig(): ApiConfig {
  return configs[import.meta.env.MODE] ?? configs.development;
}
```
