---
name: wireframe-to-spec
description: |
  Converting wireframes and mockups into developer-ready technical specifications.
  Trigger phrases: "wireframe to spec", "convert mockup", "design handoff", "spec from wireframe",
  "component breakdown", "wireframe specification", "design to code spec", "mockup to requirements"
version: 1.0.0
tags:
  - wireframe
  - specification
  - component-mapping
  - design-handoff
  - responsive
  - accessibility
  - design-system
globs:
  - "src/pages/**/*.tsx"
  - "src/components/**/*.tsx"
  - "src/features/**/*.tsx"
  - "src/hooks/**/*.ts"
  - "src/api/**/*.ts"
  - "src/store/**/*.ts"
  - "design/**/*.md"
---

# Wireframe to Spec

## Purpose

Define a repeatable process for translating visual wireframes and design mockups (Figma, Sketch, or image-based) into actionable, developer-ready technical specifications. The output bridges the gap between design intent and engineering execution within the React + TypeScript frontend and Spring Boot + PostgreSQL backend architecture.

The specification format accounts for the microservices + BFF pattern: frontend components communicate with BFF endpoints, which orchestrate calls to domain microservices. The spec must clearly delineate what belongs in the frontend, what belongs in the BFF, and what requires changes to domain services.

## When to Use

- A designer delivers wireframes or high-fidelity mockups for a new feature or page.
- Converting a Figma prototype into implementable user stories with acceptance criteria.
- Reviewing a pull request that introduces new UI flows and verifying it matches the design intent.
- Estimating engineering effort for a design proposal by breaking it into component-level tasks.
- Creating a shared document between design and engineering during sprint planning.
- Mapping a wireframe to existing design system components to identify gaps.
- Documenting responsive behavior and accessibility requirements before implementation begins.

## Workflow: Wireframe to Spec Pipeline

### Phase 1: Visual Inventory

Walk through every screen in the wireframe set and create a visual inventory. This is a raw catalog of everything visible before any technical decisions are made.

**Step 1: Screen Catalog**

List every unique screen or state shown in the wireframes.

```markdown
## Screen Catalog

| Screen ID | Name                  | Route (proposed)              | Description                           |
|-----------|-----------------------|-------------------------------|---------------------------------------|
| S-01      | Project List          | /projects                     | Paginated list of user projects       |
| S-02      | Project Detail        | /projects/:id                 | Single project with tabs              |
| S-03      | Create Project Dialog | /projects (modal overlay)     | Multi-step project creation wizard    |
| S-04      | Settings - General    | /projects/:id/settings        | Project name, description, danger zone|
| S-05      | Settings - Members    | /projects/:id/settings/members| Team member management                |
```

**Step 2: Element Inventory Per Screen**

For each screen, catalog every visible UI element.

```markdown
## S-01: Project List - Element Inventory

### Header Region
- Page title: "Projects"
- Search input with icon (placeholder: "Search projects...")
- "New Project" primary button (top-right)
- Filter dropdown: Status (All, Active, Archived)
- Sort dropdown: Last modified, Name, Created

### Content Region
- Project cards in a responsive grid (3 columns desktop, 2 tablet, 1 mobile)
  - Each card contains:
    - Project icon/avatar (40x40, rounded square)
    - Project name (truncated at 2 lines)
    - Description (truncated at 3 lines, muted text)
    - Last modified timestamp (relative: "2 hours ago")
    - Member avatar stack (max 3 + overflow count)
    - Status badge (Active: green, Archived: gray)
    - Kebab menu (Archive, Delete, Duplicate)

### Footer Region
- Pagination: "Showing 1-12 of 48 projects"
- Page size selector: 12, 24, 48
- Page navigation: Previous / page numbers / Next

### Empty State
- Illustration (project-empty-state.svg)
- Headline: "No projects yet"
- Body: "Create your first project to get started"
- CTA: "Create Project" primary button
```

### Phase 2: Component Hierarchy Extraction

Map the visual inventory to a component tree. Start from the page level and decompose into atomic, molecular, and organism components following the existing design system.

**Component Decomposition Rules:**

1. Start from the outermost layout and work inward.
2. Identify reusable components vs. page-specific components.
3. Map to existing design system components first; flag gaps.
4. Name components using PascalCase matching the project convention.
5. Define prop interfaces inline for each new component.

```markdown
## S-01: Component Hierarchy

```
ProjectListPage
├── PageHeader
│   ├── PageTitle (existing: ds/PageTitle)
│   ├── SearchInput (existing: ds/SearchInput)
│   └── Button variant="primary" (existing: ds/Button)
├── FilterBar
│   ├── SelectDropdown label="Status" (existing: ds/Select)
│   └── SelectDropdown label="Sort by" (existing: ds/Select)
├── ProjectGrid (NEW)
│   └── ProjectCard (NEW) [repeated]
│       ├── Avatar size="md" shape="rounded-square" (existing: ds/Avatar)
│       ├── Text variant="heading-sm" (existing: ds/Text)
│       ├── Text variant="body-sm" color="muted" (existing: ds/Text)
│       ├── RelativeTime (existing: ds/RelativeTime)
│       ├── AvatarStack max={3} (existing: ds/AvatarStack)
│       ├── Badge variant="status" (existing: ds/Badge)
│       └── DropdownMenu (existing: ds/DropdownMenu)
│           ├── MenuItem icon="archive" label="Archive"
│           ├── MenuItem icon="copy" label="Duplicate"
│           └── MenuItem icon="trash" label="Delete" variant="danger"
├── Pagination (existing: ds/Pagination)
└── EmptyState (existing: ds/EmptyState)
    ├── Illustration name="project-empty"
    ├── EmptyState.Title
    ├── EmptyState.Description
    └── Button variant="primary"
```

**Design System Gap Analysis:**

```markdown
## Design System Gaps

| Component     | Status      | Action Required                                    |
|---------------|-------------|----------------------------------------------------|
| ProjectGrid   | NEW         | Create grid layout component with responsive cols  |
| ProjectCard   | NEW         | Create card variant for project entities            |
| AvatarStack   | EXISTS      | No changes needed                                  |
| RelativeTime  | EXISTS      | No changes needed                                  |
| FilterBar     | PARTIAL     | Extend to support horizontal filter groups         |
```

### Phase 3: Design Token Mapping

Map visual properties from the wireframe/mockup to existing design system tokens. This ensures the implementation uses the token system rather than hardcoded values.

```markdown
## Token Mapping: ProjectCard

| Visual Property          | Design Token                    | Value            |
|--------------------------|---------------------------------|------------------|
| Card background          | --color-surface-primary         | #FFFFFF          |
| Card border              | --color-border-default          | #E2E8F0          |
| Card border radius       | --radius-md                     | 8px              |
| Card shadow (rest)       | --shadow-sm                     | 0 1px 2px ...    |
| Card shadow (hover)      | --shadow-md                     | 0 4px 6px ...    |
| Card padding             | --space-4                       | 16px             |
| Card gap (between items) | --space-3                       | 12px             |
| Project name font        | --font-heading-sm               | 14px/600         |
| Description font         | --font-body-sm                  | 13px/400         |
| Description color        | --color-text-muted              | #64748B          |
| Status badge (active)    | --color-success-subtle          | #DCFCE7          |
| Status badge text        | --color-success-emphasis         | #166534          |
| Grid gap                 | --space-4                       | 16px             |
| Kebab icon color         | --color-icon-muted              | #94A3B8          |
| Kebab icon color (hover) | --color-icon-default            | #334155          |
```

**Token gap handling:**

If a visual property does not map to an existing token, document it as a gap and propose a new token name following the naming convention:

```
--{category}-{property}-{variant}-{state}
Example: --color-surface-card-hover
```

### Phase 4: State Analysis

For each screen, document every possible state the UI can be in. This drives both component implementation and test coverage.

```markdown
## S-01: State Matrix

| State           | Trigger                        | Visual Change                                     |
|-----------------|--------------------------------|---------------------------------------------------|
| Loading         | Initial page load              | Skeleton cards (3x4 grid of skeleton rectangles)  |
| Empty           | User has 0 projects            | EmptyState component with CTA                     |
| Populated       | User has 1+ projects           | ProjectGrid with cards                            |
| Search active   | User types in search           | Filtered cards, "N results for 'query'" subtitle  |
| Search empty    | Search yields 0 results        | EmptyState variant="search" with clear CTA        |
| Filter active   | Status filter != "All"         | Filtered cards, active filter chip visible         |
| Error           | API request fails              | ErrorBanner with retry button                     |
| Card hover      | Mouse over card                | Elevated shadow, cursor pointer                   |
| Card menu open  | Click kebab on card            | DropdownMenu visible                              |
| Delete confirm  | Click "Delete" in menu         | ConfirmDialog with project name                   |
| Deleting        | Confirm delete                 | Card fades out, optimistic removal                |
| Archiving       | Click "Archive" in menu        | Card moves to archived, toast confirmation        |
```

### Phase 5: Responsive Breakpoint Annotations

Document how each screen adapts across breakpoints. Use the project's standard breakpoints.

```markdown
## Responsive Behavior: S-01 Project List

### Breakpoints
- Mobile: 0-639px (sm)
- Tablet: 640-1023px (md)
- Desktop: 1024-1279px (lg)
- Wide: 1280px+ (xl)

### Layout Adaptations

| Element         | Mobile (sm)           | Tablet (md)          | Desktop (lg)         | Wide (xl)            |
|-----------------|-----------------------|----------------------|----------------------|----------------------|
| Page header     | Stack vertically      | Inline, search below | Single row           | Single row           |
| Search input    | Full width, below title| 300px, inline       | 320px, inline        | 400px, inline        |
| Filter bar      | Horizontal scroll     | Inline               | Inline               | Inline               |
| Project grid    | 1 column              | 2 columns            | 3 columns            | 4 columns            |
| Card kebab menu | Bottom sheet          | Dropdown             | Dropdown             | Dropdown             |
| Pagination      | Simplified (prev/next)| Full                 | Full                 | Full                 |
| New Project btn | FAB (bottom-right)    | Header button        | Header button        | Header button        |

### Touch Adaptations (Mobile/Tablet)
- Card tap area: entire card is tappable (navigates to project detail)
- Long press on card: opens context menu (replaces kebab)
- Swipe-to-archive on card (optional, progressive enhancement)
- Filter dropdowns become bottom sheets on mobile
- Search input has a dedicated "search mode" with back button on mobile
```

### Phase 6: Accessibility Requirements

Document accessibility requirements per component. These are non-negotiable acceptance criteria.

```markdown
## Accessibility Requirements: S-01 Project List

### Landmarks
- Page wrapped in <main> with aria-label="Projects"
- Search region has role="search"
- Project grid uses role="list", each card role="listitem"

### Keyboard Navigation
- Tab order: Search -> Filter Status -> Filter Sort -> New Project -> First Card -> Pagination
- Cards are focusable (tabindex="0") with Enter/Space to navigate
- Kebab menu opens with Enter/Space, navigable with arrow keys, closes with Escape
- Search input: Escape clears and restores focus to previous element

### Screen Reader Announcements
- Page title announced on load: "Projects, showing 12 of 48"
- Search results announced via aria-live="polite": "8 projects found for 'dashboard'"
- Empty state: "No projects found. Create your first project."
- Delete confirmation: "Delete project 'My App'? This action cannot be undone."
- After delete: "Project 'My App' deleted" via toast with role="status"

### ARIA Attributes
| Element              | ARIA                                                  |
|----------------------|-------------------------------------------------------|
| Search input         | aria-label="Search projects"                          |
| Status filter        | aria-label="Filter by status"                         |
| Sort dropdown        | aria-label="Sort projects"                            |
| Project card         | aria-label="{project name}, {status}, modified {date}"|
| Kebab menu trigger   | aria-haspopup="menu", aria-expanded="false/true"      |
| Kebab menu           | role="menu", each item role="menuitem"                |
| Pagination           | nav with aria-label="Project list pagination"         |
| Page size selector   | aria-label="Projects per page"                        |

### Color Contrast
- All text meets WCAG 2.1 AA contrast ratios (4.5:1 for normal text, 3:1 for large text)
- Status badges use both color and text label (not color alone)
- Focus indicators: 2px solid --color-focus-ring with 2px offset
- Interactive elements have distinct hover, focus, and active states
```

### Phase 7: Acceptance Criteria

Write testable acceptance criteria for each user-visible behavior. Use Given/When/Then format.

```markdown
## Acceptance Criteria: S-01 Project List

### AC-01: Display project list
GIVEN I am logged in and have 5 projects
WHEN I navigate to /projects
THEN I see a grid of 5 project cards
AND each card shows the project name, description, last modified time, member avatars, and status badge
AND the "New Project" button is visible in the header

### AC-02: Search projects
GIVEN I am on the project list page with 20 projects
WHEN I type "dashboard" in the search input
THEN the grid filters to show only projects whose name or description contains "dashboard"
AND a subtitle shows "N projects found for 'dashboard'"
AND the URL updates to /projects?q=dashboard

### AC-03: Empty search results
GIVEN I am on the project list page
WHEN I search for a term that matches no projects
THEN the grid is replaced by an empty state with message "No projects match 'xyz'"
AND a "Clear search" button is visible
AND clicking "Clear search" restores the full project list

### AC-04: Delete project
GIVEN I am on the project list page
WHEN I click the kebab menu on a project card
AND I click "Delete"
THEN a confirmation dialog appears with the text "Delete '{project name}'? This cannot be undone."
AND I must type the project name to confirm
WHEN I type the project name and click "Delete"
THEN the project is removed from the list
AND a success toast appears: "Project '{name}' deleted"
AND the API call DELETE /api/v1/projects/{id} is made

### AC-05: Responsive layout
GIVEN I am on the project list page
WHEN I resize the browser to mobile width (< 640px)
THEN the project grid displays in a single column
AND the "New Project" button becomes a floating action button
AND filter dropdowns become bottom sheets
```

### Phase 8: API Contract Identification

Map each UI interaction to the API calls required. Identify which BFF endpoints exist and which need to be created.

```markdown
## API Requirements: S-01 Project List

| UI Action         | HTTP Method | BFF Endpoint                   | Status   | Domain Service Call                    |
|-------------------|-------------|--------------------------------|----------|----------------------------------------|
| Load projects     | GET         | /api/v1/projects               | EXISTS   | project-service: GET /projects         |
| Search projects   | GET         | /api/v1/projects?q={query}     | EXTEND   | Add search param forwarding            |
| Filter by status  | GET         | /api/v1/projects?status={s}    | EXTEND   | Add status filter                      |
| Delete project    | DELETE      | /api/v1/projects/{id}          | EXISTS   | project-service: DELETE /projects/{id} |
| Archive project   | PATCH       | /api/v1/projects/{id}          | EXISTS   | project-service: PATCH body:{archived} |
| Duplicate project | POST        | /api/v1/projects/{id}/duplicate| NEW      | project-service: POST /projects/clone  |

### New BFF Endpoint Spec: Duplicate Project

POST /api/v1/projects/{id}/duplicate

Request: (empty body, or optional name override)
```json
{
  "name": "Copy of My Project"   // optional
}
```

Response: 201 Created
```json
{
  "id": "proj_abc123",
  "name": "Copy of My Project",
  "status": "ACTIVE",
  "createdAt": "2026-03-09T10:00:00Z"
}
```

Error cases:
- 404: Source project not found
- 403: User does not have duplicate permission
- 409: A project with the duplicate name already exists
```

### Phase 9: Handoff Document Assembly

Assemble the complete specification into the handoff format. Two formats are supported.

**Format A: Figma Annotations (preferred for design-heavy features)**

Annotate directly in Figma using the dev mode or a plugin. Structure:
1. Frame-level annotation: Component name, route, state
2. Element-level annotation: Design token references, ARIA attributes
3. Interaction annotation: Click targets, hover states, transitions
4. Responsive annotation: Breakpoint-specific layouts as separate frames

**Format B: Markdown Spec (preferred for engineering-heavy features)**

```markdown
# Feature Spec: [Feature Name]

## Overview
- Designer: @designer-name
- Engineer: @engineer-name (to be assigned)
- Figma: [link]
- Jira Epic: [link]
- Target sprint: Sprint 24

## Screens
[Screen catalog from Phase 1]

## Component Hierarchy
[From Phase 2]

## Token Mapping
[From Phase 3]

## States
[From Phase 4]

## Responsive Behavior
[From Phase 5]

## Accessibility
[From Phase 6]

## Acceptance Criteria
[From Phase 7]

## API Contracts
[From Phase 8]

## Open Questions
- [ ] Q1: What happens when a user archives a project with active deployments?
- [ ] Q2: Should "Duplicate" copy project settings and members?
- [ ] Q3: Maximum number of projects per user/org?

## Estimation
| Task                          | Estimate | Owner    |
|-------------------------------|----------|----------|
| ProjectGrid + ProjectCard     | 3 pts    | Frontend |
| FilterBar extension           | 2 pts    | Frontend |
| Duplicate project BFF endpoint| 2 pts    | Backend  |
| Search integration            | 1 pt     | Backend  |
| Accessibility + testing       | 2 pts    | Frontend |
| Total                         | 10 pts   |          |
```

## Rules

1. **Every visual element must map to a component.** No element in the wireframe should be left unaccounted for in the component hierarchy. If an element does not map to an existing design system component, it must be flagged as NEW.

2. **Every interaction must have an acceptance criterion.** If the user can click, type, hover, drag, or otherwise interact with an element, there must be a corresponding AC written in Given/When/Then format.

3. **Every new component must have accessibility requirements.** ARIA roles, keyboard navigation, and screen reader behavior are not optional. They are part of the spec, not an afterthought.

4. **Responsive behavior must be documented for all breakpoints.** If the wireframe only shows a desktop layout, the spec author must define mobile and tablet behavior. Do not assume the engineer will figure it out.

5. **Use design tokens, not raw values.** The spec must reference token names (e.g., --space-4) not pixel values (e.g., 16px). If a token does not exist, propose one.

6. **API contracts must distinguish BFF from domain services.** Every API call in the spec must indicate whether it hits the BFF layer or goes directly to a domain service. The BFF is the default path for frontend calls.

7. **States are exhaustive.** Every screen must document: loading, empty, populated, error, and any interaction states (hover, active, disabled). Missing states cause engineering rework.

8. **Open questions are first-class.** Ambiguities in the wireframe must be captured as open questions in the spec, not silently resolved by the engineer. Each question should tag the designer or PM who can resolve it.

9. **Spec-first, code-second.** The spec must be reviewed and approved by both design and engineering leads before implementation begins. Changes to the spec after implementation starts must go through a change request process.

10. **Animations and transitions must be documented.** If the wireframe implies motion (e.g., a card sliding in, a modal fading), the spec must define the animation curve, duration, and trigger. Use design system motion tokens where they exist.

## Examples

### Example 1: Specifying a Modal Dialog

```markdown
## Component: CreateProjectDialog

### Trigger
- Clicking "New Project" button on ProjectListPage
- URL does not change (modal overlay, not a route)

### Layout
- Modal width: 560px (desktop), full-width with 16px margin (mobile)
- Max height: 80vh with internal scroll
- Overlay: --color-overlay-default (rgba(0,0,0,0.5))
- Animation: fade-in 150ms ease-out (overlay), slide-up 200ms ease-out (modal)

### Content
Step 1 of 2: Project Details
- Text input: "Project name" (required, max 64 chars, auto-focus)
- Textarea: "Description" (optional, max 500 chars, 4 rows)
- Select: "Template" (None, Starter, Full Stack)

Step 2 of 2: Team Setup
- Combobox: "Add team members" (search by name/email, multi-select)
- Radio group: "Default role" (Viewer, Editor, Admin)

### Footer
- "Cancel" text button (left)
- "Back" text button (step 2 only, left-center)
- "Next" primary button (step 1) / "Create Project" primary button (step 2)
- Loading state on "Create Project": spinner in button, disabled

### Keyboard
- Escape closes modal (with unsaved changes confirmation if form is dirty)
- Tab cycles through form fields, then footer buttons
- Focus trapped inside modal while open
- On close, focus returns to the "New Project" button

### API
- POST /api/v1/projects on "Create Project" click
- On success: close modal, add new project to grid (optimistic or refetch), toast
- On validation error: map field errors to form fields inline
- On 500: show error banner inside modal, keep form state
```

### Example 2: Specifying a Data Table with Inline Actions

```markdown
## Component: MemberTable (Settings - Members page)

### Columns
| Column       | Width   | Sortable | Content                              |
|-------------|---------|----------|--------------------------------------|
| Member      | 40%     | Yes (name)| Avatar + Name + Email (subtitle)   |
| Role        | 20%     | Yes      | Role badge (Owner, Admin, Member)    |
| Added       | 20%     | Yes      | Relative timestamp                   |
| Actions     | 20%     | No       | "Change Role" dropdown + "Remove" btn|

### Interactions
- Click column header to sort (toggle asc/desc, default: name asc)
- "Change Role" opens inline dropdown anchored to the button
- "Remove" shows confirmation dialog: "Remove {name} from {project}?"
- Owner role cannot be changed or removed (buttons disabled with tooltip)
- Current user cannot remove themselves (button disabled with tooltip)

### Responsive (Mobile)
- Table becomes a card list
- Each card: Avatar + Name + Role badge + kebab menu (Change Role, Remove)
- Sort control moves to a dropdown above the list
```

### Example 3: Documenting an Empty State

```markdown
## Component: EmptyState for MemberTable

### When shown
- Project has only 1 member (the owner) and the owner is viewing the members page

### Content
- Icon: users-plus (from icon set)
- Headline: "You're the only member"
- Body: "Invite team members to collaborate on this project."
- CTA: "Invite Members" primary button -> opens InviteMemberDialog

### Accessibility
- aria-label on the section: "No team members besides you"
- CTA button: aria-label="Invite team members to this project"
- Icon is decorative: aria-hidden="true"
```
