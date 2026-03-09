---
name: saas-landing-page
description: Conversion-optimized landing page patterns for developer-facing SaaS products including copy frameworks, social proof placement, pricing page design, and developer-specific CTAs
version: 1.0.0
tags:
  - landing-page
  - conversion
  - marketing
  - developer-tools
  - saas
  - pricing
globs:
  - "frontend/src/pages/landing/**"
  - "frontend/src/pages/pricing/**"
  - "frontend/src/components/marketing/**"
  - "frontend/src/components/hero/**"
---

# SaaS Landing Page Patterns for Developer Tools

## Purpose

Define conversion-optimized landing page patterns specifically for developer-facing SaaS products. This skill covers above-the-fold hero design, developer-specific value propositions, code snippet showcases, interactive demos, social proof strategies, pricing page architecture, and CTA conventions. All patterns are implemented using the React + TypeScript frontend stack.

## When to Use

- Building or redesigning the product's public-facing landing page
- Creating a pricing page for free/pro/enterprise tiers
- Adding social proof elements (testimonials, logos, GitHub stats)
- Designing above-the-fold hero sections for developer tools
- Writing copy for developer-facing CTAs and value propositions
- Integrating interactive code demos or playground embeds
- Optimizing conversion funnels from landing page to signup

## Page Architecture

### URL Structure

```
/                    # Main landing page (hero, features, social proof, CTA)
/pricing             # Pricing tiers with feature comparison
/docs                # Documentation (separate app or subdomain)
/blog                # Technical content marketing
/changelog           # Product updates (builds trust with developers)
/customers           # Customer stories and case studies
```

### Landing Page Section Order

The section order follows the developer decision-making journey: understand the product, see it work, validate through peers, evaluate cost, take action.

```
1. Hero (above the fold)
2. Trusted-by logo bar
3. Problem statement / pain points
4. Product demo or code showcase
5. Feature grid (3-4 key capabilities)
6. How it works (3-step flow)
7. Integration ecosystem
8. Social proof (testimonials + metrics)
9. Pricing summary (link to full pricing page)
10. Final CTA
11. Footer (with docs, status page, GitHub links)
```

## Rules

### 1. Above-the-Fold Hero Patterns

The hero section must communicate three things in under 5 seconds: what the product does, who it is for, and how to start.

#### Hero Layout Structure

```tsx
// frontend/src/components/marketing/Hero.tsx
interface HeroProps {
  headline: string;        // 6-10 words. What outcome the product delivers.
  subheadline: string;     // 15-25 words. How it works at a high level.
  primaryCta: CtaConfig;   // "Start free" or "Try it now" - goes to signup
  secondaryCta: CtaConfig; // "View docs" or "See demo" - lower commitment
  codeSnippet?: string;    // Optional: show a real usage example
  terminalDemo?: boolean;  // Optional: animated terminal showing the product
}
```

#### Hero Copy Rules

- **Headline**: Lead with the outcome, not the technology. Developers buy solutions to problems, not feature lists.
  - Good: "Ship microservices 10x faster"
  - Bad: "Cloud-native development platform with AI-powered tooling"
- **Subheadline**: One sentence explaining the mechanism. Include the tech stack keywords developers will search for.
  - Good: "Generate production-ready Spring Boot services with built-in DDD patterns, Docker configs, and CI/CD pipelines."
  - Bad: "Our platform helps you be more productive."
- **Primary CTA**: Use action-oriented, low-friction language. Never say "Contact Sales" as the primary CTA for a developer tool.
  - Good: "Start building free", "Try it in 30 seconds", "Get started -- no credit card"
  - Bad: "Request a demo", "Contact us", "Learn more"
- **Secondary CTA**: Offer a documentation or demo path for developers who want to evaluate before signing up.
  - Good: "Read the docs", "See it in action", "View on GitHub"

#### Code-First Hero Pattern

For developer tools, showing a real code snippet in the hero is more effective than stock illustrations. Use a split layout: copy on the left, code on the right.

```tsx
<section className="hero">
  <div className="hero-copy">
    <h1>Ship microservices 10x faster</h1>
    <p>
      Generate production-ready Spring Boot services with built-in
      DDD patterns, Docker configs, and CI/CD pipelines.
    </p>
    <div className="hero-ctas">
      <Button variant="primary" href="/signup">
        Start building free
      </Button>
      <Button variant="ghost" href="/docs/quickstart">
        Read the docs
      </Button>
    </div>
  </div>
  <div className="hero-code">
    <CodeBlock
      language="bash"
      filename="terminal"
      animated={true}
      lines={[
        "$ npx create-service user-service --stack spring-boot",
        "Scaffolding user-service with DDD structure...",
        "  Created src/main/java/.../domain/User.java",
        "  Created src/main/java/.../application/UserService.java",
        "  Created Dockerfile",
        "  Created .github/workflows/ci.yml",
        "Done in 4.2s. Run: cd user-service && ./gradlew bootRun"
      ]}
    />
  </div>
</section>
```

#### Terminal Demo Pattern

An animated terminal replay showing the product in action converts better than a static screenshot. Implement with a typed animation that replays a real workflow.

Rules for terminal demos:
- Keep the replay under 15 seconds.
- Show a complete, realistic workflow from input to output.
- Use a monospace font and a dark terminal theme.
- Include a replay button so visitors can watch it again.
- Do not autoplay with sound.

### 2. Developer-Specific Value Propositions

Structure value propositions around developer pain points, not product features. Use the "Problem -> Mechanism -> Outcome" framework.

| Pain Point | Mechanism | Outcome |
|---|---|---|
| "Setting up a new microservice takes days of boilerplate" | Scaffold generator with DDD templates | "Go from zero to deployed service in under 5 minutes" |
| "CI/CD pipelines break constantly and are hard to debug" | Pre-configured GitHub Actions with health checks | "Pipelines that work on day one and never drift" |
| "Our team writes inconsistent code across services" | Shared architecture templates with linting | "Consistent, reviewable code across every service" |

Present these as a feature grid with icons, not as a wall of text.

```tsx
<section className="features-grid">
  {features.map((feature) => (
    <FeatureCard key={feature.id}>
      <FeatureIcon name={feature.icon} />
      <h3>{feature.outcome}</h3>         {/* Lead with the outcome */}
      <p>{feature.mechanism}</p>          {/* Explain how */}
      <Link to={feature.docsLink}>
        Learn more in docs
      </Link>
    </FeatureCard>
  ))}
</section>
```

### 3. Code Snippet Showcases

Developers trust products they can read the code for. Include real, runnable code examples throughout the landing page.

#### Code Showcase Rules

- Use syntax-highlighted code blocks with a visible language label.
- Show real API calls or CLI commands, not pseudocode.
- Include a "Copy" button on every code block.
- Use tabbed code blocks when showing multiple languages or frameworks.
- Keep each snippet under 15 lines. Link to docs for full examples.

```tsx
<CodeTabs defaultTab="java">
  <CodeTab label="Java" language="java">
    {`@Aggregate
public class Order {
    private OrderId id;
    private List<LineItem> items;
    private OrderStatus status;

    public void place() {
        validateItems();
        this.status = OrderStatus.PLACED;
        registerEvent(new OrderPlacedEvent(this.id));
    }
}`}
  </CodeTab>
  <CodeTab label="API" language="bash">
    {`curl -X POST https://api.example.com/v1/orders \\
  -H "Authorization: Bearer sk_live_..." \\
  -d '{"items": [{"sku": "PLAN_PRO", "qty": 1}]}'`}
  </CodeTab>
</CodeTabs>
```

### 4. Interactive Demos and Playgrounds

Offer an interactive experience that lets developers try the product without signing up. This is the highest-converting element on a developer tool landing page.

#### Implementation Options (ranked by conversion impact)

1. **Embedded playground**: An in-browser sandbox where visitors can run real commands or modify code. Implement with an iframe pointing to a sandboxed environment.
2. **Interactive configurator**: A form-based tool that generates output (e.g., "Configure your service" -> generates a project structure preview).
3. **Recorded demo with annotations**: A scripted walkthrough with step-by-step annotations. Lower engineering cost than a full playground.

#### Playground Rules

- Load time must be under 3 seconds. Use lazy loading and skeleton screens.
- Pre-populate with a realistic example so visitors see value immediately.
- Include a "Reset" button to restore the default state.
- Show a clear "Sign up to save your work" CTA after interaction.
- Do not require login or email to use the playground.

```tsx
<section className="playground">
  <h2>Try it yourself</h2>
  <p>Configure a service and see the generated project structure.</p>
  <PlaygroundEmbed
    defaultConfig={{
      serviceName: "order-service",
      stack: "spring-boot-3",
      features: ["ddd", "docker", "ci-cd", "postgres"],
    }}
    onComplete={(config) => (
      <CtaBanner>
        <p>Like what you see?</p>
        <Button href={`/signup?preset=${encodeConfig(config)}`}>
          Create this project for real
        </Button>
      </CtaBanner>
    )}
  />
</section>
```

### 5. Social Proof Strategy

Developers are skeptical of marketing claims. Social proof must be specific, verifiable, and technically credible.

#### Social Proof Hierarchy (from most to least impactful for developers)

1. **GitHub metrics**: Stars, forks, contributors, commit activity. These are verifiable and indicate real adoption.
2. **Customer logos**: Well-known tech companies using the product. Place in a "Trusted by" bar below the hero.
3. **Quantified results**: Specific metrics from real customers. "Reduced deployment time from 45 minutes to 3 minutes."
4. **Developer testimonials**: Quotes from named engineers with title, company, and photo. Attribute to real, verifiable people.
5. **Community size**: Discord/Slack member count, npm download stats.

#### Logo Bar Rules

- Show 5-8 logos maximum. More than 8 creates visual clutter.
- Use grayscale logos to avoid clashing brand colors.
- Arrange by recognition (most well-known first for left-to-right reading).
- Logos must have explicit permission. Do not use a company's logo without approval.
- Add a subtle scroll animation for mobile viewports.

```tsx
<section className="trusted-by">
  <p className="trusted-by-label">Trusted by engineering teams at</p>
  <div className="logo-bar">
    {customerLogos.map((logo) => (
      <img
        key={logo.name}
        src={logo.grayscaleSrc}
        alt={`${logo.name} logo`}
        className="customer-logo"
        loading="lazy"
      />
    ))}
  </div>
</section>
```

#### Testimonial Rules

- Include the person's full name, title, and company.
- Use a real headshot, not an avatar or stock photo.
- The quote must mention a specific, measurable outcome.
- Keep quotes under 40 words. Developers skim.
- Include 2-3 testimonials maximum on the landing page. More belong on a dedicated customers page.

```tsx
<TestimonialCard
  quote="We cut our service scaffolding time from 2 days to 15 minutes.
         The generated DDD structure matches how our senior architects
         would have designed it."
  author={{
    name: "Sarah Chen",
    title: "Staff Engineer",
    company: "Acme Corp",
    avatar: "/images/testimonials/sarah-chen.jpg",
  }}
/>
```

#### GitHub Stats Widget

For open-source or open-core products, display live GitHub stats:

```tsx
<GitHubStats repo="your-org/your-product">
  <Stat label="GitHub Stars" value={stars} icon="star" />
  <Stat label="Contributors" value={contributors} icon="users" />
  <Stat label="Weekly Downloads" value={downloads} icon="download" />
</GitHubStats>
```

Fetch stats server-side and cache for 1 hour. Do not make client-side GitHub API calls from the landing page.

### 6. Pricing Page Layout

Developer tool pricing must be transparent and self-serve. Developers will leave if they see "Contact Sales" as the only option.

#### Tier Structure

Use three tiers: Free, Pro, Enterprise. This is the standard for developer SaaS because it maps to the developer evaluation journey.

| Attribute | Free | Pro | Enterprise |
|---|---|---|---|
| **Target** | Individual developers, evaluation | Small teams, startups | Large organizations |
| **Price display** | "$0 / forever" | "$X / user / month" | "Custom" |
| **CTA** | "Start free" | "Start 14-day trial" | "Talk to us" |
| **Limit examples** | 3 projects, 1 user, community support | Unlimited projects, 10 users, email support | Unlimited everything, SSO, SLA, dedicated support |

#### Pricing Page Rules

- Show all prices. Never hide pricing behind a "Contact Sales" wall for Free and Pro tiers.
- Default to annual billing (show monthly as secondary). Display the per-month price for annual to make comparison easy.
- Highlight the recommended tier visually (usually Pro).
- Include a full feature comparison table below the tier cards.
- Add a FAQ section addressing common pricing questions.
- Show a "Free forever" label on the free tier to reduce friction.

```tsx
<section className="pricing">
  <h2>Simple, transparent pricing</h2>
  <p>Start free. Scale as your team grows. No surprises.</p>

  <BillingToggle
    value={billingCycle}
    onChange={setBillingCycle}
    annualDiscount={20}
  />

  <div className="pricing-tiers">
    <PricingCard
      tier="Free"
      price={0}
      period="forever"
      description="For individual developers exploring the platform"
      features={[
        "3 projects",
        "1 team member",
        "Community support",
        "Basic templates",
      ]}
      cta={{ label: "Start free", href: "/signup?plan=free" }}
    />
    <PricingCard
      tier="Pro"
      price={billingCycle === "annual" ? 29 : 39}
      period="per user / month"
      description="For teams shipping microservices in production"
      features={[
        "Unlimited projects",
        "Up to 25 team members",
        "Email and chat support",
        "All templates and generators",
        "CI/CD pipeline generation",
        "Custom architecture rules",
      ]}
      cta={{ label: "Start 14-day trial", href: "/signup?plan=pro" }}
      highlighted={true}
      badge="Most popular"
    />
    <PricingCard
      tier="Enterprise"
      price={null}
      period="custom"
      description="For organizations with compliance and scale requirements"
      features={[
        "Everything in Pro",
        "Unlimited team members",
        "SSO / SAML",
        "99.9% SLA",
        "Dedicated support engineer",
        "Custom integrations",
        "Audit logging",
        "On-premise deployment option",
      ]}
      cta={{ label: "Talk to us", href: "/contact-sales" }}
    />
  </div>

  <FeatureComparisonTable tiers={tiers} />
  <PricingFaq />
</section>
```

### 7. Developer-Focused CTAs

CTAs for developer tools must reduce friction and signal low commitment. Developers are wary of sales funnels.

#### CTA Hierarchy

| Position | CTA Type | Label Pattern | Destination |
|---|---|---|---|
| Hero primary | Sign up | "Start building free" | `/signup` |
| Hero secondary | Documentation | "Read the docs" | `/docs/quickstart` |
| After demo section | Try it | "Try it in your terminal" | `/docs/install` |
| After features | Learn more | "See how it works" | `/docs/architecture` |
| After pricing | Sign up | "Get started" | `/signup?plan=selected` |
| Sticky header | Sign up | "Sign up free" | `/signup` |
| Footer | Multiple | Docs, GitHub, Status, Blog | Various |

#### CTA Copy Rules

- Use verbs that imply doing, not reading: "Start building", "Deploy your first service", "Generate a project".
- Include friction reducers: "No credit card required", "Free forever", "Set up in 2 minutes".
- Never use "Submit", "Request", or "Contact" as primary CTAs.
- The primary CTA color must have a contrast ratio of at least 4.5:1 against its background.
- Use no more than one primary CTA per viewport. Multiple competing CTAs reduce conversion.

### 8. Technical Content Marketing Integration

The landing page should link naturally to technical content that builds trust and improves SEO.

#### Content Placement Rules

- Link blog posts in relevant feature sections: "Learn how we handle DDD bounded contexts" -> blog post.
- Include a "From the blog" section near the bottom with 3 recent technical posts.
- Link to the changelog from the hero or footer to show active development.
- Link to the API reference and architecture docs from the features section.

```tsx
<section className="from-the-blog">
  <h2>From the engineering blog</h2>
  <div className="blog-cards">
    {recentPosts.slice(0, 3).map((post) => (
      <BlogCard
        key={post.slug}
        title={post.title}
        excerpt={post.excerpt}
        date={post.publishedAt}
        readTime={post.readTimeMinutes}
        href={`/blog/${post.slug}`}
      />
    ))}
  </div>
</section>
```

### 9. Performance Requirements

Landing page performance directly impacts conversion rates. Every 100ms of load time reduces conversion by approximately 1%.

| Metric | Target |
|---|---|
| Largest Contentful Paint (LCP) | < 2.5 seconds |
| First Input Delay (FID) | < 100 milliseconds |
| Cumulative Layout Shift (CLS) | < 0.1 |
| Time to Interactive (TTI) | < 3.5 seconds |
| Total page weight | < 500 KB (compressed) |

Rules:
- Lazy load all images below the fold.
- Use `next/image` or equivalent for automatic image optimization.
- Inline critical CSS for above-the-fold content.
- Defer non-essential JavaScript (analytics, chat widgets).
- Preload the hero font to prevent FOUT.
- Serve static assets from a CDN.

## Examples

### Example: Landing Page Component Structure

```
frontend/src/pages/landing/
  LandingPage.tsx              # Page component, assembles sections
  sections/
    HeroSection.tsx            # Above-the-fold hero with code demo
    TrustedBySection.tsx       # Customer logo bar
    ProblemSection.tsx         # Pain point articulation
    ProductDemoSection.tsx     # Interactive demo or video
    FeaturesGridSection.tsx    # 3-4 key feature cards
    HowItWorksSection.tsx      # 3-step numbered flow
    IntegrationsSection.tsx    # Supported tools and platforms
    TestimonialsSection.tsx    # Customer quotes with metrics
    PricingSummarySection.tsx  # Condensed pricing with link to /pricing
    FinalCtaSection.tsx        # Full-width CTA banner
  components/
    CodeBlock.tsx              # Syntax-highlighted code with copy button
    CodeTabs.tsx               # Tabbed code examples
    TerminalReplay.tsx         # Animated terminal demo
    FeatureCard.tsx            # Icon + outcome + mechanism card
    TestimonialCard.tsx        # Quote + author attribution
    PricingCard.tsx            # Tier card with features list
    BillingToggle.tsx          # Monthly/annual toggle
    GitHubStats.tsx            # Live GitHub star/fork counts
    BlogCard.tsx               # Blog post preview card
```

### Example: A/B Testing Key Elements

Prioritize A/B tests on these high-impact elements:

1. **Hero headline**: Test outcome-focused vs. mechanism-focused headlines.
2. **Primary CTA label**: Test "Start free" vs. "Try it now" vs. "Get started".
3. **Social proof placement**: Test logo bar immediately below hero vs. after features.
4. **Pricing default**: Test annual-first vs. monthly-first display.
5. **Code demo vs. video**: Test an interactive code snippet vs. a product walkthrough video in the hero.

Track conversion as signup completion, not just CTA click.

### Example: Mobile Responsiveness Rules

- Hero: Stack copy above code demo on screens below 768px. Reduce code snippet to 5 lines.
- Logo bar: Convert to a horizontal scroll carousel on mobile.
- Feature grid: Stack cards vertically on mobile with 1 card per row.
- Pricing: Stack tier cards vertically with the highlighted tier first.
- Sticky CTA: Show a fixed bottom bar with the primary CTA on mobile viewports.
- Terminal demo: Use a smaller font size (12px) and reduce animation speed for readability.
