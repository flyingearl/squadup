# Herd X Clone

A Twitter/X-like social platform built with Laravel, Vue 3, TypeScript, and Inertia.js. A modern SPA featuring real-time interactions, authentication with Fortify, and comprehensive testing with Pest.

## Tech Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Runtime | PHP | 8.3+ | Backend application runtime |
| Framework | Laravel | 13.x | Backend framework |
| Frontend Framework | Vue | 3.x | Reactive UI components |
| Type Safety | TypeScript | 5.x | Static typing |
| Build Tool | Vite | 8.x | Fast dev server and bundling |
| SPA Framework | Inertia.js | 3.x | Server-side routing with client rendering |
| Authentication | Laravel Fortify | 1.34+ | Frontend-agnostic auth backend |
| Styling | Tailwind CSS | 4.x | Utility-first CSS |
| Route Generation | Laravel Wayfinder | 0.1.14+ | Type-safe controller/route imports |
| Component Library | Reka UI | 2.x | Headless Vue components |
| Testing | Pest | 4.x | PHP testing framework |
| Dev Tools | Laravel Boost | 2.2+ | Development utilities and improvements |
| Code Formatting | Pint | 1.27+ | PHP code formatter |

## Quick Start

**Prerequisites:** PHP 8.3+, Node.js 18+, Composer, npm

```bash
# Clone and install
git clone <repo>
cd x-clone
composer install
npm install

# Setup environment
cp .env.example .env
php artisan key:generate

# Database
php artisan migrate

# Development - starts Laravel server, queue, logs, and Vite dev server
composer run dev

# Run tests
php artisan test

# Format code
composer run lint
```

**Access the app:** https://x-clone.test (served by Laravel Herd)

## Project Structure

```
project/
├── app/                           # Laravel backend
│   ├── Actions/                   # Fortify actions (auth, profile updates)
│   ├── Http/
│   │   ├── Controllers/           # Route controllers
│   │   ├── Requests/              # Form validation requests
│   │   └── Middleware/            # Custom middleware
│   ├── Models/                    # Eloquent models
│   ├── Concerns/                  # Traits for model concerns
│   └── Providers/                 # Service providers
├── resources/
│   ├── js/
│   │   ├── app.ts                 # Application entry point
│   │   ├── pages/                 # Inertia page components (routed)
│   │   │   ├── Dashboard.vue      # PascalCase
│   │   │   ├── Welcome.vue
│   │   │   ├── auth/              # Auth pages (login, register, etc.)
│   │   │   └── settings/          # Settings pages
│   │   ├── layouts/               # Layout wrapper components
│   │   ├── components/            # Reusable components (PascalCase)
│   │   │   └── ui/                # Reka UI headless components
│   │   ├── composables/           # Vue composables (useXxx pattern)
│   │   ├── lib/                   # Utility functions (camelCase)
│   │   ├── types/                 # TypeScript type definitions
│   │   └── wayfinder/             # Generated route/action types
│   └── css/                       # Global styles (Tailwind)
├── routes/
│   ├── web.php                    # Web routes (uses Inertia::render)
│   └── settings.php               # Settings sub-routes
├── tests/                         # Pest test suite
│   ├── Feature/                   # Feature tests
│   └── Unit/                      # Unit tests
├── database/
│   ├── migrations/                # Schema migrations
│   ├── factories/                 # Model factories
│   └── seeders/                   # Database seeders
├── config/                        # Laravel configuration
├── vite.config.ts                 # Vite bundler config (includes Tailwind, Vue, Wayfinder)
├── tsconfig.json                  # TypeScript config (path alias: @/ → resources/js/)
├── package.json                   # NPM dependencies
└── composer.json                  # PHP dependencies
```

## Architecture Overview

This is a modern Laravel SPA (Single Page Application) built with Inertia.js, separating frontend and backend concerns:

- **Backend (Laravel):** Web routes use `Inertia::render('PageName', [props])` to render Vue components. Fortify handles all authentication flows. Wayfinder auto-generates type-safe route/action imports.
- **Frontend (Vue 3 + TypeScript):** Components live in `resources/js/`. Pages (in `pages/`) are routed by Laravel and rendered by Inertia. Composables provide reusable logic. Path alias `@/` maps to `resources/js/`.
- **Database:** SQLite for development, configurable for production.
- **Build:** Vite bundles Vue, TypeScript, and Tailwind CSS. Dev server watches for changes.

### Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| Authentication | `app/Actions/Fortify/`, Routes | Login, registration, 2FA, password reset, email verification |
| Pages | `resources/js/pages/` | Inertia page components (routed by Laravel) |
| Components | `resources/js/components/` | Reusable Vue components (not routed) |
| Composables | `resources/js/composables/` | Reusable stateful logic (e.g., `useCurrentUrl`, `useAuth`) |
| Types | `resources/js/types/` | TypeScript type definitions and interfaces |
| Lib | `resources/js/lib/` | Utility functions (e.g., `flashToast.ts`, `utils.ts`) |

## Code Conventions

### Frontend (Vue/TypeScript)

**File Naming:**
- Vue components: `PascalCase` (e.g., `UserProfile.vue`, `SidebarHeader.vue`)
- Pages (in `resources/js/pages/`): `PascalCase` (e.g., `Dashboard.vue`, `Welcome.vue`)
- Composables: camelCase with `use` prefix (e.g., `useAuth.ts`, `useCurrentUrl.ts`)
- Utilities/lib: camelCase (e.g., `flashToast.ts`, `utils.ts`)
- Type files: camelCase with PascalCase exports (e.g., `auth.ts` exports `type User`, `type AuthState`)

**Code Naming:**
- Component names: `PascalCase` (`export function UserProfile`)
- Composable functions: camelCase with `use` prefix (`export function useAuth()`)
- Regular functions: camelCase (`function formatDate()`)
- Variables: camelCase (`const userData`, `const isLoading`)
- Constants: `SCREAMING_SNAKE_CASE` (`const MAX_ITEMS = 10`)
- Props: Use `type Props` with PascalCase interface name
- Boolean variables: prefix with `is`, `has`, `should` (`isLoading`, `hasPermission`, `shouldUpdate`)

**Import Order:**
1. External libraries (Vue, Inertia, etc.)
2. Internal absolute imports (`@/`)
3. Relative imports
4. Type imports (use `type` keyword): `import type { User }`

**Example Component:**
```vue
<script setup lang="ts">
import type { BreadcrumbItem } from '@/types';
import { computed } from 'vue';
import Breadcrumbs from '@/components/Breadcrumbs.vue';

type Props = {
    items: BreadcrumbItem[];
};

defineProps<Props>();
const hasItems = computed(() => items.length > 0);
</script>
```

### Backend (Laravel/PHP)

Follow Laravel conventions plus:
- Controllers: `PascalCase` (e.g., `UserController.php`)
- Models: `PascalCase` (e.g., `User.php`, `Post.php`)
- Routes: Use named routes (`route('dashboard')`) and `Route::inertia()` for pages
- Actions: `PascalCase` in `app/Actions/` (Fortify convention)
- Always use curly braces for control structures, even single-line
- Use PHP 8 constructor property promotion: `public function __construct(public UserRepository $repo) {}`
- Explicit return types on all methods: `function getData(): array`

## Development Guidelines

### Path Aliases
- `@/` resolves to `resources/js/` (defined in `tsconfig.json` and Vite config)
- Always use `@/` for frontend imports, never relative paths like `../../../`

### Styling
- Use Tailwind CSS utility classes directly in Vue templates
- Leverage Reka UI headless components from `@/components/ui/`
- Dark mode support via Tailwind's dark mode utilities

### Type Safety
- Enable TypeScript strict mode in all files
- Use `type` keyword for type imports: `import type { User }`
- Define prop types with `type Props` interface in components
- Export types from dedicated type files in `resources/js/types/`

### Running Commands

| Command | Purpose |
|---------|---------|
| `composer run dev` | Start dev server (Laravel + Vite + queue + logs) |
| `npm run dev` | Start Vite dev server only |
| `npm run build` | Build for production |
| `npm run format` | Format frontend code with Prettier |
| `npm run lint` | Lint frontend code with ESLint |
| `npm run types:check` | Type-check without emitting |
| `php artisan test` | Run all Pest tests |
| `php artisan test --compact` | Run tests with minimal output |
| `php artisan test --filter=TestName` | Run specific test |
| `php artisan route:list` | List all routes |
| `php artisan tinker` | Interactive PHP shell |
| `composer run lint` | Format PHP code with Pint |

## Testing

- **Location:** `tests/Feature/` and `tests/Unit/`
- **Framework:** Pest 4.x
- **Creation:** `php artisan make:test --pest FeatureName`
- **Running:** `php artisan test --compact` (recommended)
- **Every change must be tested** — write or update tests before finalizing
- **Use factories** for test data setup (check for custom states)
- **Use RefreshDatabase** trait for feature tests to reset DB between tests

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_NAME` | Yes | Application name |
| `APP_ENV` | Yes | Environment (local, production) |
| `APP_KEY` | Yes | Encryption key (generated by `php artisan key:generate`) |
| `APP_DEBUG` | Yes | Debug mode (true/false) |
| `DB_CONNECTION` | Yes | Database driver (sqlite, mysql, pgsql) |
| `VITE_APP_NAME` | No | Frontend app name |

See `.env.example` for all available variables.

## Key Features to Know

### Inertia.js Integration
- Routes return `Inertia::render('PageName', [...props])`
- Pages are Vue components in `resources/js/pages/`
- Layout wrapping configured in `app.ts` based on page name
- Use `<Link href="">` for client-side navigation
- Use `<Form>` for form handling with validation errors
- Built-in `useForm()` hook for form state management

### Fortify Authentication
- All auth routes auto-registered by Fortify
- Customizable actions in `app/Actions/Fortify/`
- Two-factor authentication (TOTP) support
- Email verification flow
- Login/register/password reset flows included
- Activate `fortify-development` skill for auth work

### Laravel Wayfinder
- Auto-generates TypeScript route/action functions
- Import from `@/actions/` (for controller actions) or `@/routes/` (for named routes)
- Run `php artisan wayfinder:generate` if types go stale
- Provides full IDE autocomplete and type checking
- Activate `wayfinder-development` skill when wiring frontend to backend

### Skill Activation Requirements

**`fortify-development`** — Activate when working on: login, registration, password reset, email verification, 2FA, profile updates, auth guards, or any auth-related routes/controllers.

**`laravel-best-practices`** — Activate when writing/reviewing: controllers, models, migrations, form requests, policies, jobs, queries, or any PHP code patterns.

**`inertia-vue-development`** — Activate when creating: Vue pages, forms, navigation, deferred props, prefetching, optimistic updates, or instant visits.

**`tailwindcss-development`** — Activate when building: responsive layouts, grid/flex structures, styling components, dark mode, or adjusting spacing/typography.

---

## Laravel Boost Guidelines

The following guidelines are curated by Laravel maintainers for this application and should be followed closely.

### Foundational Context

This application uses these core packages and versions:

- php: 8.3+
- laravel/framework: 13.x
- inertiajs/inertia-laravel: 3.x
- laravel/fortify: 1.x
- laravel/wayfinder: 0.x
- laravel/boost: 2.x
- pestphp/pest: 4.x
- vue: 3.x
- tailwindcss: 4.x
- typescript: 5.x

### Conventions

- Follow all existing code conventions when creating or editing files — check sibling files for patterns
- Use descriptive names: `isRegisteredForDiscounts`, not `discount()`
- Check for existing components to reuse before writing new ones
- Don't create verification scripts when tests already cover functionality
- Don't change dependencies without approval
- Don't create new base directories without approval

### Frontend Bundling

If frontend changes don't appear in the UI, the user needs to run `npm run build`, `npm run dev`, or `composer run dev`.

### Documentation

Only create documentation files if explicitly requested.

### Replies

Be concise — focus on what's important rather than explaining obvious details.

---

## Laravel Boost Tools

[Laravel Boost](https://laravel.com/docs/boost) provides MCP tools designed for this application. Prefer these over manual alternatives:

- **`database-query`** — Run read-only queries instead of writing raw SQL in tinker
- **`database-schema`** — Inspect table structure before writing migrations or models
- **`get-absolute-url`** — Resolve correct scheme, domain, and port for project URLs (always use before sharing URLs)
- **`browser-logs`** — Read browser logs, errors, and exceptions (recent logs only)
- **`search-docs`** — Search version-specific documentation (ALWAYS use before making code changes)

### Searching Documentation

**Always use `search-docs` before making code changes.** It returns version-specific docs based on installed packages.

**Search Syntax:**
- Words use AND logic: `rate limit` matches both "rate" AND "limit"
- Quoted phrases match exact position: `"infinite scroll"` requires adjacent words
- Multiple queries use OR logic: `["authentication", "middleware"]`
- Don't add package names — they're already known

Example queries: `['rate limiting', 'routing rate limiting', 'routing']`

### Artisan Commands

- List commands: `php artisan list`
- Get command help: `php artisan [command] --help`
- View routes: `php artisan route:list` (filters: `--method=GET`, `--name=users`, `--path=api`)
- Check config: `php artisan config:show app.name`
- Check env: read `.env` directly

### Tinker

- Execute PHP in app context: `php artisan tinker --execute 'Code::here();'`
- Always use single quotes to prevent shell expansion
- Use double quotes for PHP strings inside: `php artisan tinker --execute 'User::where("active", true)->count();'`
- Prefer factories over manual model creation
- Prefer existing Artisan commands over custom tinker code

---

## PHP Conventions

- Always use curly braces for control structures, even single-line bodies
- Use PHP 8 constructor property promotion: `public function __construct(public GitHub $github) {}`
- Explicit return types and type hints: `function isAccessible(User $user, ?string $path = null): bool`
- Enum keys use TitleCase: `FavoritePerson`, `BestLake`, `Monthly`
- Prefer PHPDoc blocks over inline comments (inline only for exceptionally complex logic)
- Use array shape type definitions in PHPDoc blocks

---

## Code Formatter

If you modify PHP files, run Pint before finalizing:

```bash
vendor/bin/pint --dirty --format agent
```

(Not `--test`, just `--format agent` to fix issues)

---

## Deployment

Deploy using [Laravel Cloud](https://cloud.laravel.com/) for easiest production setup.

### Pre-Deployment

```bash
npm run build                    # Build frontend
php artisan migrate --force      # Run migrations
```

Set `APP_ENV=production` and `APP_DEBUG=false` in production.

---

## Inertia.js v3 Specifics

**New v3 Features:**
- Standalone HTTP requests: `useHttp()` hook
- Optimistic updates with automatic rollback
- Layout props: `useLayoutProps()` hook
- Instant visits
- Simplified SSR via `@inertiajs/vite` plugin
- Custom exception handling for error pages

**Carried Over from v2:**
- Deferred props (add empty state with animated skeleton)
- Infinite scroll
- Merging props
- Polling, prefetching, once props, flash data

**Removed from v2:**
- Axios (use built-in XHR client or install separately)
- `Inertia::lazy()` / `LazyProp` (use `Inertia::optional()` instead)

**Event Renames:**
- `invalid` → `httpException`
- `exception` → `networkError`
- `router.cancel()` → `router.cancelAll()`

---

## Laravel Best Practices

### Do Things the Laravel Way

- Use `php artisan make:` for creating files (migrations, controllers, models, etc.)
  - Pass `--no-interaction` to ensure non-interactive execution
  - Pass correct options to ensure correct behavior
- For generic PHP classes: `php artisan make:class`

### Models & Migrations

When creating new models, also create factories and seeders. Ask users if they need additional features using `php artisan make:model --help`.

### APIs & Resources

Default to Eloquent API Resources and API versioning unless existing routes suggest otherwise (then follow existing convention).

### URL Generation

Prefer named routes and the `route()` function over hardcoded URLs.

### Testing Guidelines

- Use model factories for test data (check for custom states before manually setting up)
- Faker: Use `$this->faker->word()` or `fake()->randomDigit()` (follow existing conventions)
- Create feature tests by default: `php artisan make:test FeatureName`
- Create unit tests with `--unit` flag: `php artisan make:test --unit FeatureName`

### Error Handling

If you see "Unable to locate file in Vite manifest" error: run `npm run build` or ask user to run `npm run dev` or `composer run dev`.

---

## Pest Testing

This project uses Pest for testing.

- Create tests: `php artisan make:test --pest FeatureName`
- Run tests: `php artisan test --compact` or filter: `php artisan test --compact --filter=testName`
- Do NOT delete tests without approval

**Features Covered:** test()/it()/expect() syntax, datasets, mocking, browser testing (visit/click/fill), smoke testing, arch(), RefreshDatabase, all Pest 4 features.

**Not Covered:** factories, seeders, migrations, controllers, models, or non-test PHP code.

---

## Laravel Herd

The application is served by Laravel Herd (always available, no need to run serve commands):

- Development URL: `https://x-clone.test`
- Manage via `herd` CLI: `herd sites`, `herd services:start <service>`, `herd php:list`
- List commands: `herd list`
- Generate URLs with `get-absolute-url` tool before sharing

---

## Vue 3 + Inertia

Vue components must have a single root element.

When working with Inertia Vue patterns (pages, forms, navigation, `<Link>`, `<Form>`, `useForm()`, `useHttp()`, `setLayoutProps()`, deferred props, prefetching, optimistic updates, instant visits, polling), **activate the `inertia-vue-development` skill**.

---

## Additional Resources

- [Laravel Documentation](https://laravel.com/docs)
- [Inertia.js Vue 3 Documentation](https://inertiajs.com/)
- [Vue 3 Documentation](https://vuejs.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Laravel Fortify Documentation](https://laravel.com/docs/fortify)
- [Laravel Wayfinder Documentation](https://laravel.com/docs/wayfinder)
- [Pest Documentation](https://pestphp.com/)
- [Laravel Boost Documentation](https://laravel.com/docs/boost)


## Skill Usage Guide

When working on tasks involving these technologies, invoke the corresponding skill:

| Skill | Invoke When |
|-------|-------------|
| php | Writes PHP 8.3+ code with modern syntax and static type hints |
| inertia | Integrates Inertia.js for server-side routing with client-side rendering |
| laravel | Builds Laravel applications with controllers, models, migrations, and routing |
| typescript | Enforces type safety with TypeScript strict mode and type definitions |
| vite | Configures Vite for fast builds, hot module replacement, and bundling |
| vue | Develops Vue 3 components with composition API and TypeScript support |
| pest | Writes Pest tests with assertions, datasets, mocking, and browser testing |
| tailwindcss | Applies Tailwind CSS utility-first styling and responsive design |
| wayfinder | Generates type-safe route and action imports from Laravel routes |
| fortify | Implements Laravel Fortify authentication with 2FA and email verification |
| frontend-design | Designs Vue UIs with Tailwind CSS, responsive grids, and dark mode |
| mapping-user-journeys | Maps in-app journeys and identifies friction points in code |
| designing-onboarding-paths | Designs onboarding paths, checklists, and first-run UI |
| orchestrating-feature-adoption | Plans feature discovery, nudges, and adoption flows |
| clarifying-market-fit | Aligns ICP, positioning, and value narrative for on-page messaging |
| reka-ui | Uses Reka UI headless components for building Vue interfaces |
| instrumenting-product-metrics | Defines product events, funnels, and activation metrics |
| structuring-offer-ladders | Frames plan tiers, value ladders, and upgrade logic |
| mapping-conversion-events | Defines funnel events, tracking, and success signals |
| tuning-landing-journeys | Improves landing page flow, hierarchy, and conversion paths |
| crafting-page-messaging | Writes conversion-focused messaging for pages and key CTAs |
| inspecting-search-coverage | Audits technical and on-page search coverage |
| adding-structured-signals | Adds structured data for rich results |
