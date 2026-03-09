# API Documentation Style Guide

## Writing Style

### General Principles

1. **Use active voice**: "The server returns a 200 response" not "A 200 response is returned by the server"
2. **Be direct**: "Use cursor pagination for large datasets" not "It is recommended that cursor pagination be used"
3. **Address the developer as "you"**: "You can filter results by status" not "The user can filter results"
4. **Use present tense**: "This endpoint creates a project" not "This endpoint will create a project"
5. **Keep sentences under 25 words**: Break long explanations into multiple sentences
6. **Lead with the action**: "To create a project, send a POST request to `/api/v1/projects`"

### Tone

- Professional but not formal
- Concise but not cryptic
- Helpful but not condescending
- Technical but not academic

### Formatting Rules

| Element | Convention | Example |
|---------|-----------|---------|
| Endpoint paths | Code font, full path | `POST /api/v1/projects` |
| Parameter names | Code font | `pageSize` |
| JSON field names | Code font | `"createdAt"` |
| HTTP methods | ALL CAPS, code font | `GET`, `POST`, `PUT`, `DELETE` |
| Status codes | Number + name | `200 OK`, `404 Not Found` |
| Header names | Code font, exact case | `Authorization`, `X-RateLimit-Limit` |
| Boolean values | Code font | `true`, `false` |
| Enum values | Code font, exact value | `"active"`, `"pending"` |

## Example Value Conventions

### Never Use Placeholder Values

Bad:
```json
{
  "name": "string",
  "email": "string",
  "age": 0,
  "createdAt": "string"
}
```

Good:
```json
{
  "name": "Elara Meadowcroft",
  "email": "elara@example.com",
  "age": 34,
  "createdAt": "2026-03-09T14:30:00Z"
}
```

### Standard Example Values

Use these consistent example values across all documentation:

| Field Type | Example Value | Notes |
|-----------|---------------|-------|
| User name | `"Elara Meadowcroft"` | Avoid generic "John Doe" |
| Email | `"elara@example.com"` | Always use `example.com` domain |
| Company | `"Meridian Labs"` | Fictional company name |
| UUID | `"d290f1ee-6c54-4b01-90e6-d701748f0851"` | Valid UUID v4 format |
| Date (ISO 8601) | `"2026-03-09T14:30:00Z"` | Always include timezone |
| Date (date only) | `"2026-03-09"` | ISO 8601 date format |
| URL | `"https://api.meridian-labs.com/v1/projects"` | Use fictional domain |
| Phone | `"+1-555-0142"` | Use 555 range |
| Currency | `2999` | Amounts in cents (integer) |
| IP address | `"198.51.100.42"` | Use documentation range (RFC 5737) |
| API key | `"sk_live_abc123def456ghi789"` | Clearly fake, prefixed |
| Slug | `"my-first-project"` | Lowercase kebab-case |
| Pagination cursor | `"eyJpZCI6MTAwfQ=="` | Base64-encoded, realistic |

### Example Response Patterns

#### Successful Response (Single Resource)

```json
{
  "id": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "name": "Production API Gateway",
  "slug": "production-api-gateway",
  "description": "Main API gateway for production environment",
  "status": "active",
  "environment": "production",
  "createdAt": "2026-03-09T14:30:00Z",
  "updatedAt": "2026-03-09T14:30:00Z",
  "createdBy": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "Elara Meadowcroft",
    "email": "elara@example.com"
  }
}
```

#### Successful Response (Paginated List)

```json
{
  "data": [
    {
      "id": "d290f1ee-6c54-4b01-90e6-d701748f0851",
      "name": "Production API Gateway",
      "status": "active"
    },
    {
      "id": "e381g2ff-7d65-5c12-01f7-e812859g1962",
      "name": "Staging API Gateway",
      "status": "active"
    }
  ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalElements": 47,
    "totalPages": 3,
    "hasNext": true,
    "hasPrevious": false
  }
}
```

#### Error Response (RFC 7807)

```json
{
  "type": "https://api.meridian-labs.com/problems/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "The request body contains 2 validation errors.",
  "instance": "/api/v1/projects",
  "errors": [
    {
      "field": "name",
      "message": "Project name must be between 3 and 100 characters",
      "rejectedValue": "ab"
    },
    {
      "field": "environment",
      "message": "Environment must be one of: development, staging, production",
      "rejectedValue": "test"
    }
  ]
}
```

## Error Code Catalog Format

Every API error type must be documented in the error catalog. Use this format:

### Catalog Entry Template

```markdown
### ERR-PROJECT-001: Project Not Found

**HTTP Status**: 404 Not Found
**Type URI**: `https://api.meridian-labs.com/problems/project-not-found`

**Description**: The requested project does not exist or you do not have access to it.

**Common Causes**:
- The project ID is incorrect or has a typo
- The project was deleted
- Your API key does not have access to this project

**Example Response**:
```json
{
  "type": "https://api.meridian-labs.com/problems/project-not-found",
  "title": "Project Not Found",
  "status": 404,
  "detail": "No project found with ID d290f1ee-6c54-4b01-90e6-d701748f0851",
  "instance": "/api/v1/projects/d290f1ee-6c54-4b01-90e6-d701748f0851"
}
```

**Resolution**:
- Verify the project ID in your request
- List your projects with `GET /api/v1/projects` to find valid IDs
- Contact support if you believe this is an access issue
```

### Error Code Naming Convention

Format: `ERR-<DOMAIN>-<NUMBER>`

| Domain | Prefix | Example |
|--------|--------|---------|
| Authentication | `ERR-AUTH` | `ERR-AUTH-001: Invalid Credentials` |
| Projects | `ERR-PROJECT` | `ERR-PROJECT-001: Project Not Found` |
| Deployments | `ERR-DEPLOY` | `ERR-DEPLOY-001: Deployment Failed` |
| Billing | `ERR-BILLING` | `ERR-BILLING-001: Payment Failed` |
| Rate Limiting | `ERR-RATE` | `ERR-RATE-001: Rate Limit Exceeded` |
| Validation | `ERR-VALIDATION` | `ERR-VALIDATION-001: Invalid Request Body` |
| Integration | `ERR-INTEGRATION` | `ERR-INTEGRATION-001: Provider Unreachable` |
| General | `ERR-GENERAL` | `ERR-GENERAL-001: Internal Server Error` |

### Common Error Codes

| Code | Status | Title | When |
|------|--------|-------|------|
| `ERR-AUTH-001` | 401 | Invalid Credentials | Wrong email/password |
| `ERR-AUTH-002` | 401 | Token Expired | JWT expired |
| `ERR-AUTH-003` | 403 | Insufficient Permissions | Missing required role |
| `ERR-AUTH-004` | 403 | Feature Not Available | Tier does not include feature |
| `ERR-VALIDATION-001` | 422 | Validation Error | Request body fails validation |
| `ERR-VALIDATION-002` | 400 | Malformed Request | Unparseable JSON |
| `ERR-RATE-001` | 429 | Rate Limit Exceeded | Too many requests |
| `ERR-PROJECT-001` | 404 | Project Not Found | Invalid project ID |
| `ERR-PROJECT-002` | 409 | Project Name Conflict | Duplicate project name |
| `ERR-DEPLOY-001` | 422 | Deployment Failed | Build/deploy error |
| `ERR-BILLING-001` | 402 | Payment Required | Subscription expired |
| `ERR-GENERAL-001` | 500 | Internal Server Error | Unhandled server error |

## Changelog Entry Format

Every API change must be documented in the changelog. Use this format:

### Changelog Entry Template

```markdown
## 2026-03-09 -- v1.12.0

### Added
- `POST /api/v1/projects/{id}/deploy` -- Deploy a project to a specific environment. [Docs](/api/v1/projects#deploy)
- `webhooks` query parameter on `GET /api/v1/projects` to filter by webhook status.

### Changed
- `GET /api/v1/projects` now returns `environment` field in the response body.
- Rate limit for `POST /api/v1/deployments` increased from 5/min to 10/min for Pro tier.

### Deprecated
- `GET /api/v1/projects/{id}/status` is deprecated. Use `GET /api/v1/projects/{id}` instead. Sunset date: 2026-09-09.

### Fixed
- `PATCH /api/v1/projects/{id}` now correctly validates the `slug` field format.

### Security
- API keys are no longer returned in `GET /api/v1/api-keys` list responses. Use `POST /api/v1/api-keys` to view the key at creation time only.

### Breaking (v2 only)
- `GET /api/v2/projects` pagination changed from offset to cursor-based. See [migration guide](/docs/migration/v1-to-v2).
```

### Changelog Rules

1. **Date format**: ISO 8601 (`YYYY-MM-DD`)
2. **Version format**: SemVer (`vMAJOR.MINOR.PATCH`)
3. **Categories**: Added, Changed, Deprecated, Fixed, Security, Breaking
4. **Breaking changes**: Only in major version bumps, always link to migration guide
5. **Deprecation notice**: Must include sunset date (minimum 6 months)
6. **Each entry links to documentation**: Include `[Docs](/path)` link

## SDK Code Sample Template

Every endpoint should include code samples in at least these languages:

### Template Structure

````markdown
### Create a Project

Creates a new project in your workspace.

**Endpoint**: `POST /api/v1/projects`

#### cURL

```bash
curl -X POST https://api.meridian-labs.com/v1/projects \
  -H "Authorization: Bearer sk_live_abc123def456ghi789" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production API Gateway",
    "environment": "production",
    "description": "Main API gateway"
  }'
```

#### TypeScript (openapi-fetch)

```typescript
import { createClient } from 'openapi-fetch';
import type { paths } from './api-types';

const client = createClient<paths>({
  baseUrl: 'https://api.meridian-labs.com/v1',
  headers: {
    Authorization: 'Bearer sk_live_abc123def456ghi789',
  },
});

const { data, error } = await client.POST('/projects', {
  body: {
    name: 'Production API Gateway',
    environment: 'production',
    description: 'Main API gateway',
  },
});

if (error) {
  console.error('Failed to create project:', error.detail);
} else {
  console.log('Created project:', data.id);
}
```

#### Java (Spring WebClient)

```java
var project = webClient.post()
    .uri("/api/v1/projects")
    .header("Authorization", "Bearer sk_live_abc123def456ghi789")
    .contentType(MediaType.APPLICATION_JSON)
    .bodyValue(new CreateProjectRequest(
        "Production API Gateway",
        "production",
        "Main API gateway"
    ))
    .retrieve()
    .bodyToMono(ProjectResponse.class)
    .block();

System.out.println("Created project: " + project.getId());
```

#### Python (requests)

```python
import requests

response = requests.post(
    "https://api.meridian-labs.com/v1/projects",
    headers={
        "Authorization": "Bearer sk_live_abc123def456ghi789",
        "Content-Type": "application/json",
    },
    json={
        "name": "Production API Gateway",
        "environment": "production",
        "description": "Main API gateway",
    },
)

project = response.json()
print(f"Created project: {project['id']}")
```
````

### Code Sample Rules

1. **Always runnable**: Every code sample must be copy-paste executable
2. **Include error handling**: Show at minimum how to check for errors
3. **Use realistic values**: Never use `"string"` or `0` as example values
4. **Include all required headers**: Authorization, Content-Type, etc.
5. **Show the response**: Include expected response for successful calls
6. **Comment sparingly**: Only add comments for non-obvious behavior
7. **Use latest SDK versions**: Pin to a specific version in import/dependency
8. **Consistent ordering**: cURL first, then TypeScript, Java, Python

## OpenAPI Description Conventions

### Operation Summaries

- Max 60 characters
- Start with a verb
- No trailing period

Good: `Create a new project`
Bad: `This endpoint is used for creating a new project.`

### Operation Descriptions

- 1-3 sentences
- Mention key constraints (auth required, rate limits, tier restrictions)
- Link to related endpoints

```yaml
description: |
  Creates a new project in the authenticated user's workspace.
  Requires the `projects:write` scope. Limited to 10 requests per minute
  on the Free tier. See [Rate Limits](/docs/rate-limits) for details.
```

### Parameter Descriptions

- State what it does, not what it is
- Include valid range or format
- Show default value

Good: `Filters projects by status. Valid values: active, archived, deleted. Default: active.`
Bad: `The status parameter.`

### Schema Descriptions

- Describe the business meaning, not the data type
- Include constraints inline

```yaml
properties:
  name:
    type: string
    description: "Human-readable project name. Must be unique within the workspace."
    minLength: 3
    maxLength: 100
    example: "Production API Gateway"
  slug:
    type: string
    description: "URL-safe identifier, auto-generated from name if not provided."
    pattern: "^[a-z0-9]+(?:-[a-z0-9]+)*$"
    example: "production-api-gateway"
```
