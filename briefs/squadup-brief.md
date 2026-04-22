# Project Brief — SquadUp

**Date:** 2026-04-22
**Status:** Approved (pending Phase 0 kickoff)
**Owner:** Ed (solo)
**Type:** Portfolio piece (B), keep genuine-product option (C) open

---

## Problem

Gamers who want to play *with other people* — clan members, squad mates, duo partners — have no single social surface built for coordination. They scatter across Discord servers, Reddit threads, in-game LFG tools, and Twitter, none of which are designed around the primitives that matter: *which game, which role, which rank, when are you free, and are you actually online right now?*

Existing platforms optimise for broadcast (Twitter/X), chat (Discord), or matchmaking-inside-one-game (in-game LFG). None combine a social timeline with teammate-finding as a first-class action.

## Solution

A Twitter/X-shaped social platform where every user is a **player profile** and every post can optionally be a **"Looking For Group" (LFG) signal** tied to a specific game, role, rank range, and time window.

One-sentence positioning test:

> For gamers who want to play with other people, **SquadUp** is the social network that turns every post into a potential teammate-match, unlike Discord or Twitter because the profile and feed are structured around *what you play, when, and with whom*.

## Target User (ICP)

**Primary:** Competitive and semi-competitive PC/console gamers, 18-34, who play team-based games (MOBAs, tactical shooters, MMOs, co-op RPGs) and actively want to find regular teammates rather than solo-queue.

**Not the ICP:** Casual single-player gamers, esports spectators, streamers building audience, or game developers. (Those are adjacent and could be later tiers — not now.)

**Assumed behaviour:**
- Already active in one or more Discords
- Frustrated with Discord's discoverability (joining random servers hoping to find their people)
- Willing to declare game(s), role(s), rank(s), and availability publicly
- Mostly self-reported data — no initial integration with Riot/Steam/Xbox APIs

> **Assumption flagged:** Self-reported profile data is sufficient for v1. API integrations with game platforms would increase credibility but add significant scope. Deferred to a later phase.

## Success Criteria

This is a portfolio project, so "success" is split across two axes:

**As a portfolio artefact (primary):**
- A running public URL a recruiter can click through
- A `docker-compose.yml` that a reviewer can `docker compose up` locally and get a working clone in under 5 minutes
- Source code that demonstrates production-grade Laravel + Vue + Inertia patterns: tests, type safety, real-time, queues, load balancing
- A clear README with architecture diagram
- Ship within 8-12 weeks of part-time work

**As a product (secondary, only if B→C unlocks):**
- 50+ real users finding teammates they actually played with
- Retention signal: users returning in week 2+

Both require the same feature set. The *polish* and *marketing* differ; the *code* does not.

---

## Scope

### In Scope

**Core social primitives (Twitter/X parity, trimmed):**
- Posts (text up to 280 chars, optional image, optional game tag)
- Follow / unfollow
- Home timeline (chronological; followed users + own posts)
- Likes, replies (single level only, no deep threads)
- User profile pages
- Search for users and game tags

**ICP-specific primitives (the differentiator):**
- Structured player profile: games played, roles, ranks, timezone, typical play hours
- "LFG post" — a structured post variant with: game, role needed, rank range, start time, duration, slots remaining
- LFG feed — filter by game, role, rank, time window
- "Join squad" action on an LFG post (creator approves)

**Messaging (DMs) — in scope per your call:**
- 1:1 direct messages
- Group DMs for approved squads
- Real-time delivery via websockets

**Moderation (minimal for v1):**
- Report user / report post
- Block user
- Admin queue for reviewing reports (simple list, approve/dismiss)
- Defer: automated content filters, appeals, temp bans, anything else

**Notifications:**
- In-app notification centre for: new follower, reply, like, LFG join request, new DM
- Real-time delivery for DMs and LFG join requests
- Email notifications — deferred to later phase

**Infrastructure / ecosystem (production-parity local):**
- Docker Compose stack that mirrors production topology (details in Technical section below)
- Postgres (not SQLite) as primary DB from day one
- Redis for cache, sessions, and queue broker
- Laravel Reverb for websockets
- Queue worker container for async jobs
- Scheduler container
- Reverse proxy / load balancer in front of two app replicas (to prove horizontal scalability works)
- Mailpit for dev email
- Healthchecks on every container

### Out of Scope

- Spaces / audio rooms
- Ads, promoted posts, any monetisation
- Payments / subscriptions / billing
- Mobile native apps (iOS / Android) — responsive web only
- Federation / ActivityPub / Mastodon interop
- Automated moderation (keyword filters, spam detection, ML)
- Riot / Steam / Xbox / PlayStation API integrations
- Voice chat (Discord already exists and is better at this)
- Video posts, streaming, clip hosting
- Email digests / marketing email flows
- SSO / social login (Google, Discord, etc.) — email/password only via Fortify
- Internationalisation / multi-language
- Analytics dashboards beyond basic event tracking

### Assumptions

- **Tech:** Laravel 13, Vue 3, Inertia 3, Tailwind 4, Fortify, Wayfinder, Reverb, Postgres 16, Redis 7, MinIO — all already decided or implied by current scaffold
- **Dev env:** **Docker Compose is the dev env and the production env.** No Laravel Herd. No parallel "local" and "containerised" worlds to keep in sync. The daily dev loop runs inside containers with bind-mounted code for hot reload.
- **Hosting (future):** Same Docker image deployable to Fly.io, Hetzner VPS, or Laravel Cloud; decision deferred until end of Phase 3
- **Auth:** Fortify email/password + optional 2FA. No magic links, no social login v1
- **Data volume:** Design for hundreds of users, not millions. Reasonable indexes only, no sharding, no read replicas
- **Self-reported ranks:** Trust the user; no verification v1
- **Legal/compliance:** Defer GDPR/COPPA/ToS work until a real launch is in view
- **Time budget:** Solo, ~8-15 hrs/week, 8-12 week build horizon

### Docker learning goals

Ed has flagged Docker as a skill-building priority. The stack is deliberately designed to exercise real Docker concepts, not hide them:

- Multi-stage `Dockerfile` (builder stage → slim runtime)
- Image layer caching strategy (`composer install` and `npm ci` layered correctly)
- Named volumes vs bind mounts (code bind-mounted in dev, not in prod)
- `docker-compose.yml` base + `docker-compose.override.yml` (dev) + `docker-compose.prod.yml` (prod)
- Service-to-service networking by DNS (`postgres`, `redis`, `reverb` as hostnames)
- Healthchecks with `depends_on: condition: service_healthy`
- Reverse proxy labels (Traefik) for service routing
- Horizontal scaling proof — two app replicas behind the LB
- Non-root container user + read-only root FS in the prod image
- Secrets handling (Docker secrets or env files, deliberately chosen)
- Logging strategy (stdout → `docker logs`, not log files)
- Hot reload inside a container (Vite dev server + PHP opcache revalidate)

These are not a curriculum — they're the natural byproduct of building this stack correctly. Each will be called out in commits/README when encountered.

---

## User Stories

### Must Have (v1 launch)

**US-1 — Account & profile**
> As a gamer, I want to register, log in, and create a player profile (games, roles, ranks, timezone, play hours) so that other users can see what I play and when.

Acceptance criteria:
- [ ] Email/password registration via Fortify with email verification
- [ ] Profile edit page with: display name, bio, avatar, timezone, at least one game entry
- [ ] Each game entry has: game name (from a seeded list), role(s), rank
- [ ] Profile page visible at `/@username` to authenticated users

**US-2 — Post and feed**
> As a user, I want to post short messages and see a timeline of posts from people I follow, so that I feel like I'm part of a community.

Acceptance criteria:
- [ ] Post composer: text up to 280 chars, optional image, optional game tag
- [ ] Home feed shows posts from followed users + own posts, newest first
- [ ] Pagination or infinite scroll (infinite scroll preferred per Inertia v3 patterns)
- [ ] Like and reply actions work and update in the UI
- [ ] Delete own posts

**US-3 — Follow graph**
> As a user, I want to follow and unfollow other players so that my feed reflects the people I care about.

Acceptance criteria:
- [ ] Follow/unfollow button on profile pages
- [ ] Follower and following counts visible on profile
- [ ] Follower/following list pages

**US-4 — LFG post (the differentiator)**
> As a player, I want to post an LFG signal specifying game, role, rank range, start time, and slot count, so that teammates who fit can request to join.

Acceptance criteria:
- [ ] Dedicated LFG composer distinct from regular post composer
- [ ] Structured fields: game, role, rank range (min/max), start time, duration, slots
- [ ] LFG posts appear in the regular feed AND in a filterable LFG board
- [ ] "Request to join" button on LFG posts (disabled for own posts)
- [ ] Creator sees join requests and can approve/decline

**US-5 — LFG board with filters**
> As a player, I want to browse open LFG posts filtered by game, role, rank, and time, so that I can find something to play right now.

Acceptance criteria:
- [ ] `/lfg` route shows all open LFG posts, newest first
- [ ] Filters: game (single select), role (multi), rank range (slider), time window (next 30m, 2h, today, this week)
- [ ] Closed/full LFG posts hidden by default

**US-6 — Direct messages with real-time delivery**
> As a user, I want to DM other users and receive messages in real time so that coordination happens inside the platform.

Acceptance criteria:
- [ ] 1:1 DM thread accessible from profile and LFG approval
- [ ] Group DM auto-created when an LFG squad fills (all approved members added)
- [ ] Websocket delivery via Reverb — message appears in recipient's UI without refresh
- [ ] Unread message count badge
- [ ] Fallback to polling if websocket unavailable (graceful degradation)

**US-7 — Notifications**
> As a user, I want an in-app notification centre so that I don't miss follows, replies, likes, or DM activity.

Acceptance criteria:
- [ ] Bell icon with unread count
- [ ] Notification types: new follower, reply, like, LFG join request, new DM
- [ ] Real-time delivery for DM and LFG join request notifications
- [ ] Mark all as read / clear

**US-8 — Report & block**
> As a user, I want to block abusive users and report bad content so that I can protect myself.

Acceptance criteria:
- [ ] Block hides the blocked user's posts, DMs, and profile from me
- [ ] Blocked user cannot DM me, reply to me, or join my LFG squads
- [ ] Report action available on posts, profiles, and DM threads
- [ ] Admin-only `/admin/reports` queue (gated by an `is_admin` flag)
- [ ] Admin can dismiss or take action (delete post, disable user)

### Should Have (if time permits before launch)

**US-9 — Search**
> As a user, I want to search for other players by handle, game, or role.

**US-10 — Player availability indicator**
> As a player, I want my profile to show "available now" / "online" / "offline" based on recent activity.

**US-11 — LFG history on profile**
> As a player, I want to see a history of squads I've played with, so others can judge reliability.

### Could Have (v2+)

- Squad pages (persistent multi-user groups with their own feed)
- Game API integrations for rank verification
- Email notifications and digest
- Reaction emoji beyond just "like"
- Post drafts
- Media gallery on profiles

### Won't Have (this version)

- Everything in "Out of Scope" above

---

## Technical Architecture

### Local Docker Compose stack (production-parity)

```
                     ┌──────────────────┐
                     │   Traefik / LB   │  :80 / :443
                     │  (reverse proxy) │
                     └────────┬─────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
       ┌──────────────┐                ┌──────────────┐
       │ app-1        │                │ app-2        │
       │ nginx +      │                │ nginx +      │
       │ php-fpm 8.3  │                │ php-fpm 8.3  │
       └──────┬───────┘                └──────┬───────┘
              └───────────┬───────────────────┘
                          │
     ┌──────────┬─────────┼─────────┬──────────┬──────────┐
     ▼          ▼         ▼         ▼          ▼          ▼
 ┌────────┐ ┌───────┐ ┌───────┐ ┌────────┐ ┌────────┐ ┌────────┐
 │postgres│ │ redis │ │reverb │ │ minio  │ │mailpit │ │vite dev│
 │ :5432  │ │ :6379 │ │ :8080 │ │  :9000 │ │ :8025  │ │ :5173  │
 └────────┘ └───────┘ └───────┘ └────────┘ └────────┘ └────────┘
                 ▲
                 │
       ┌─────────┴──────────┐
       ▼                    ▼
 ┌──────────────┐    ┌──────────────┐
 │ queue-worker │    │  scheduler   │
 └──────────────┘    └──────────────┘
```

*`vite dev` runs only under the dev override (`docker-compose.override.yml`). In the prod compose file, assets are pre-built into the app image and served by nginx.*

**What each container proves (portfolio signal):**
- **Two app replicas + LB** → horizontal scaling works, session handling is stateless (Redis-backed sessions)
- **Redis** → cache, queue, session, pub-sub for Reverb — one service, multiple roles (shows understanding)
- **Reverb** → Laravel's native websocket server, broadcasting for DMs and notifications
- **MinIO** → S3-compatible object storage, swappable for AWS S3 / Cloudflare R2 in prod with zero code change
- **queue-worker** → async jobs (notification fanout, report processing, image resize)
- **scheduler** → replaces cron; hosts Laravel's `schedule:run`
- **mailpit** → catches outbound mail in dev; swap env vars for a real SMTP in prod
- **vite dev** → hot module replacement container in dev only (override file); not present in prod compose
- **healthchecks** → every service has a healthcheck so `docker compose up` waits correctly

**MinIO (S3-compatible object storage)** — in from day one:
- Post images stored in MinIO, not local filesystem
- Same API surface (S3) as what we'd use in production (AWS S3, Cloudflare R2, etc.) — swap credentials and endpoint, nothing else changes
- Laravel `s3` filesystem driver points at MinIO locally
- Adds one more service to the compose file, but removes the "local → prod storage" migration problem later

**What we're deliberately not adding (yet):**
- Meilisearch / typesense — add in Should-Have phase if search becomes a bottleneck
- Prometheus / Grafana — overkill for portfolio scope
- Centralised logging (Loki/ELK) — stdout + `docker logs` is enough for v1

### Stack summary

| Layer | Choice | Why |
|---|---|---|
| Runtime | PHP 8.3 | Already locked by starter kit |
| Framework | Laravel 13 | Already locked |
| DB | Postgres 16 | Swap from SQLite early — avoids late migration pain |
| Cache / Queue / Session | Redis 7 | Standard combo |
| Websockets | Laravel Reverb | Native, no external dep, Laravel-first |
| Frontend | Vue 3 + Inertia 3 | Already locked |
| Styling | Tailwind 4 + Reka UI | Already locked |
| Auth | Fortify + 2FA | Already scaffolded |
| Testing | Pest 4 + browser | Already locked; Pest-first workflow |
| Reverse proxy | Traefik | Label-based service discovery, minimal config, auto-SSL in prod via Let's Encrypt |
| Object storage | MinIO (dev) / S3-compatible (prod) | One Laravel driver, zero code change between envs |
| Email (dev) | Mailpit | Catches outbound mail |
| Code quality | Pint, ESLint, Prettier, types:check | Already locked |

### Data model sketch (v1)

Core tables (non-exhaustive — these are the ones worth calling out now):

- `users` — Fortify-managed + `is_admin`, `timezone`, `bio`, `avatar_path`
- `games` — seeded list (valorant, league, dota2, cs2, overwatch, destiny2, etc.)
- `user_games` — pivot with `role`, `rank`, `hours_per_week`
- `posts` — `user_id`, `body`, `image_path`, `game_id?`, `is_lfg`
- `lfg_details` — one-to-one with `posts` where `is_lfg = true`: `role`, `rank_min`, `rank_max`, `starts_at`, `duration_minutes`, `slots`
- `lfg_requests` — `lfg_post_id`, `user_id`, `status` (pending/approved/declined)
- `follows` — `follower_id`, `followed_id`
- `likes` — `user_id`, `post_id`
- `replies` — just a `posts` row with `parent_id`, keep single-level
- `conversations` — DM thread (1:1 or group, linkable to `lfg_post_id`)
- `conversation_user` — membership
- `messages` — `conversation_id`, `sender_id`, `body`, `read_at`
- `notifications` — standard Laravel notifications table
- `blocks` — `blocker_id`, `blocked_id`
- `reports` — polymorphic target, `reporter_id`, `reason`, `status`

> Full schema design happens in Phase 1, not now. This sketch is to confirm scope, not commit to column names.

### Constraints / non-functional

- Page load < 1s on local Docker stack
- Websocket delivery < 500ms from send to receive on local
- Every PR runs Pest test suite via GitHub Actions (portfolio signal — CI green badge)
- Test coverage goal: feature tests cover every must-have user story end-to-end; unit tests for domain logic (rank comparisons, LFG matching)

---

## Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Scope creep — DMs + real-time + LFG + moderation is a lot for 8-12 weeks solo | High | High | Strict MoSCoW discipline. Ship Must-have only, defer everything else. Weekly scope check. |
| R2 | Docker Compose becomes a rabbit hole before any features exist | Med | Med | Phase 0 has a hard time box (5 working days). If not done, cut the load balancer, use single app container, ship features, come back later. |
| R3 | Real-time infra (Reverb + websockets) eats time with no visible UI payoff | Med | Med | Stub DMs with polling first; wire Reverb only after US-6 polling version is green. |
| R4 | "X for gamers" is ambiguous without launch games chosen — LFG board feels empty | Med | Med | Seed 5-8 popular team games; pre-populate profile dropdowns. Accept it will look empty on day one (dev data only). |
| R5 | Portfolio polish (README, architecture diagram, demo video, seeded demo data) gets skipped at the end | High | High | Treat polish as its own Phase 4 with explicit tasks, not a rounding error. |
| R6 | Postgres-specific features leak in and break SQLite-based starter kit tests | Low | Med | Switch tests to run against Postgres in CI and locally. Don't straddle. |
| R7 | Fortify + Inertia + real-time auth handoff (user identity on websockets) has subtle bugs | Med | Med | Use Laravel Sanctum or Reverb's built-in auth channels. Test auth on a private channel as the *first* Reverb task, not the last. |

---

## Timeline (rough, not a commitment)

Solo, ~10 hrs/week baseline.

### Phase 0 — Foundation (Week 1-2, ~15h)
Infra skeleton. No app features. "Hello world" in Docker Compose, everything green, dev workflow inside containers.

- [ ] `Dockerfile` for app (multi-stage: builder → runtime; non-root user in runtime)
- [ ] `docker-compose.yml` (base, prod-shaped): Traefik, 2× app replicas, Postgres, Redis, Reverb, MinIO, queue-worker, scheduler, Mailpit
- [ ] `docker-compose.override.yml` (dev): bind-mounts source, runs Vite dev server, enables opcache revalidate, exposes debug ports
- [ ] `docker-compose.prod.yml` (prod): pre-built assets, no bind mounts, no Vite, read-only root FS
- [ ] Swap SQLite → Postgres across app, factories, tests
- [ ] Redis-backed sessions, cache, queues
- [ ] Laravel `s3` filesystem driver pointed at MinIO; test upload works
- [ ] Reverb running and reachable from browser through Traefik
- [ ] Healthchecks on every service; `depends_on: service_healthy` for correct boot order
- [ ] `docker compose up` boots a working Laravel welcome page behind the LB
- [ ] CI via GitHub Actions: builds the image, runs Pest against Postgres inside the container
- [ ] README with "run locally in 3 commands" + architecture diagram + what each container does

**Exit criteria:** Freshly-cloned repo + `docker compose up` → welcome page, tests pass, all services healthy, hitting the URL twice alternates between app-1 and app-2 (LB works), file upload to MinIO succeeds.

### Phase 1 — Core social (Weeks 2-4, ~30h)
Twitter/X baseline.

- [ ] Posts CRUD with tests
- [ ] Follow graph
- [ ] Home timeline (infinite scroll)
- [ ] Likes + replies
- [ ] User profile page + edit
- [ ] Game catalog + user_games (structured profile)
- [ ] Block + report (UI only, no admin queue yet)

**Exit criteria:** Two test users can post, follow each other, see each other's posts, like, reply.

### Phase 2 — LFG (Weeks 5-6, ~20h)
The differentiator.

- [ ] LFG post schema + composer UI
- [ ] LFG board with filters
- [ ] Join request flow with approve/decline
- [ ] LFG posts render in main feed too

**Exit criteria:** A user can post an LFG, another user can find it via filters, request to join, and be approved.

### Phase 3 — DMs & real-time (Weeks 7-9, ~30h)
Reverb comes online.

- [ ] DM schema (conversations, messages)
- [ ] DM UI with polling delivery (feature-complete)
- [ ] Reverb wired up + private channels authed via Fortify session
- [ ] Real-time message delivery
- [ ] Real-time notifications for LFG requests + new DMs
- [ ] Group DM auto-created when LFG squad fills
- [ ] Admin reports queue (basic)

**Exit criteria:** Two browsers open → one sends a DM → the other sees it without refresh.

### Phase 4 — Polish & portfolio packaging (Weeks 10-12, ~20h)
This is where portfolio projects usually die. Explicit phase.

- [ ] Seeded demo data (realistic users, games, posts, open LFGs)
- [ ] Architecture diagram in README
- [ ] 60-second demo video / GIF
- [ ] Deploy to public URL (pick: Fly.io vs Forge VPS — decision at end of Phase 3)
- [ ] Accessibility pass (keyboard nav, contrast, screen reader on core flows)
- [ ] Dark mode verified across all pages
- [ ] Performance pass (Lighthouse, eager loading audit, N+1 check)
- [ ] Empty states, error states, loading states reviewed

**Exit criteria:** Public URL works, README tells the story, recruiter can grok in 3 minutes.

---

## Decisions (confirmed 2026-04-22)

1. **Name:** SquadUp.
2. **Launch games (10):** Valorant, League of Legends, Dota 2, CS2, Overwatch 2, Destiny 2, Apex Legends, Marvel Rivals, World of Warcraft, Final Fantasy XIV.
3. **Admin provisioning:** tinker for v1 (set `is_admin = true` manually).
4. **Deployment target:** deferred until end of Phase 3. Likely candidates: Fly.io, Hetzner VPS via Forge, Laravel Cloud.
5. **Public beta:** no. Local-only for the entire build.
6. **Images:** in-scope from v1. Stored in **MinIO** via Laravel's `s3` driver. 1MB upload cap. Same driver points at AWS S3 / Cloudflare R2 in production — credentials-only change.
7. **CI:** GitHub Actions only. No pre-commit hooks.

## Deferred Questions (revisit when relevant)

- Deployment target — end of Phase 3.
- Rank verification via game APIs — not for v1; reconsider if real users arrive.
- Search backend (Meilisearch) — only if search performance becomes a bottleneck in Should-Have phase.

---

Approved. Phase 0 cleared to start.
