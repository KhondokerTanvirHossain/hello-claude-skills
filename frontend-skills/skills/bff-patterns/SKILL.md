---
name: bff-patterns
description: Backend-for-Frontend layer conventions for React + TypeScript frontends communicating with Spring Boot microservices, including API aggregation, response shaping, and error normalization
version: 1.0.0
tags:
  - bff
  - api-aggregation
  - react
  - typescript
  - spring-boot
  - microservices
  - clean-architecture
globs:
  - "src/bff/**/*.ts"
  - "src/api/**/*.ts"
  - "src/gateway/**/*.ts"
  - "src/adapters/**/*.ts"
---

# BFF Patterns

## Purpose

Define conventions for the Backend-for-Frontend (BFF) layer that sits between React + TypeScript frontends and Spring Boot microservices. The BFF is responsible for aggregating data from multiple microservices, shaping responses for specific frontend views, normalizing errors into a consistent contract, and managing cross-cutting concerns such as authentication forwarding and caching. This skill ensures the BFF layer remains thin, purpose-built for each frontend experience, and avoids becoming a general-purpose API gateway.

## When to Use

- Building a new frontend view that requires data from two or more microservices
- Creating an API endpoint that aggregates or transforms backend responses for a specific UI component
- Implementing error normalization across heterogeneous microservice error formats
- Setting up authentication token forwarding from the frontend through the BFF to downstream services
- Designing cache strategies for BFF responses to reduce latency and backend load
- Generating TypeScript types from OpenAPI specs exposed by downstream Spring Boot services
- Refactoring a frontend that currently calls multiple microservices directly into a BFF-mediated pattern

## Architecture Overview

```
React App (TypeScript)
    |
    v
BFF Layer (Node.js / Next.js API routes / Express)
    |
    +---> Microservice A (Spring Boot, Java 21)
    +---> Microservice B (Spring Boot, Java 21)
    +---> Microservice C (Spring Boot, Java 21)
    |
PostgreSQL (each service owns its schema)
```

The BFF is **view-specific**, not service-specific. Each BFF endpoint is designed for a particular frontend screen or component composition, not as a 1:1 proxy of a backend service.

## Workflow and Rules

### Rule 1: One BFF Per Frontend Experience

Each distinct frontend application (web dashboard, mobile web, admin panel) gets its own BFF layer. Do not share a single BFF across multiple frontend experiences with different data needs.

```
src/
  bff/
    dashboard/          # BFF for main dashboard SPA
      routes/
      aggregators/
      transformers/
    admin/              # BFF for admin panel
      routes/
      aggregators/
      transformers/
    shared/             # Shared utilities only (auth, logging, error formatting)
      middleware/
      types/
      utils/
```

### Rule 2: API Aggregation Patterns

When a frontend view requires data from multiple microservices, aggregate at the BFF layer. Never have the React frontend make parallel calls to multiple microservices directly.

**Parallel Aggregation** -- Use when backend calls are independent:

```typescript
// src/bff/dashboard/aggregators/projectOverview.aggregator.ts
import { ProjectService } from '@/bff/shared/clients/projectService';
import { TeamService } from '@/bff/shared/clients/teamService';
import { MetricsService } from '@/bff/shared/clients/metricsService';

interface ProjectOverviewResponse {
  project: ProjectSummary;
  team: TeamMember[];
  metrics: ProjectMetrics;
}

export async function aggregateProjectOverview(
  projectId: string,
  authToken: string
): Promise<ProjectOverviewResponse> {
  const [project, team, metrics] = await Promise.all([
    ProjectService.getProject(projectId, authToken),
    TeamService.getTeamByProject(projectId, authToken),
    MetricsService.getProjectMetrics(projectId, authToken),
  ]);

  return {
    project: toProjectSummary(project),
    team: team.map(toTeamMember),
    metrics: toProjectMetrics(metrics),
  };
}
```

**Sequential Aggregation** -- Use when one call depends on the result of another:

```typescript
// src/bff/dashboard/aggregators/billingOverview.aggregator.ts
export async function aggregateBillingOverview(
  orgId: string,
  authToken: string
): Promise<BillingOverviewResponse> {
  // Step 1: Get subscription (needed to determine plan tier)
  const subscription = await BillingService.getSubscription(orgId, authToken);

  // Step 2: Use plan tier to fetch appropriate usage data and limits
  const [usage, invoices] = await Promise.all([
    UsageService.getUsageByPlan(orgId, subscription.planId, authToken),
    BillingService.getRecentInvoices(orgId, { limit: 5 }, authToken),
  ]);

  return {
    subscription: toSubscriptionSummary(subscription),
    usage: toUsageSummary(usage, subscription.limits),
    invoices: invoices.map(toInvoiceSummary),
  };
}
```

**Partial Failure Handling** -- Use when some data is optional and the view can render without it:

```typescript
// src/bff/dashboard/aggregators/userDashboard.aggregator.ts
export async function aggregateUserDashboard(
  userId: string,
  authToken: string
): Promise<UserDashboardResponse> {
  const userProfilePromise = UserService.getProfile(userId, authToken);
  const notificationsPromise = NotificationService.getRecent(userId, authToken);
  const activityPromise = ActivityService.getRecentActivity(userId, authToken);

  const userProfile = await userProfilePromise; // Required -- let it throw

  // Optional sections: use settledResult pattern
  const [notificationsResult, activityResult] = await Promise.allSettled([
    notificationsPromise,
    activityPromise,
  ]);

  return {
    profile: toProfileView(userProfile),
    notifications:
      notificationsResult.status === 'fulfilled'
        ? notificationsResult.value.map(toNotificationItem)
        : { error: 'unavailable', items: [] },
    recentActivity:
      activityResult.status === 'fulfilled'
        ? activityResult.value.map(toActivityItem)
        : { error: 'unavailable', items: [] },
  };
}
```

### Rule 3: Response Shaping and Transformation

The BFF transforms backend domain models into view-optimized shapes. Transformers live in a dedicated directory and are pure functions.

```typescript
// src/bff/shared/transformers/project.transformer.ts

// Backend domain model (from Spring Boot service)
interface ProjectEntity {
  id: string;
  name: string;
  description: string | null;
  created_at: string;          // ISO 8601
  updated_at: string;          // ISO 8601
  owner_user_id: string;
  organization_id: string;
  status: 'ACTIVE' | 'ARCHIVED' | 'DELETED';
  settings_json: string;
}

// Frontend view model (sent to React app)
interface ProjectSummary {
  id: string;
  name: string;
  description: string;
  createdAt: Date;
  isActive: boolean;
  ownerName: string;           // Resolved from user service
}

export function toProjectSummary(
  entity: ProjectEntity,
  ownerName: string
): ProjectSummary {
  return {
    id: entity.id,
    name: entity.name,
    description: entity.description ?? '',
    createdAt: new Date(entity.created_at),
    isActive: entity.status === 'ACTIVE',
    ownerName,
  };
}
```

**Transformation rules:**

- Convert `snake_case` backend fields to `camelCase` for the frontend
- Resolve IDs into display values at the BFF layer (e.g., `owner_user_id` becomes `ownerName`)
- Replace `null` with sensible defaults for the UI
- Flatten nested structures when the frontend only needs a subset
- Strip sensitive fields (internal IDs, audit columns) before sending to the client
- Convert ISO date strings to `Date` objects or formatted strings as the view requires

### Rule 4: Error Normalization Contract

All errors returned from the BFF to the React frontend must conform to a single `ApiError` shape, regardless of which downstream service produced the error.

```typescript
// src/bff/shared/types/apiError.ts
export interface ApiError {
  status: number;
  code: string;                // Machine-readable: 'PROJECT_NOT_FOUND', 'RATE_LIMIT_EXCEEDED'
  message: string;             // Human-readable, safe to display in UI
  details?: Record<string, string[]>; // Field-level validation errors
  traceId: string;             // Correlation ID for debugging
  timestamp: string;           // ISO 8601
}

// src/bff/shared/middleware/errorNormalizer.ts
import { AxiosError } from 'axios';
import { v4 as uuidv4 } from 'uuid';

export function normalizeError(error: unknown, traceId?: string): ApiError {
  const resolvedTraceId = traceId ?? uuidv4();

  if (error instanceof AxiosError && error.response) {
    const { status, data } = error.response;

    // Spring Boot default error body
    if (data?.error && data?.message) {
      return {
        status,
        code: mapSpringErrorToCode(data.error, data.status),
        message: sanitizeMessage(data.message),
        details: data.fieldErrors ?? undefined,
        traceId: resolvedTraceId,
        timestamp: new Date().toISOString(),
      };
    }

    // Custom Spring Boot problem+json response
    if (data?.type && data?.title) {
      return {
        status,
        code: data.type.split('/').pop() ?? 'UNKNOWN_ERROR',
        message: data.title,
        details: data.violations ?? undefined,
        traceId: resolvedTraceId,
        timestamp: new Date().toISOString(),
      };
    }
  }

  // Network or timeout errors
  if (error instanceof AxiosError && error.code === 'ECONNABORTED') {
    return {
      status: 504,
      code: 'GATEWAY_TIMEOUT',
      message: 'The service did not respond in time. Please try again.',
      traceId: resolvedTraceId,
      timestamp: new Date().toISOString(),
    };
  }

  // Fallback for unexpected errors
  return {
    status: 500,
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred.',
    traceId: resolvedTraceId,
    timestamp: new Date().toISOString(),
  };
}
```

### Rule 5: Authentication Token Forwarding

The BFF receives the JWT or session token from the React frontend and forwards it to downstream microservices. The BFF never stores tokens and never inspects token claims beyond what is needed for routing.

```typescript
// src/bff/shared/middleware/authForwarding.ts
import { Request, Response, NextFunction } from 'express';

export function forwardAuth(req: Request, _res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return next(new UnauthorizedError('Missing or invalid authorization header'));
  }

  // Attach to request context for downstream clients to pick up
  req.context = {
    ...req.context,
    authToken: authHeader,
    traceId: req.headers['x-trace-id'] as string ?? uuidv4(),
  };

  next();
}

// All downstream service clients accept authToken explicitly
// src/bff/shared/clients/baseClient.ts
import axios, { AxiosInstance } from 'axios';

export function createServiceClient(baseURL: string, authToken: string): AxiosInstance {
  return axios.create({
    baseURL,
    timeout: 5000,
    headers: {
      Authorization: authToken,
      'Content-Type': 'application/json',
    },
  });
}
```

### Rule 6: Caching Strategies

Apply caching at the BFF layer to reduce downstream service calls. Use short TTLs for user-specific data and longer TTLs for shared reference data.

| Data Type | Cache Location | TTL | Invalidation |
|-----------|---------------|-----|-------------|
| User profile | In-memory (per-request) | Request-scoped | N/A |
| Org settings | Redis | 5 minutes | Event-driven via webhook |
| Feature flags | In-memory | 30 seconds | Polling |
| Plan/pricing | Redis | 1 hour | Manual purge on deploy |
| Static reference data | CDN / Redis | 24 hours | Deploy-triggered |

```typescript
// src/bff/shared/cache/cacheLayer.ts
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export async function cached<T>(
  key: string,
  ttlSeconds: number,
  fetcher: () => Promise<T>
): Promise<T> {
  const existing = await redis.get(key);
  if (existing) {
    return JSON.parse(existing) as T;
  }

  const fresh = await fetcher();
  await redis.setex(key, ttlSeconds, JSON.stringify(fresh));
  return fresh;
}

// Usage in aggregator
const orgSettings = await cached(
  `org:${orgId}:settings`,
  300, // 5 minutes
  () => OrgService.getSettings(orgId, authToken)
);
```

### Rule 7: TypeScript Type Generation from OpenAPI Specs

Each Spring Boot microservice publishes an OpenAPI 3.x spec. The BFF project generates TypeScript types from these specs at build time to ensure type safety across the boundary.

```bash
# In the BFF project's package.json scripts
{
  "scripts": {
    "generate:types": "npm-run-all generate:types:*",
    "generate:types:project-service": "openapi-typescript http://localhost:8081/v3/api-docs -o src/bff/shared/generated/projectService.types.ts",
    "generate:types:billing-service": "openapi-typescript http://localhost:8082/v3/api-docs -o src/bff/shared/generated/billingService.types.ts",
    "generate:types:user-service": "openapi-typescript http://localhost:8083/v3/api-docs -o src/bff/shared/generated/userService.types.ts",
    "generate:types:ci": "npm-run-all generate:types:ci:*",
    "generate:types:ci:project-service": "openapi-typescript specs/project-service.yaml -o src/bff/shared/generated/projectService.types.ts",
    "generate:types:ci:billing-service": "openapi-typescript specs/billing-service.yaml -o src/bff/shared/generated/billingService.types.ts"
  }
}
```

```yaml
# GitHub Actions step for CI type generation
- name: Generate BFF TypeScript types
  run: |
    # Download latest specs from service artifact registry
    for service in project-service billing-service user-service; do
      curl -o specs/${service}.yaml \
        "${ARTIFACT_REGISTRY_URL}/api-specs/${service}/latest/openapi.yaml"
    done
    npm run generate:types:ci
```

**Generated types are committed to the repository** so that:
- Builds do not depend on running microservices
- Type drift is caught in pull request diffs
- Downstream type changes trigger compile errors in the BFF code

## Examples

### Example 1: Creating a new BFF endpoint for a dashboard widget

```typescript
// 1. Define the view model
// src/bff/dashboard/types/teamActivity.types.ts
export interface TeamActivityWidget {
  summary: {
    totalCommits: number;
    activeMemberCount: number;
    topContributor: { name: string; avatarUrl: string };
  };
  recentItems: Array<{
    id: string;
    memberName: string;
    action: string;
    target: string;
    occurredAt: string; // relative time string: "2 hours ago"
  }>;
}

// 2. Create the aggregator
// src/bff/dashboard/aggregators/teamActivity.aggregator.ts
export async function aggregateTeamActivity(
  teamId: string,
  authToken: string
): Promise<TeamActivityWidget> {
  const [stats, activity, members] = await Promise.all([
    GitService.getTeamStats(teamId, authToken),
    ActivityService.getTeamActivity(teamId, { limit: 10 }, authToken),
    TeamService.getMembers(teamId, authToken),
  ]);

  const memberMap = new Map(members.map(m => [m.id, m]));

  return {
    summary: {
      totalCommits: stats.commitCount,
      activeMemberCount: stats.activeContributors,
      topContributor: {
        name: memberMap.get(stats.topContributorId)?.displayName ?? 'Unknown',
        avatarUrl: memberMap.get(stats.topContributorId)?.avatarUrl ?? '',
      },
    },
    recentItems: activity.map(item => ({
      id: item.id,
      memberName: memberMap.get(item.userId)?.displayName ?? 'Unknown',
      action: humanizeAction(item.actionType),
      target: item.targetName,
      occurredAt: formatRelativeTime(item.timestamp),
    })),
  };
}

// 3. Wire up the route
// src/bff/dashboard/routes/teamActivity.route.ts
router.get('/teams/:teamId/activity-widget', forwardAuth, async (req, res) => {
  try {
    const result = await aggregateTeamActivity(
      req.params.teamId,
      req.context.authToken
    );
    res.json(result);
  } catch (error) {
    const apiError = normalizeError(error, req.context.traceId);
    res.status(apiError.status).json(apiError);
  }
});
```

### Example 2: Handling a downstream service outage gracefully

```typescript
// src/bff/dashboard/routes/homepage.route.ts
router.get('/homepage', forwardAuth, async (req, res) => {
  const { authToken, traceId } = req.context;
  const userId = extractUserId(authToken);

  // Critical data: must succeed
  const profile = await UserService.getProfile(userId, authToken);

  // Optional data: degrade gracefully
  const [announcementsResult, tipsResult] = await Promise.allSettled([
    ContentService.getAnnouncements(authToken),
    RecommendationService.getTips(userId, authToken),
  ]);

  res.json({
    profile: toProfileView(profile),
    announcements:
      announcementsResult.status === 'fulfilled'
        ? announcementsResult.value
        : [],
    tips:
      tipsResult.status === 'fulfilled'
        ? tipsResult.value
        : [{ fallback: true, message: 'Check back later for personalized tips.' }],
    _meta: {
      degraded: [
        announcementsResult.status === 'rejected' ? 'announcements' : null,
        tipsResult.status === 'rejected' ? 'tips' : null,
      ].filter(Boolean),
      traceId,
    },
  });
});
```

### Example 3: BFF endpoint with Redis caching and cache invalidation

```typescript
// src/bff/dashboard/routes/orgPlan.route.ts
router.get('/org/:orgId/plan-summary', forwardAuth, async (req, res) => {
  const { orgId } = req.params;
  const { authToken, traceId } = req.context;

  const planSummary = await cached(
    `bff:plan-summary:${orgId}`,
    300,
    () => aggregatePlanSummary(orgId, authToken)
  );

  res.json(planSummary);
});

// Webhook handler for cache invalidation when plan changes
router.post('/webhooks/plan-changed', verifyWebhookSignature, async (req, res) => {
  const { organizationId } = req.body;
  await redis.del(`bff:plan-summary:${organizationId}`);
  res.status(204).send();
});
```
