---
name: design-system
description: Conventions for building and maintaining a React + TypeScript component library with consistent design tokens, theming, and accessibility standards for SaaS dashboards
version: 1.0.0
tags:
  - react
  - typescript
  - design-tokens
  - theming
  - accessibility
  - component-library
  - storybook
globs:
  - "src/components/**/*.tsx"
  - "src/components/**/*.ts"
  - "src/design-tokens/**/*"
  - "src/themes/**/*"
  - "src/styles/**/*"
  - "**/*.stories.tsx"
---

# Design System

Conventions for building and maintaining a React + TypeScript component library with consistent design tokens, theming, and accessibility standards for developer productivity SaaS dashboards.

## Purpose

This skill defines the architecture, conventions, and quality standards for a shared design system that powers all frontend surfaces of the platform. It ensures visual consistency, accessibility compliance, and developer ergonomics across micro-frontends served by the BFF layer.

The design system is consumed by multiple React micro-frontends that each communicate with their own BFF (Backend for Frontend) Spring Boot service. Components must be framework-agnostic in their styling approach and independently versionable.

## When to Use

- Creating new UI components for any frontend module
- Modifying existing design tokens (colors, spacing, typography, elevation)
- Adding or updating theme variants (light, dark, high-contrast)
- Building compound or polymorphic components
- Writing Storybook stories or visual regression tests
- Reviewing component API surface for consistency
- Implementing responsive layouts for dashboard views
- Auditing accessibility compliance of interactive components

## Design Token Structure

### Token Hierarchy

Design tokens follow a three-tier hierarchy. Never skip tiers or reference raw values directly in components.

```
Global Tokens (raw values)
  -> Alias Tokens (semantic meaning)
    -> Component Tokens (component-specific overrides)
```

### Color Tokens

Define all colors as global tokens in `src/design-tokens/colors.ts`. Use HSL format for easier programmatic manipulation.

```typescript
// src/design-tokens/colors.ts
export const globalColors = {
  blue: {
    50: 'hsl(214, 100%, 97%)',
    100: 'hsl(214, 95%, 93%)',
    200: 'hsl(213, 97%, 87%)',
    300: 'hsl(212, 96%, 78%)',
    400: 'hsl(213, 94%, 68%)',
    500: 'hsl(217, 91%, 60%)',
    600: 'hsl(221, 83%, 53%)',
    700: 'hsl(224, 76%, 48%)',
    800: 'hsl(226, 71%, 40%)',
    900: 'hsl(224, 64%, 33%)',
    950: 'hsl(226, 57%, 21%)',
  },
  // ... neutral, red, amber, green, violet palettes follow same pattern
} as const;
```

Map global tokens to semantic alias tokens:

```typescript
// src/design-tokens/aliases.ts
export const aliasTokens = {
  color: {
    bg: {
      primary: 'var(--color-neutral-0)',
      secondary: 'var(--color-neutral-50)',
      tertiary: 'var(--color-neutral-100)',
      inverse: 'var(--color-neutral-900)',
      brand: 'var(--color-blue-600)',
      danger: 'var(--color-red-50)',
      warning: 'var(--color-amber-50)',
      success: 'var(--color-green-50)',
      info: 'var(--color-blue-50)',
    },
    text: {
      primary: 'var(--color-neutral-900)',
      secondary: 'var(--color-neutral-600)',
      tertiary: 'var(--color-neutral-500)',
      inverse: 'var(--color-neutral-0)',
      brand: 'var(--color-blue-600)',
      danger: 'var(--color-red-700)',
      link: 'var(--color-blue-600)',
      linkHover: 'var(--color-blue-800)',
    },
    border: {
      default: 'var(--color-neutral-200)',
      strong: 'var(--color-neutral-400)',
      brand: 'var(--color-blue-600)',
      danger: 'var(--color-red-300)',
      focus: 'var(--color-blue-500)',
    },
  },
} as const;
```

### Spacing Scale

Use a base-4 spacing scale. Expose as both CSS custom properties and a TypeScript constant map.

```typescript
// src/design-tokens/spacing.ts
export const spacing = {
  0: '0px',
  1: '4px',
  2: '8px',
  3: '12px',
  4: '16px',
  5: '20px',
  6: '24px',
  8: '32px',
  10: '40px',
  12: '48px',
  16: '64px',
  20: '80px',
  24: '96px',
} as const;

export type SpacingKey = keyof typeof spacing;
```

### Typography Scale

Define a type-safe typography scale. All font sizes use `rem` units. Line heights are unitless ratios.

```typescript
// src/design-tokens/typography.ts
export const typography = {
  fontFamily: {
    sans: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
    mono: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
  },
  fontSize: {
    xs: '0.75rem',    // 12px
    sm: '0.875rem',   // 14px
    base: '1rem',     // 16px
    lg: '1.125rem',   // 18px
    xl: '1.25rem',    // 20px
    '2xl': '1.5rem',  // 24px
    '3xl': '1.875rem',// 30px
    '4xl': '2.25rem', // 36px
  },
  fontWeight: {
    regular: '400',
    medium: '500',
    semibold: '600',
    bold: '700',
  },
  lineHeight: {
    tight: '1.25',
    normal: '1.5',
    relaxed: '1.75',
  },
  letterSpacing: {
    tight: '-0.025em',
    normal: '0em',
    wide: '0.025em',
  },
} as const;
```

### Elevation (Shadows)

```typescript
export const elevation = {
  none: 'none',
  sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  base: '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
  md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)',
  lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)',
  xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
  inner: 'inset 0 2px 4px 0 rgba(0, 0, 0, 0.05)',
} as const;
```

## Responsive Breakpoints

Target dashboard layouts across these breakpoints. Mobile-first approach: write base styles for small screens, then layer on with `min-width` queries.

```typescript
export const breakpoints = {
  sm: '640px',   // Large phone / small tablet
  md: '768px',   // Tablet portrait
  lg: '1024px',  // Tablet landscape / small desktop
  xl: '1280px',  // Standard desktop dashboard
  '2xl': '1536px', // Wide desktop / ultrawide
} as const;
```

Rules for responsive behavior:
- Navigation sidebar collapses to icon-only below `lg`, hidden below `md`
- Data tables switch to card layout below `md`
- Dashboard grid columns: 1 column below `sm`, 2 below `lg`, 3-4 at `xl`+
- Modal dialogs become full-screen sheets below `md`
- Form layouts switch from horizontal to stacked below `md`

## Component API Conventions

### Naming and File Structure

```
src/components/
  Button/
    Button.tsx           # Main component
    Button.types.ts      # Props interface and related types
    Button.styles.ts     # Styled-components / CSS module styles
    Button.test.tsx      # Unit and interaction tests
    Button.stories.tsx   # Storybook stories
    index.ts             # Public barrel export
  DataTable/
    DataTable.tsx
    DataTable.types.ts
    DataTableHeader.tsx    # Sub-component
    DataTableRow.tsx       # Sub-component
    DataTablePagination.tsx
    useDataTable.ts        # Hook for table state logic
    index.ts
```

### Props Interface Rules

1. Always extend native HTML element props using `ComponentPropsWithoutRef`:

```typescript
import { ComponentPropsWithoutRef, forwardRef } from 'react';

interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}
```

2. Use discriminated unions for mutually exclusive props:

```typescript
type AlertProps =
  | { dismissible: true; onDismiss: () => void }
  | { dismissible?: false; onDismiss?: never };
```

3. Boolean props must use the `is` or `has` prefix: `isDisabled`, `isLoading`, `hasError`, `isOpen`.

4. Callback props must use `on` prefix: `onChange`, `onSubmit`, `onDismiss`, `onSort`.

5. Always use `forwardRef` for components that render a single DOM element:

```typescript
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'md', isLoading, children, ...rest }, ref) => {
    return (
      <button ref={ref} disabled={isLoading} {...rest}>
        {isLoading ? <Spinner size={size} /> : children}
      </button>
    );
  }
);
Button.displayName = 'Button';
```

### Compound Component Pattern

Use compound components for complex UI structures (Tabs, Menu, DataTable, Modal). Leverage React Context for implicit state sharing.

```typescript
// Compound component with context
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (id: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabsContext() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error('Tabs compound components must be used within <Tabs>');
  return ctx;
}

function Tabs({ defaultTab, children }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div role="tablist">{children}</div>
    </TabsContext.Provider>
  );
}

function TabsTrigger({ id, children }: TabsTriggerProps) {
  const { activeTab, setActiveTab } = useTabsContext();
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabsContent({ id, children }: TabsContentProps) {
  const { activeTab } = useTabsContext();
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
}

// Attach sub-components
Tabs.Trigger = TabsTrigger;
Tabs.Content = TabsContent;
```

Usage:

```tsx
<Tabs defaultTab="overview">
  <Tabs.Trigger id="overview">Overview</Tabs.Trigger>
  <Tabs.Trigger id="metrics">Metrics</Tabs.Trigger>
  <Tabs.Content id="overview">Dashboard overview content</Tabs.Content>
  <Tabs.Content id="metrics">Metrics charts</Tabs.Content>
</Tabs>
```

### Polymorphic `as` Prop

For components that need to render as different HTML elements or other components:

```typescript
type AsProp<C extends React.ElementType> = {
  as?: C;
};

type PropsToOmit<C extends React.ElementType, P> = keyof (AsProp<C> & P);

type PolymorphicComponentProps<
  C extends React.ElementType,
  Props = {}
> = React.PropsWithChildren<Props & AsProp<C>> &
  Omit<React.ComponentPropsWithoutRef<C>, PropsToOmit<C, Props>>;
```

## Dark Mode and Theming

### Theme Structure

Themes override alias tokens via CSS custom properties on a data attribute selector.

```css
/* Light theme (default) */
:root, [data-theme='light'] {
  --color-bg-primary: hsl(0, 0%, 100%);
  --color-bg-secondary: hsl(210, 40%, 98%);
  --color-text-primary: hsl(224, 64%, 12%);
  --color-text-secondary: hsl(220, 9%, 43%);
  --color-border-default: hsl(220, 13%, 91%);
  /* ... all alias tokens */
}

/* Dark theme */
[data-theme='dark'] {
  --color-bg-primary: hsl(224, 30%, 10%);
  --color-bg-secondary: hsl(224, 25%, 14%);
  --color-text-primary: hsl(210, 40%, 96%);
  --color-text-secondary: hsl(215, 16%, 65%);
  --color-border-default: hsl(217, 19%, 24%);
  /* ... all alias tokens */
}

/* High contrast theme */
[data-theme='high-contrast'] {
  --color-bg-primary: hsl(0, 0%, 0%);
  --color-text-primary: hsl(0, 0%, 100%);
  --color-border-default: hsl(0, 0%, 100%);
  /* ... all alias tokens */
}
```

### Theme Provider

```typescript
// src/themes/ThemeProvider.tsx
type Theme = 'light' | 'dark' | 'high-contrast' | 'system';

interface ThemeContextValue {
  theme: Theme;
  resolvedTheme: Exclude<Theme, 'system'>;
  setTheme: (theme: Theme) => void;
}

export function ThemeProvider({ children, defaultTheme = 'system' }: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(defaultTheme);
  const systemPreference = useMediaQuery('(prefers-color-scheme: dark)');

  const resolvedTheme = theme === 'system'
    ? (systemPreference ? 'dark' : 'light')
    : theme;

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', resolvedTheme);
  }, [resolvedTheme]);

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
```

Rules:
- Never use hardcoded color values in components. Always reference CSS custom properties or alias tokens.
- Test every component in all three themes before merging.
- Shadows and elevation must also be theme-aware (dark theme uses lighter, more subtle shadows).
- Charts and data visualizations must use a dedicated palette that meets WCAG AA contrast in both light and dark themes.

## Accessibility Requirements

### Minimum Standards

All components must meet WCAG 2.1 Level AA. The following are non-negotiable:

1. **Color contrast**: Minimum 4.5:1 for normal text, 3:1 for large text (18px+ or 14px+ bold), 3:1 for UI components and graphical objects.

2. **Keyboard navigation**: Every interactive element must be operable via keyboard. Tab order must follow logical reading order. Focus must be visible with a 2px solid outline using `var(--color-border-focus)`.

3. **Focus management**: When modals open, trap focus inside. When modals close, return focus to the trigger element. When items are deleted from a list, move focus to the next logical item.

4. **Screen reader support**: Use semantic HTML elements first (`button`, `nav`, `main`, `section`, `table`). Add ARIA attributes only when semantic HTML is insufficient. Never use `div` with `onClick` as a button substitute.

5. **Motion**: Respect `prefers-reduced-motion`. Wrap all animations and transitions:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Required ARIA Patterns by Component Type

| Component | Required ARIA | Notes |
|-----------|--------------|-------|
| Modal / Dialog | `role="dialog"`, `aria-modal="true"`, `aria-labelledby` | Must trap focus |
| Dropdown Menu | `role="menu"`, `role="menuitem"`, `aria-expanded` | Arrow key navigation |
| Tabs | `role="tablist"`, `role="tab"`, `role="tabpanel"`, `aria-selected` | Arrow keys to switch |
| Toast / Alert | `role="alert"` or `role="status"`, `aria-live` | `assertive` for errors, `polite` for info |
| Data Table | `role="grid"` or semantic `<table>`, `aria-sort`, `aria-label` | Sortable headers announced |
| Combobox | `role="combobox"`, `aria-expanded`, `aria-activedescendant` | Full keyboard support |
| Toggle | `role="switch"`, `aria-checked` | Not `role="checkbox"` |
| Progress | `role="progressbar"`, `aria-valuenow`, `aria-valuemin`, `aria-valuemax` | Include text label |

### Testing Accessibility

Every component PR must include:
- `axe-core` automated scan via `jest-axe` (zero violations)
- Manual keyboard navigation verification
- Screen reader announcement verification for interactive state changes
- Color contrast check for all theme variants

```typescript
// Example accessibility test
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

it('should have no accessibility violations', async () => {
  const { container } = render(
    <Button variant="primary">Submit</Button>
  );
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## Storybook Conventions

### Story File Structure

Every component must have a Storybook story file. Use Component Story Format (CSF) 3.

```typescript
// Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Actions/Button',
  component: Button,
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'ghost', 'danger'],
      description: 'Visual style variant',
      table: { defaultValue: { summary: 'primary' } },
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
      table: { defaultValue: { summary: 'md' } },
    },
    isLoading: { control: 'boolean' },
    isDisabled: { control: 'boolean' },
  },
  args: {
    children: 'Button',
    variant: 'primary',
    size: 'md',
  },
};
export default meta;

type Story = StoryObj<typeof Button>;

export const Default: Story = {};

export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="ghost">Ghost</Button>
      <Button variant="danger">Danger</Button>
    </div>
  ),
};

export const Loading: Story = {
  args: { isLoading: true },
};
```

### Story Organization

Stories are organized by atomic design level:

```
Components/
  Primitives/     -> Button, Input, Badge, Avatar, Spinner
  Feedback/       -> Alert, Toast, ProgressBar, Skeleton
  Navigation/     -> Tabs, Breadcrumb, Sidebar, Pagination
  Data Display/   -> DataTable, Card, Stat, Chart
  Overlays/       -> Modal, Drawer, Popover, Tooltip, DropdownMenu
  Forms/          -> Select, Combobox, DatePicker, Checkbox, RadioGroup
  Layout/         -> Stack, Grid, Container, Divider
Patterns/         -> Composed patterns (SearchableTable, FilterBar)
Pages/            -> Full page compositions for visual regression
```

### Required Addons and Checks

- `@storybook/addon-a11y`: Accessibility panel must show zero violations for every story.
- `@storybook/addon-viewport`: Include stories for mobile and tablet viewports.
- `chromatic`: Visual regression testing connected to PR pipeline via GitHub Actions.

## Examples

### Example: Creating a New StatusBadge Component

1. Create the file structure under `src/components/StatusBadge/`.
2. Define the props interface using semantic status values:

```typescript
interface StatusBadgeProps extends ComponentPropsWithoutRef<'span'> {
  status: 'healthy' | 'degraded' | 'down' | 'maintenance' | 'unknown';
  size?: 'sm' | 'md';
  hasIcon?: boolean;
}
```

3. Map statuses to alias tokens -- never hardcode colors:

```typescript
const statusTokenMap: Record<StatusBadgeProps['status'], { bg: string; text: string; icon: string }> = {
  healthy:     { bg: 'var(--color-bg-success)',   text: 'var(--color-text-success)',   icon: 'check-circle' },
  degraded:    { bg: 'var(--color-bg-warning)',   text: 'var(--color-text-warning)',   icon: 'alert-triangle' },
  down:        { bg: 'var(--color-bg-danger)',    text: 'var(--color-text-danger)',    icon: 'x-circle' },
  maintenance: { bg: 'var(--color-bg-info)',      text: 'var(--color-text-info)',      icon: 'wrench' },
  unknown:     { bg: 'var(--color-bg-tertiary)',  text: 'var(--color-text-tertiary)',  icon: 'help-circle' },
};
```

4. Write the component with `forwardRef`, spreading remaining props.
5. Write Storybook stories showing all statuses in both light and dark themes.
6. Write accessibility test asserting meaningful `aria-label` text for the status.
7. Verify 4.5:1 contrast ratio for badge text against badge background in all themes.

### Example: Adding a New Design Token

1. Add the raw value to the appropriate global token file.
2. Create or update the alias token referencing the global token.
3. Add the CSS custom property to both light and dark theme declarations.
4. If the token is component-specific, add a component token that references the alias.
5. Update Storybook theme decorator to verify rendering in all themes.
6. Run the full visual regression suite to catch unintended side effects.

### Example: Implementing Dark Mode for a Chart Component

1. Define a chart color palette as alias tokens with light and dark variants.
2. Use the `useTheme()` hook to pass the resolved palette to the chart library.
3. Ensure axis labels, legends, and tooltip text meet 4.5:1 contrast in both themes.
4. Grid lines and borders should use `var(--color-border-default)` -- never a raw gray.
5. Add a Storybook story with the dark theme decorator to verify visual correctness.
6. Test with `prefers-reduced-motion: reduce` to ensure chart animations are suppressed.
