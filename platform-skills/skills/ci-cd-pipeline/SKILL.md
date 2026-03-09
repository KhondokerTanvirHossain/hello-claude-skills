---
name: ci-cd-pipeline
description: GitHub Actions CI/CD pipeline conventions for a monorepo or multi-repo setup with React frontend and Spring Boot microservices, including build, test, Docker image publish, and deployment stages
version: 1.0.0
tags:
  - ci-cd
  - github-actions
  - docker
  - deployment
  - devops
globs:
  - ".github/workflows/*.yml"
  - ".github/workflows/*.yaml"
  - "**/Dockerfile"
  - "**/docker-compose*.yml"
  - "**/build.gradle.kts"
  - "**/package.json"
---

# CI/CD Pipeline Conventions

## Purpose

Define the standard GitHub Actions CI/CD pipeline structure for a developer productivity SaaS platform built with React + TypeScript frontend, Java 21 + Spring Boot 3.x microservices (Gradle), PostgreSQL, and Docker. This skill ensures consistent, reproducible, and fast build-test-deploy cycles across all services in the monorepo.

## When to Use

- Creating or modifying GitHub Actions workflow files
- Adding a new microservice to the CI/CD pipeline
- Configuring Docker image builds and registry pushes
- Setting up environment-based deployment stages (dev, staging, prod)
- Troubleshooting build failures or slow pipelines
- Implementing cache strategies for Gradle or npm
- Defining artifact retention and promotion flows

## Workflow File Structure

Organize workflows by concern, not by service. Place all workflow files in `.github/workflows/`.

```
.github/
  workflows/
    ci-backend.yml          # Build, test, lint all Spring Boot services
    ci-frontend.yml         # Build, test, lint React frontend
    cd-deploy.yml           # Deploy to target environment
    docker-publish.yml      # Build and push Docker images
    pr-checks.yml           # Lightweight checks on pull requests
    release.yml             # Tag-based release promotion
    scheduled-security.yml  # Weekly dependency and image scanning
```

### Naming Convention

- Prefix with `ci-` for continuous integration workflows
- Prefix with `cd-` for continuous deployment workflows
- Use `pr-` for pull request specific checks
- Use `scheduled-` for cron-triggered workflows

## Rules

### 1. Path-Based Triggering

Every workflow must use path filters to avoid unnecessary runs. Never trigger all workflows on every push.

```yaml
on:
  push:
    branches: [main, release/**]
    paths:
      - "services/user-service/**"
      - "libs/shared-kernel/**"
      - ".github/workflows/ci-backend.yml"
  pull_request:
    branches: [main]
    paths:
      - "services/user-service/**"
      - "libs/shared-kernel/**"
```

Shared libraries (e.g., `libs/shared-kernel`) must trigger builds for all dependent services.

### 2. Matrix Builds for Microservices

Use a matrix strategy to build all backend services in parallel. Define the service list as a matrix parameter, not as separate jobs.

```yaml
jobs:
  build-backend:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        service:
          - user-service
          - billing-service
          - notification-service
          - analytics-service
          - api-gateway-bff
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 21
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Build and test ${{ matrix.service }}
        working-directory: services/${{ matrix.service }}
        run: |
          ./gradlew build -x spotlessCheck
          ./gradlew jacocoTestReport

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.service }}
          path: services/${{ matrix.service }}/build/reports/tests/
          retention-days: 7

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.service }}
          path: services/${{ matrix.service }}/build/reports/jacoco/
          retention-days: 7
```

Set `fail-fast: false` so a failure in one service does not cancel builds for other services.

### 3. Frontend Build and Test

The React + TypeScript frontend gets its own workflow with dedicated caching.

```yaml
jobs:
  build-frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Type check
        run: npx tsc --noEmit

      - name: Lint
        run: npm run lint

      - name: Unit tests
        run: npm run test -- --coverage --watchAll=false

      - name: Build production bundle
        run: npm run build
        env:
          REACT_APP_API_BASE_URL: ${{ vars.API_BASE_URL }}

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: frontend-build
          path: frontend/build/
          retention-days: 3
```

### 4. Docker Image Tagging Strategy

Use a deterministic, traceable tagging convention. Never use `latest` in production.

| Context | Tag Format | Example |
|---|---|---|
| Feature branch | `{service}:{branch-slug}-{short-sha}` | `user-service:feat-auth-abc1234` |
| Main branch | `{service}:main-{short-sha}` | `user-service:main-def5678` |
| Release candidate | `{service}:rc-{version}` | `user-service:rc-2.3.0` |
| Production release | `{service}:{semver}` | `user-service:2.3.0` |
| Production latest | `{service}:stable` | `user-service:stable` |

```yaml
jobs:
  docker-publish:
    runs-on: ubuntu-latest
    needs: [build-backend]
    strategy:
      matrix:
        service: [user-service, billing-service, notification-service, analytics-service, api-gateway-bff]
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}/${{ matrix.service }}
          tags: |
            type=ref,event=branch,suffix=-{{sha}}
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=stable,enable=${{ startsWith(github.ref, 'refs/tags/v') }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: services/${{ matrix.service }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            APP_VERSION=${{ github.ref_name }}
            BUILD_SHA=${{ github.sha }}
```

### 5. Environment-Based Deployments

Use GitHub Environments with required reviewers for staging and production. Never auto-deploy to production.

```yaml
jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    needs: [docker-publish]
    if: github.ref == 'refs/heads/main'
    environment:
      name: development
      url: https://dev.example.com
    steps:
      - name: Deploy to dev cluster
        uses: ./.github/actions/deploy-to-k8s
        with:
          cluster: dev-cluster
          namespace: saas-dev
          image-tag: main-${{ github.sha }}
          kube-config: ${{ secrets.DEV_KUBECONFIG }}

      - name: Verify health
        run: |
          for service in user-service billing-service api-gateway-bff; do
            echo "Checking $service..."
            for i in $(seq 1 30); do
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://dev.example.com/api/$service/actuator/health")
              if [ "$STATUS" = "200" ]; then
                echo "$service is healthy"
                break
              fi
              if [ "$i" = "30" ]; then
                echo "$service failed health check after 30 attempts"
                exit 1
              fi
              sleep 10
            done
          done

  deploy-staging:
    runs-on: ubuntu-latest
    needs: [deploy-dev]
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Deploy to staging cluster
        uses: ./.github/actions/deploy-to-k8s
        with:
          cluster: staging-cluster
          namespace: saas-staging
          image-tag: main-${{ github.sha }}
          kube-config: ${{ secrets.STAGING_KUBECONFIG }}

  deploy-prod:
    runs-on: ubuntu-latest
    needs: [deploy-staging]
    if: startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production
      url: https://app.example.com
    steps:
      - name: Deploy to production cluster
        uses: ./.github/actions/deploy-to-k8s
        with:
          cluster: prod-cluster
          namespace: saas-prod
          image-tag: ${{ github.ref_name }}
          kube-config: ${{ secrets.PROD_KUBECONFIG }}
```

### 6. Secrets Management

Organize secrets by scope and never inline them in workflow files.

| Secret Scope | Storage Location | Example |
|---|---|---|
| Organization-wide | GitHub Org Secrets | `SONARQUBE_TOKEN`, `SNYK_TOKEN` |
| Repository-level | GitHub Repo Secrets | `CODECOV_TOKEN` |
| Environment-specific | GitHub Environment Secrets | `DEV_KUBECONFIG`, `PROD_DB_URL` |
| Runtime config | GitHub Variables (non-secret) | `API_BASE_URL`, `LOG_LEVEL` |

Rules for secrets:
- Use `GITHUB_TOKEN` for GHCR pushes; do not create PATs for this.
- Rotate environment-specific secrets on a 90-day cadence.
- Never log secrets. Add `::add-mask::` for any dynamically generated values.
- Store database credentials per environment, never share across environments.

### 7. Cache Optimization

#### Gradle Cache

```yaml
- name: Setup Gradle
  uses: gradle/actions/setup-gradle@v4
  with:
    cache-read-only: ${{ github.ref != 'refs/heads/main' }}
```

The Gradle action handles `~/.gradle/caches` and `~/.gradle/wrapper` automatically. Set `cache-read-only: true` on non-main branches to prevent cache pollution from feature branches.

#### npm Cache

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"
    cache: "npm"
    cache-dependency-path: frontend/package-lock.json
```

Always pin `cache-dependency-path` to the correct `package-lock.json` location in a monorepo.

#### Docker Layer Cache

Use GitHub Actions cache backend for Docker BuildKit:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

This caches intermediate Docker layers across runs. Use `mode=max` to cache all layers, not just the final image layers.

### 8. Artifact Management

- Test reports: retain for 7 days.
- Coverage reports: retain for 7 days.
- Build artifacts (frontend bundle, JARs): retain for 3 days.
- Docker images: managed by GHCR retention policies.
- Release artifacts: retain indefinitely via GitHub Releases.

Never upload `node_modules` or `.gradle` as artifacts.

### 9. Health Check Verification

Every deployment job must include a post-deploy health check step. Use Spring Boot Actuator `/actuator/health` for backend services. Use an HTTP 200 check on the root path for the frontend.

```yaml
- name: Verify deployment health
  run: |
    MAX_RETRIES=30
    RETRY_INTERVAL=10
    HEALTH_URL="https://${{ vars.DEPLOY_HOST }}/api/${{ matrix.service }}/actuator/health"

    for i in $(seq 1 $MAX_RETRIES); do
      RESPONSE=$(curl -s -w "\n%{http_code}" "$HEALTH_URL")
      HTTP_CODE=$(echo "$RESPONSE" | tail -1)
      BODY=$(echo "$RESPONSE" | head -1)

      if [ "$HTTP_CODE" = "200" ]; then
        echo "Health check passed: $BODY"
        exit 0
      fi

      echo "Attempt $i/$MAX_RETRIES: HTTP $HTTP_CODE - retrying in ${RETRY_INTERVAL}s"
      sleep $RETRY_INTERVAL
    done

    echo "Health check failed after $MAX_RETRIES attempts"
    exit 1
```

If a health check fails, the workflow must fail and block promotion to the next environment.

### 10. PR Check Workflow

Keep PR checks lightweight and fast. Do not build Docker images on PRs.

```yaml
name: PR Checks
on:
  pull_request:
    branches: [main]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - "services/**"
              - "libs/**"
            frontend:
              - "frontend/**"

  backend-checks:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    uses: ./.github/workflows/ci-backend.yml

  frontend-checks:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    uses: ./.github/workflows/ci-frontend.yml
```

Use `concurrency` with `cancel-in-progress: true` to cancel stale PR runs when new commits are pushed.

## Examples

### Example: Adding a New Microservice to the Pipeline

When adding `order-service` to the monorepo:

1. Add the service name to the matrix in `ci-backend.yml`:
   ```yaml
   matrix:
     service:
       - user-service
       - billing-service
       - order-service  # new
   ```

2. Add a `Dockerfile` in `services/order-service/`:
   ```dockerfile
   FROM eclipse-temurin:21-jre-alpine
   ARG APP_VERSION=dev
   ARG BUILD_SHA=unknown
   LABEL org.opencontainers.image.version=$APP_VERSION
   LABEL org.opencontainers.image.revision=$BUILD_SHA
   WORKDIR /app
   COPY build/libs/order-service-*.jar app.jar
   EXPOSE 8080
   HEALTHCHECK --interval=30s --timeout=3s \
     CMD curl -f http://localhost:8080/actuator/health || exit 1
   ENTRYPOINT ["java", "-jar", "app.jar"]
   ```

3. Add the service to the `docker-publish.yml` matrix.

4. Update path filters in `ci-backend.yml` to include `services/order-service/**`.

5. Add the health check URL to deployment verification scripts.

### Example: Promoting a Release to Production

1. Merge feature branches into `main`. CI runs automatically.
2. Dev deployment triggers automatically on main push.
3. Create a release tag: `git tag v2.3.0 && git push origin v2.3.0`.
4. The `release.yml` workflow triggers, builds images tagged `2.3.0` and `stable`.
5. Staging deployment runs with required reviewer approval.
6. Production deployment runs with required reviewer approval from a separate reviewer.
7. Post-deploy health checks verify all services are operational.
