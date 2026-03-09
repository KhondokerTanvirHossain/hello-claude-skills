---
name: ux-audit
description: Heuristic evaluation checklist and UX audit framework for developer-facing SaaS products, covering usability, information architecture, and developer experience
version: 1.0.0
tags:
  - ux
  - audit
  - heuristics
  - usability
  - developer-experience
  - information-architecture
  - accessibility
globs:
  - "src/pages/**/*.tsx"
  - "src/components/**/*.tsx"
  - "src/routes/**/*"
  - "src/layouts/**/*"
---

# UX Audit

Heuristic evaluation checklist and UX audit framework for developer-facing SaaS products, covering usability, information architecture, and developer experience.

## Purpose

This skill provides a structured methodology for evaluating the user experience of developer productivity SaaS dashboards. It applies established usability heuristics through the specific lens of developer tooling -- where users are technical, workflows are complex, and tolerance for friction is low.

The framework is designed for use during design reviews, sprint retrospectives, pre-launch audits, and continuous improvement cycles. It evaluates the React + TypeScript frontend surfaces served by BFF (Backend for Frontend) microservices backed by Spring Boot and PostgreSQL.

## When to Use

- Conducting a formal UX audit before a major feature launch
- Reviewing a pull request that introduces new UI flows
- Evaluating competitor products for UX benchmarking
- Investigating elevated support ticket volume for a feature area
- Planning UX improvements during a tech debt sprint
- Assessing onboarding completion rates and drop-off points
- Reviewing dashboard information density after adding new metrics
- Evaluating error handling and recovery flows after incident reports

## Heuristic Evaluation Framework

### H1: Visibility of System Status

The system should always keep users informed about what is going on through appropriate feedback within reasonable time.

**Checklist:**

- [ ] All API calls show loading indicators (skeleton screens preferred over spinners for dashboard content)
- [ ] Long-running operations (build, deploy, data export) display progress indicators with estimated time remaining
- [ ] WebSocket or polling-based real-time status updates for background jobs are visible in the relevant context
- [ ] The current navigation state is clearly indicated (active sidebar item, breadcrumb trail, page title)
- [ ] Form submissions show immediate feedback: optimistic UI updates for fast operations, progress states for slow ones
- [ ] System health and service status are visible without requiring navigation (status indicator in header or sidebar)
- [ ] Data freshness is communicated ("Last updated 2 minutes ago", "Live", or stale data warnings)
- [ ] Deployment pipeline stages show clear current-step indication with success/failure states for completed steps

**Developer Tool Specific:**

- [ ] Build logs stream in real-time with auto-scroll and pause-on-hover
- [ ] CI/CD pipeline visualization shows which stage is active, queued, or completed
- [ ] API response times are visible in relevant debugging contexts
- [ ] Resource consumption dashboards (CPU, memory, request count) update at intervals the user can understand and trust

### H2: Match Between System and Real World

The system should speak the users' language, with words, phrases, and concepts familiar to the developer audience.

**Checklist:**

- [ ] Technical terminology matches industry standards (use "repository", not "code storage"; use "pipeline", not "automated workflow")
- [ ] Error messages use developer-appropriate language (include error codes, HTTP status codes, service names)
- [ ] Navigation labels match the mental model of the target developer persona (e.g., "Deployments" not "Release Management" for a CI/CD tool)
- [ ] Data formats match developer conventions (ISO 8601 for timestamps, UTC with timezone indicator, JSON for data previews)
- [ ] Code snippets and configuration examples use syntax highlighting with the correct language grammar
- [ ] API documentation examples match the actual request/response format the user will encounter

**Anti-patterns to flag:**

- Marketing language in product UI ("Supercharge your workflow!" in a dashboard header)
- Inconsistent terminology (switching between "project" and "workspace" for the same concept)
- Non-standard iconography for standard actions (custom icon for "copy to clipboard" instead of the recognized clipboard icon)

### H3: User Control and Freedom

Users often perform actions by mistake. The system should support undo, redo, and easy escape from unwanted states.

**Checklist:**

- [ ] Destructive actions (delete, revoke, terminate) require confirmation with clear description of consequences
- [ ] Bulk destructive actions require explicit typed confirmation (e.g., type the resource name to confirm deletion)
- [ ] Soft deletes with a recovery period are preferred over hard deletes for user-managed resources
- [ ] Modals and drawers have clear close affordances: close button, Escape key, and click-outside-to-dismiss (for non-destructive modals)
- [ ] Multi-step wizards allow backward navigation without losing entered data
- [ ] Form state is preserved when navigating away and returning (via browser back, sidebar navigation, or page refresh)
- [ ] Undo is supported for reversible actions (e.g., "Environment variable removed. Undo" toast with a 10-second window)
- [ ] Filters and search state are reflected in the URL so users can share, bookmark, and use browser history

### H4: Consistency and Standards

Users should not have to wonder whether different words, situations, or actions mean the same thing.

**Checklist:**

- [ ] The same action uses the same label, icon, and position across all pages (e.g., "Create" button always in top-right, always uses plus icon)
- [ ] Primary actions are visually distinct from secondary actions using consistent button variants
- [ ] Date and time formats are consistent across all views (standardize on relative time for recency, absolute for precision)
- [ ] Table interactions are consistent: sorting indicators, pagination controls, row actions all follow the same pattern
- [ ] Empty states follow a consistent template: illustration/icon, headline, description, primary CTA
- [ ] Error state presentation is uniform: inline validation errors, toast notifications, full-page error boundaries
- [ ] Keyboard shortcuts follow platform conventions (Cmd/Ctrl+K for command palette, Cmd/Ctrl+S for save)

**Cross-micro-frontend consistency:**

- [ ] All micro-frontends served by different BFF services use the shared design system components
- [ ] Layout shell (sidebar, header, breadcrumbs) is identical across micro-frontends
- [ ] Authentication states, session expiry, and permission-denied flows are handled identically
- [ ] Loading and error boundaries render the same way regardless of which BFF service is responding

### H5: Error Prevention

A careful design that prevents problems from occurring is better than good error messages.

**Checklist:**

- [ ] Form inputs validate on blur for format errors (email, URL, regex patterns) and show inline error messages
- [ ] Character counts and format hints are visible before the user encounters a validation error
- [ ] Configuration fields with known constraints show allowed values (dropdowns, radio groups) rather than free text
- [ ] Dangerous zones are visually separated (red-bordered "Danger Zone" section at the bottom of settings pages)
- [ ] API key and secret fields are masked by default with a "reveal" toggle
- [ ] YAML, JSON, and code configuration editors provide real-time syntax validation and linting
- [ ] Duplicate resource name creation is prevented with real-time availability checks
- [ ] Rate-limited actions show remaining quota before the user triggers a rate limit error

### H6: Recognition Rather Than Recall

Minimize the user's memory load by making objects, actions, and options visible or easily retrievable.

**Checklist:**

- [ ] Command palette (Cmd/Ctrl+K) provides searchable access to all major actions and navigation targets
- [ ] Recently visited resources are accessible from the sidebar or a "Recent" dropdown
- [ ] Search supports fuzzy matching and shows results as the user types (no submit-then-wait pattern)
- [ ] Context-sensitive help (tooltips, info icons with popovers) explains non-obvious fields inline
- [ ] Code examples are copyable with a single click and include all necessary context (imports, configuration)
- [ ] Dashboard widgets show their data source and time range without requiring the user to remember or navigate elsewhere
- [ ] Filter states are visible as removable chips/tags above the filtered content

### H7: Flexibility and Efficiency of Use

Accelerators -- unseen by the novice user -- may speed up interaction for the expert user.

**Checklist:**

- [ ] Keyboard shortcuts exist for frequent actions (copy, create, search, navigate)
- [ ] A keyboard shortcut reference is accessible via `?` key or from the help menu
- [ ] Bulk operations are supported for list views (select all, bulk delete, bulk status change)
- [ ] Advanced users can use URL query parameters to deep-link to filtered/sorted views
- [ ] CLI equivalents are shown alongside UI actions where applicable ("Run this in your terminal: `saas-cli deploy --env staging`")
- [ ] API documentation provides both curl examples and SDK snippets
- [ ] Power users can save custom dashboard layouts and filter presets
- [ ] Tables support column visibility toggling and column reordering

### H8: Aesthetic and Minimalist Design

Dialogues should not contain information that is irrelevant or rarely needed.

**Checklist:**

- [ ] Dashboard cards show the most important metric prominently with trends, not raw data tables
- [ ] Secondary information is accessible via expand/collapse or "View details" rather than shown by default
- [ ] Empty states are concise: one headline, one sentence of description, one CTA
- [ ] Tooltips contain maximum 2 sentences; longer explanations link to documentation
- [ ] Settings pages use progressive disclosure: basic settings visible, advanced settings behind an expandable section
- [ ] Tables show 5-7 columns maximum; additional data available via row expansion or detail panel
- [ ] Alert banners use the minimum severity level necessary -- do not over-use "critical" styling

### H9: Help Users Recognize, Diagnose, and Recover from Errors

Error messages should be expressed in plain language, precisely indicate the problem, and constructively suggest a solution.

**Checklist:**

- [ ] Error messages follow the format: **What happened** + **Why it happened** + **What the user can do**
- [ ] API error responses from BFF services are translated to user-friendly messages (never show raw stack traces)
- [ ] HTTP 403 errors show which permission is required and how to request access
- [ ] HTTP 404 errors suggest possible alternatives ("Did you mean...?" or link to search)
- [ ] HTTP 429 errors show when the user can retry and current rate limit status
- [ ] HTTP 500 errors provide a unique error ID the user can share with support
- [ ] Form validation errors are associated with the specific field via `aria-describedby` and scroll-to-error behavior
- [ ] Network connectivity errors show a non-blocking banner with auto-retry indication

**Developer-specific error handling:**

- [ ] Build failure logs highlight the failing line and provide context (5 lines above and below)
- [ ] Configuration validation errors pinpoint the exact field/line with the issue
- [ ] Dependency resolution errors show the conflict graph, not just the final error
- [ ] Deployment failures show the last successful deployment and offer a one-click rollback

### H10: Help and Documentation

Even though it is better if the system can be used without documentation, it may be necessary to provide help and documentation.

**Checklist:**

- [ ] Contextual help links navigate to the relevant documentation section, not the docs homepage
- [ ] Onboarding tooltips and guided tours can be replayed from settings
- [ ] API documentation is accessible from within the dashboard, not only from a separate docs site
- [ ] Status page link is accessible from the UI when the system detects degraded performance
- [ ] Changelog or "What's new" is accessible from the UI to communicate recent changes
- [ ] Search within documentation returns results ranked by relevance to the current product area

## Developer Workflow Friction Analysis

Beyond heuristics, evaluate these developer-specific friction points:

### Onboarding Flow Evaluation

Score each phase 1-5 (1 = significant friction, 5 = seamless):

| Phase | Evaluation Criteria |
|-------|-------------------|
| Sign-up | Number of required fields, social login options, email verification speed |
| First project | Time to create first project/resource, clarity of initial setup steps |
| First value | Time to see meaningful output (build result, deployed app, first metric) |
| Integration | Ease of connecting to GitHub/GitLab, installing CLI, adding to CI pipeline |
| Team invite | Clarity of roles/permissions, invitation flow, onboarding for invited members |

Target: Time-to-first-value under 5 minutes for a new user with an existing code repository.

### Dashboard Usability

- **Information density**: Is the signal-to-noise ratio appropriate? Dashboards should surface anomalies and actionable items, not just metrics.
- **Customizability**: Can users rearrange, resize, and hide dashboard widgets?
- **Data visualization clarity**: Do charts have clear axis labels, legends, and tooltips? Are appropriate chart types used (line for trends, bar for comparison, heatmap for density)?
- **Drill-down paths**: Can users click on a metric to see the underlying data? Is the drill-down path intuitive?
- **Time range controls**: Are time range selectors consistent across all dashboard widgets? Do they support both relative ("Last 24 hours") and absolute ranges?

### Data Visualization Clarity Checklist

- [ ] Chart type matches the data relationship (do not use pie charts for more than 5 categories)
- [ ] Y-axis starts at zero for bar charts (or clearly indicates a broken axis)
- [ ] Color palette is distinguishable for colorblind users (use patterns/shapes in addition to color)
- [ ] Tooltips show exact values on hover
- [ ] Empty data states show "No data for this period" rather than an empty chart frame
- [ ] Loading states show skeleton chart shapes, not spinners
- [ ] Large numbers are formatted with appropriate units (1.2K, 3.4M, not 1200 or 3400000)
- [ ] Time-series charts handle timezone display correctly and consistently

## Audit Workflow

### Phase 1: Scope Definition

1. Identify the product area or user journey to audit.
2. Define the user persona(s) and their primary tasks.
3. List the micro-frontends and BFF services involved in the user journey.
4. Establish severity classification: Critical (blocks task completion), Major (causes significant friction), Minor (cosmetic or minor annoyance).

### Phase 2: Heuristic Walkthrough

1. Walk through the user journey step by step as the defined persona.
2. At each step, evaluate against all 10 heuristics using the checklists above.
3. Record each finding with: Heuristic violated, Severity, Screenshot/recording, Description, Suggested fix.
4. Note positive patterns as well -- the audit should reinforce what works.

### Phase 3: Quantitative Data Review

1. Review analytics for the audited flow: task completion rate, time on task, error rates, drop-off points.
2. Cross-reference with support tickets and user feedback for the feature area.
3. Review API latency data from the BFF services to identify performance-related UX issues (slow page loads, timeout errors).

### Phase 4: Findings Report

Structure the report as:

```markdown
## Executive Summary
- Total findings: X (Critical: N, Major: N, Minor: N)
- Top 3 recommendations with expected impact

## Findings by Heuristic
### H1: Visibility of System Status
#### Finding 1.1: No loading state for deployment history
- Severity: Major
- Location: /deployments page, DeploymentHistory component
- Description: When loading deployment history, the page shows a blank
  area for 2-3 seconds with no loading indicator.
- Evidence: [screenshot]
- Recommendation: Add skeleton loading states matching the table row
  structure. Use the shared SkeletonTable component from the design system.
- Effort estimate: Small (1-2 hours)

## Positive Patterns
- List UX patterns that work well and should be preserved/replicated
```

### Phase 5: Prioritization and Roadmap

1. Plot findings on an Impact vs. Effort matrix.
2. Prioritize: High impact + Low effort = immediate fixes; High impact + High effort = planned for next sprint.
3. Create Jira tickets for each accepted finding with the UX audit label.
4. Schedule a follow-up audit for the same area in 2-3 sprints to verify improvements.

## Examples

### Example: Auditing a Deployment Pipeline Dashboard

**Persona**: Backend developer deploying a Spring Boot microservice.

**Journey steps evaluated**:
1. Navigate to Deployments page from sidebar
2. View list of recent deployments with status
3. Click on a specific deployment to see detail
4. Read build logs for a failed deployment
5. Trigger a rollback to a previous successful deployment
6. Verify rollback completion

**Sample findings**:

Finding 1 (H1 - Critical): Build logs do not stream in real-time. The user must manually refresh the page to see updated log output during a deployment. This forces the user to poll manually during a stressful incident response scenario.

Finding 2 (H9 - Major): When a deployment fails due to a health check timeout, the error message says "Deployment failed" with no additional context. It should state: "Deployment failed: health check at /actuator/health did not return 200 within 120s. Last response: 503. Check application startup logs for errors."

Finding 3 (H3 - Major): The rollback button requires navigating to Settings > Deployment History > Select version > Confirm. This should be a one-click action from the deployment detail view with a confirmation dialog.

### Example: Evaluating Onboarding for a New Team Member

**Persona**: Developer invited to join an existing team workspace.

**Evaluation approach**:
1. Time the full flow from invitation email to first meaningful action.
2. Count the number of decisions/inputs required before reaching the dashboard.
3. Identify any points where the user needs information they do not have (e.g., "Select your team's default branch" when they have not yet connected a repository).
4. Verify the invited user sees a contextual onboarding state (not the same empty-state a brand new user would see).

### Example: Data Visualization Audit for Metrics Dashboard

**Evaluation criteria**:
1. Check that all charts use the design system chart color palette (not default library colors).
2. Verify tooltip content includes: metric name, exact value, timestamp, comparison to previous period.
3. Test chart rendering at different time ranges (1 hour, 24 hours, 7 days, 30 days) to ensure axis labels do not overlap.
4. Confirm that zero-data states show a meaningful message rather than a flat line at zero (which could be confused with "all metrics are zero" vs. "no data collected").
5. Verify charts are keyboard-navigable and provide screen reader descriptions for trends.
