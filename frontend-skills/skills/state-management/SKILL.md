---
name: state-management
description: State management conventions for React + TypeScript SaaS applications using modern patterns including server state (TanStack Query), client state (Zustand), and URL state
version: 1.0.0
tags:
  - react
  - typescript
  - tanstack-query
  - zustand
  - state-management
  - server-state
  - url-state
globs:
  - "src/stores/**/*.ts"
  - "src/hooks/use*.ts"
  - "src/queries/**/*.ts"
  - "src/mutations/**/*.ts"
  - "src/state/**/*.ts"
---

# State Management

## Purpose

Establish clear conventions for managing state in React + TypeScript SaaS applications. State is categorized into four distinct types -- server state, client state, URL state, and form state -- each with its own dedicated tooling and patterns. This eliminates the common anti-pattern of dumping all state into a single global store and ensures that each category of state is managed with the tool best suited for its lifecycle, caching needs, and synchronization requirements.

## When to Use

- Starting a new feature that fetches data from Spring Boot APIs and displays it in React components
- Deciding where to store a piece of state (server cache vs. local UI vs. URL vs. form)
- Implementing optimistic updates for mutations that modify backend data
- Setting up cache invalidation strategies after create/update/delete operations
- Building real-time features (WebSocket subscriptions, polling, Server-Sent Events)
- Refactoring a component tree that suffers from prop drilling or stale data
- Implementing URL-driven state for shareable views (filters, pagination, search terms)
- Managing complex multi-step form state with validation

## State Categorization

Before writing any state logic, classify the data into one of four categories:

| Category | Tool | Lifecycle | Examples |
|----------|------|-----------|----------|
| **Server State** | TanStack Query | Owned by backend, cached locally | User profiles, project lists, billing data, feature flags |
| **Client State** | Zustand | Owned by frontend, session-scoped | Theme preference, sidebar open/closed, modal visibility, selected items |
| **URL State** | `nuqs` or `useSearchParams` | Owned by the URL, shareable | Filters, sort order, pagination, search query, active tab |
| **Form State** | React Hook Form + Zod | Owned by the form instance, transient | Registration form, settings form, multi-step wizard |

**Decision rule:** If the data exists on the server, it is server state. If it needs to survive a page refresh and be shareable via link, it is URL state. If it controls UI appearance or interaction within a session, it is client state. If it is user input being collected for submission, it is form state.

## Workflow and Rules

### Rule 1: Server State with TanStack Query

All data fetched from Spring Boot APIs is managed exclusively through TanStack Query. Never store fetched API data in Zustand, Redux, React context, or component state.

**Query Key Conventions:**

```typescript
// src/queries/queryKeys.ts
export const queryKeys = {
  projects: {
    all: ['projects'] as const,
    lists: () => [...queryKeys.projects.all, 'list'] as const,
    list: (filters: ProjectFilters) =>
      [...queryKeys.projects.lists(), filters] as const,
    details: () => [...queryKeys.projects.all, 'detail'] as const,
    detail: (id: string) =>
      [...queryKeys.projects.details(), id] as const,
    members: (id: string) =>
      [...queryKeys.projects.detail(id), 'members'] as const,
  },
  billing: {
    all: ['billing'] as const,
    subscription: (orgId: string) =>
      [...queryKeys.billing.all, 'subscription', orgId] as const,
    invoices: (orgId: string, filters?: InvoiceFilters) =>
      [...queryKeys.billing.all, 'invoices', orgId, filters] as const,
    usage: (orgId: string) =>
      [...queryKeys.billing.all, 'usage', orgId] as const,
  },
  users: {
    all: ['users'] as const,
    me: () => [...queryKeys.users.all, 'me'] as const,
    detail: (id: string) =>
      [...queryKeys.users.all, 'detail', id] as const,
    preferences: (id: string) =>
      [...queryKeys.users.all, 'preferences', id] as const,
  },
} as const;
```

**Query Hook Conventions:**

```typescript
// src/queries/useProjects.ts
import { useQuery, useSuspenseQuery } from '@tanstack/react-query';
import { apiClient } from '@/api/client';
import { queryKeys } from './queryKeys';
import type { Project, ProjectFilters } from '@/types/project';

// Standard query hook -- returns loading/error states
export function useProjects(filters: ProjectFilters) {
  return useQuery({
    queryKey: queryKeys.projects.list(filters),
    queryFn: () => apiClient.get<Project[]>('/bff/projects', { params: filters }),
    staleTime: 30_000,       // 30 seconds before considered stale
    gcTime: 5 * 60_000,     // 5 minutes in garbage collection
    placeholderData: (previousData) => previousData, // Keep previous data during refetch
  });
}

// Suspense query -- for use inside <Suspense> boundaries
export function useProjectSuspense(projectId: string) {
  return useSuspenseQuery({
    queryKey: queryKeys.projects.detail(projectId),
    queryFn: () => apiClient.get<Project>(`/bff/projects/${projectId}`),
    staleTime: 60_000,
  });
}

// Dependent query -- only runs when prerequisite data is available
export function useProjectMembers(projectId: string | undefined) {
  return useQuery({
    queryKey: queryKeys.projects.members(projectId!),
    queryFn: () => apiClient.get(`/bff/projects/${projectId}/members`),
    enabled: !!projectId,    // Only fetch when projectId is defined
  });
}
```

**Stale Time Guidelines:**

| Data Volatility | staleTime | gcTime | Examples |
|----------------|-----------|--------|----------|
| Real-time | 0 | 30s | Notifications, live metrics |
| Frequently changing | 10-30s | 2 min | Project lists, activity feeds |
| Moderately stable | 1-5 min | 10 min | User profile, org settings |
| Rarely changing | 15-60 min | 1 hour | Plan details, feature flags |
| Static reference | Infinity | 24 hours | Countries, timezones, enums |

### Rule 2: Mutations and Cache Invalidation

Every mutation (create, update, delete) against a Spring Boot API uses `useMutation` with explicit cache invalidation or optimistic updates.

```typescript
// src/mutations/useUpdateProject.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/api/client';
import { queryKeys } from '@/queries/queryKeys';
import type { Project, UpdateProjectInput } from '@/types/project';

export function useUpdateProject() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ projectId, data }: { projectId: string; data: UpdateProjectInput }) =>
      apiClient.put<Project>(`/bff/projects/${projectId}`, data),

    // Invalidation strategy: refetch affected queries after success
    onSuccess: (_data, variables) => {
      // Invalidate the specific project detail
      queryClient.invalidateQueries({
        queryKey: queryKeys.projects.detail(variables.projectId),
      });
      // Invalidate all project lists (the updated project may appear in any list)
      queryClient.invalidateQueries({
        queryKey: queryKeys.projects.lists(),
      });
    },

    onError: (error) => {
      // Error is already normalized by the API client interceptor
      toast.error(error.message);
    },
  });
}
```

**Cache Invalidation Strategies:**

| Operation | Strategy | When to Use |
|-----------|----------|-------------|
| `invalidateQueries` | Refetch from server | Default for most mutations; ensures consistency |
| `setQueryData` | Update cache directly | When the mutation response contains the full updated entity |
| Optimistic update | Update cache before server confirms | Low-risk operations where instant UI feedback matters |
| `removeQueries` | Evict from cache | After deleting an entity; prevents stale cache reads |

### Rule 3: Optimistic Updates

Use optimistic updates for mutations that need instant UI feedback and where rollback on failure is acceptable.

```typescript
// src/mutations/useToggleProjectStar.ts
export function useToggleProjectStar() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ projectId, starred }: { projectId: string; starred: boolean }) =>
      apiClient.put(`/bff/projects/${projectId}/star`, { starred }),

    onMutate: async ({ projectId, starred }) => {
      // 1. Cancel in-flight fetches to prevent race conditions
      await queryClient.cancelQueries({
        queryKey: queryKeys.projects.detail(projectId),
      });

      // 2. Snapshot the current value for rollback
      const previousProject = queryClient.getQueryData<Project>(
        queryKeys.projects.detail(projectId)
      );

      // 3. Optimistically update the cache
      queryClient.setQueryData<Project>(
        queryKeys.projects.detail(projectId),
        (old) => old ? { ...old, starred } : old
      );

      // 4. Return the snapshot for onError rollback
      return { previousProject };
    },

    onError: (_error, { projectId }, context) => {
      // Rollback to snapshot on failure
      if (context?.previousProject) {
        queryClient.setQueryData(
          queryKeys.projects.detail(projectId),
          context.previousProject
        );
      }
      toast.error('Failed to update star status. Please try again.');
    },

    onSettled: (_data, _error, { projectId }) => {
      // Always refetch after mutation settles to sync with server
      queryClient.invalidateQueries({
        queryKey: queryKeys.projects.detail(projectId),
      });
    },
  });
}
```

### Rule 4: Client State with Zustand

Use Zustand for UI-only state that does not exist on the server. Keep stores small and domain-scoped. Never put fetched API data in Zustand.

**Store Conventions:**

```typescript
// src/stores/uiStore.ts
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface UiState {
  // State
  sidebarOpen: boolean;
  theme: 'light' | 'dark' | 'system';
  commandPaletteOpen: boolean;

  // Actions
  toggleSidebar: () => void;
  setTheme: (theme: UiState['theme']) => void;
  openCommandPalette: () => void;
  closeCommandPalette: () => void;
}

export const useUiStore = create<UiState>()(
  devtools(
    persist(
      (set) => ({
        sidebarOpen: true,
        theme: 'system',
        commandPaletteOpen: false,

        toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
        setTheme: (theme) => set({ theme }),
        openCommandPalette: () => set({ commandPaletteOpen: true }),
        closeCommandPalette: () => set({ commandPaletteOpen: false }),
      }),
      {
        name: 'ui-preferences',
        partialize: (state) => ({
          sidebarOpen: state.sidebarOpen,
          theme: state.theme,
          // Do NOT persist modal/palette open state
        }),
      }
    ),
    { name: 'UiStore' }
  )
);
```

**Store organization:**

```
src/stores/
  uiStore.ts          # Sidebar, theme, modals, panels
  selectionStore.ts   # Multi-select in tables, bulk actions
  onboardingStore.ts  # Onboarding tour step, dismissed hints
  editorStore.ts      # Editor-specific transient state (unsaved changes flag)
```

**Rules for Zustand stores:**

- One store per bounded UI domain; avoid a single monolithic store
- Colocate state and actions in the same store definition
- Use `persist` middleware only for state that should survive page refresh
- Use `partialize` to exclude transient state from persistence
- Use `devtools` middleware in development for debugging
- Export individual selector hooks to prevent unnecessary re-renders

```typescript
// Selector pattern to prevent re-renders
const sidebarOpen = useUiStore((s) => s.sidebarOpen);
const toggleSidebar = useUiStore((s) => s.toggleSidebar);

// WRONG: this causes re-renders on ANY store change
const { sidebarOpen, toggleSidebar } = useUiStore();
```

### Rule 5: URL State

State that should survive page refresh and be shareable via URL belongs in search parameters. Use a type-safe URL state library.

```typescript
// src/hooks/useProjectFilters.ts
import { useQueryStates, parseAsString, parseAsInteger, parseAsStringEnum } from 'nuqs';

const projectSortOptions = ['name', 'created', 'updated'] as const;
type ProjectSort = typeof projectSortOptions[number];

export function useProjectFilters() {
  return useQueryStates({
    search: parseAsString.withDefault(''),
    status: parseAsStringEnum(['active', 'archived', 'all']).withDefault('active'),
    sort: parseAsStringEnum(projectSortOptions).withDefault('updated'),
    page: parseAsInteger.withDefault(1),
    pageSize: parseAsInteger.withDefault(20),
  });
}

// Usage in component
function ProjectListPage() {
  const [filters, setFilters] = useProjectFilters();
  const { data, isLoading } = useProjects(filters);

  return (
    <div>
      <SearchInput
        value={filters.search}
        onChange={(search) => setFilters({ search, page: 1 })}
      />
      <StatusFilter
        value={filters.status}
        onChange={(status) => setFilters({ status, page: 1 })}
      />
      <ProjectTable data={data} isLoading={isLoading} />
      <Pagination
        page={filters.page}
        pageSize={filters.pageSize}
        onPageChange={(page) => setFilters({ page })}
      />
    </div>
  );
}
```

**URL state is the source of truth for filters.** The TanStack Query hook receives the URL state as its query key input, creating a reactive chain: URL changes trigger query key changes trigger refetches.

### Rule 6: Form State

Form state is transient and owned by the form instance. Use React Hook Form with Zod validation schemas.

```typescript
// src/forms/schemas/createProject.schema.ts
import { z } from 'zod';

export const createProjectSchema = z.object({
  name: z
    .string()
    .min(3, 'Project name must be at least 3 characters')
    .max(100, 'Project name must be at most 100 characters')
    .regex(/^[a-zA-Z0-9\s-]+$/, 'Only letters, numbers, spaces, and hyphens'),
  description: z.string().max(500).optional(),
  visibility: z.enum(['private', 'team', 'public']),
  templateId: z.string().uuid().optional(),
});

export type CreateProjectInput = z.infer<typeof createProjectSchema>;

// src/forms/CreateProjectForm.tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

function CreateProjectForm({ onSuccess }: { onSuccess: () => void }) {
  const form = useForm<CreateProjectInput>({
    resolver: zodResolver(createProjectSchema),
    defaultValues: {
      name: '',
      description: '',
      visibility: 'team',
    },
  });

  const createProject = useCreateProject();

  const onSubmit = form.handleSubmit(async (data) => {
    await createProject.mutateAsync(data);
    onSuccess();
  });

  return (
    <form onSubmit={onSubmit}>
      {/* Form fields bound to form.register() */}
    </form>
  );
}
```

### Rule 7: Real-Time Data Patterns

For data that needs live updates, use one of the following patterns based on the update frequency and infrastructure available.

**Polling (simplest, use when update latency of 5-30 seconds is acceptable):**

```typescript
export function useNotifications(userId: string) {
  return useQuery({
    queryKey: queryKeys.notifications.list(userId),
    queryFn: () => apiClient.get(`/bff/notifications/${userId}`),
    refetchInterval: 15_000,                // Poll every 15 seconds
    refetchIntervalInBackground: false,      // Stop polling when tab is hidden
  });
}
```

**WebSocket with TanStack Query cache sync:**

```typescript
// src/hooks/useRealtimeProjectUpdates.ts
import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { queryKeys } from '@/queries/queryKeys';

export function useRealtimeProjectUpdates(projectId: string) {
  const queryClient = useQueryClient();

  useEffect(() => {
    const ws = new WebSocket(
      `${process.env.NEXT_PUBLIC_WS_URL}/projects/${projectId}/updates`
    );

    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);

      switch (update.type) {
        case 'PROJECT_UPDATED':
          queryClient.setQueryData(
            queryKeys.projects.detail(projectId),
            update.payload
          );
          break;
        case 'MEMBER_ADDED':
        case 'MEMBER_REMOVED':
          queryClient.invalidateQueries({
            queryKey: queryKeys.projects.members(projectId),
          });
          break;
      }
    };

    return () => ws.close();
  }, [projectId, queryClient]);
}
```

**Server-Sent Events (SSE) for unidirectional streams:**

```typescript
// src/hooks/useLiveBuildStatus.ts
export function useLiveBuildStatus(buildId: string) {
  const queryClient = useQueryClient();

  useEffect(() => {
    const eventSource = new EventSource(
      `/bff/builds/${buildId}/stream`,
      { withCredentials: true }
    );

    eventSource.addEventListener('status', (event) => {
      const status = JSON.parse(event.data);
      queryClient.setQueryData(
        ['builds', 'detail', buildId],
        (old: BuildDetail | undefined) =>
          old ? { ...old, status: status.phase, progress: status.progress } : old
      );
    });

    eventSource.addEventListener('complete', () => {
      queryClient.invalidateQueries({ queryKey: ['builds', 'detail', buildId] });
      eventSource.close();
    });

    return () => eventSource.close();
  }, [buildId, queryClient]);
}
```

## Examples

### Example 1: Complete feature -- Project settings page with all state types

```typescript
// This example demonstrates all four state categories in a single feature

// URL State: active settings tab
const [{ tab }, setParams] = useQueryStates({
  tab: parseAsStringEnum(['general', 'members', 'danger']).withDefault('general'),
});

// Server State: project data from API
const { data: project } = useProjectSuspense(projectId);
const { data: members } = useProjectMembers(projectId);

// Client State: unsaved changes warning
const hasUnsavedChanges = useEditorStore((s) => s.hasUnsavedChanges);

// Form State: settings form
const form = useForm<UpdateProjectInput>({
  resolver: zodResolver(updateProjectSchema),
  values: project, // Sync form with server data
});
```

### Example 2: Bulk selection with Zustand + server mutations

```typescript
// src/stores/selectionStore.ts
interface SelectionState {
  selectedIds: Set<string>;
  toggle: (id: string) => void;
  selectAll: (ids: string[]) => void;
  clearSelection: () => void;
  isSelected: (id: string) => boolean;
}

export const useSelectionStore = create<SelectionState>()((set, get) => ({
  selectedIds: new Set(),
  toggle: (id) =>
    set((s) => {
      const next = new Set(s.selectedIds);
      next.has(id) ? next.delete(id) : next.add(id);
      return { selectedIds: next };
    }),
  selectAll: (ids) => set({ selectedIds: new Set(ids) }),
  clearSelection: () => set({ selectedIds: new Set() }),
  isSelected: (id) => get().selectedIds.has(id),
}));

// In the component using both Zustand selection and TanStack Query mutation
function ProjectBulkActions() {
  const selectedIds = useSelectionStore((s) => s.selectedIds);
  const clearSelection = useSelectionStore((s) => s.clearSelection);
  const archiveProjects = useArchiveProjects();

  const handleBulkArchive = async () => {
    await archiveProjects.mutateAsync({ projectIds: [...selectedIds] });
    clearSelection();
    toast.success(`Archived ${selectedIds.size} projects`);
  };

  return (
    <BulkActionBar visible={selectedIds.size > 0}>
      <span>{selectedIds.size} selected</span>
      <Button onClick={handleBulkArchive} loading={archiveProjects.isPending}>
        Archive Selected
      </Button>
    </BulkActionBar>
  );
}
```

### Example 3: TanStack Query configuration for the application

```typescript
// src/providers/QueryProvider.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 5 * 60_000,
      retry: (failureCount, error) => {
        // Don't retry on 4xx client errors
        if (error instanceof ApiError && error.status >= 400 && error.status < 500) {
          return false;
        }
        return failureCount < 3;
      },
      refetchOnWindowFocus: 'always',
      refetchOnReconnect: 'always',
    },
    mutations: {
      retry: false, // Never auto-retry mutations
    },
  },
});

export function QueryProvider({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      {process.env.NODE_ENV === 'development' && (
        <ReactQueryDevtools initialIsOpen={false} />
      )}
    </QueryClientProvider>
  );
}
```
