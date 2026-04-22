# Phase 1 Plan — Core Social

**Date:** 2026-04-22
**Status:** Approved

Covers brief user stories US-1 (profile), US-2 (posts + feed + engagement), US-3 (follow graph), and US-8 (block + report UI only). LFG-specific work (US-4, US-5) lives in Phase 2.

---

## Decisions locked

| # | Decision |
|---|---|
| 1 | **Username separate from display name.** `username` is unique, lowercase, 3-20 chars, alphanumeric + underscore. `name` stays freeform for display. URL slug uses username. |
| 2 | **Block is two-way.** A blocks B → neither sees the other's posts, neither can reply, existing follows are removed both directions, neither can DM (enforced when DMs land in Phase 3). Profile visits show a minimal "cannot view" page. |
| 3 | **Post game tag is an FK** to `games.id`, nullable. |
| 4 | **Replies are threaded.** Unlimited depth in DB via `posts.parent_id`. UI is Twitter-style linear — "replying to @foo" header, no deep indentation. Click into a reply to see its own subthread. |
| 5 | **Feed is chronological.** No algorithmic ranking v1. |
| 6 | **Feed page size: 20.** Infinite scroll via Inertia v3 merge-on-visit. |
| 7 | **Counts are denormalised.** `posts.likes_count`, `posts.replies_count`, `users.followers_count`, `users.following_count` updated in observers. Avoids `withCount` on every feed query. |
| 8 | **Avatars in MinIO** at `avatars/{user_id}/{uuid}.{ext}`, public visibility, old avatar deleted on upload. |

---

## Commit slicing

Each slice is roughly 1-3 hours of solo work; tests ship with each.

### 1.1 — Player profile schema + games seed *(foundation, no UI)*

- `users` table additions: `username` (unique, indexed), `bio` (nullable text), `avatar_path` (nullable string), `timezone` (string, default UTC), `is_admin` (bool, default false)
- `games` table (id, name, slug, created_at, updated_at); seeded with 10 games: Valorant, League of Legends, Dota 2, CS2, Overwatch 2, Destiny 2, Apex Legends, Marvel Rivals, World of Warcraft, Final Fantasy XIV
- `user_games` pivot (user_id, game_id, role, rank, hours_per_week, created_at, updated_at); composite unique on (user_id, game_id, role)
- Factories: `UserFactory` gets username state, `GameFactory`, `UserGameFactory`
- `Game` and `UserGame` models + relationships
- Pest unit tests for relationships
- Seeder registered for dev/prod first-run

### 1.2 — Profile edit page + public profile

- Username validation (form request): unique, 3-20 chars, regex `^[a-z0-9_]+$`, case-insensitive uniqueness
- `ProfileController@edit` extended: bio, timezone select, avatar upload, per-game rows (game + role + rank + hours)
- Avatar upload through `s3` disk to MinIO, max 1MB, resized to 512x512 (via gd extension already installed)
- Public profile: `GET /@{username}` → `ProfileController@show` → Inertia page
- Self-visit redirects `/dashboard/profile` for editing
- Pest feature tests: username uniqueness, avatar upload persists, edit flow

### 1.3 — Posts: model + composer + own-posts display

- `Post` model + migration (`id`, `user_id`, `body` string 280, `game_id?`, `parent_id?`, `likes_count` default 0, `replies_count` default 0, `created_at`, `updated_at`, indexes on `user_id + created_at` and `parent_id`)
- Factories: `PostFactory`, with `reply()` state that sets parent_id
- `PostController@store` (form request validates 280-char cap, optional game_id), `@destroy` (PostPolicy: own only)
- Dashboard gains a composer
- Own profile page shows own latest posts (stub for feed in 1.5)
- Observers start tracking counts
- Pest: auth required, own-only delete, 280-char validation, game_id existence check

### 1.4 — Follow graph

- `follows` pivot (follower_id, followed_id, created_at) + composite unique
- `User::following()` / `followers()` belongsToMany relations
- `FollowController@store` / `@destroy` — idempotent
- Follow button on profile page
- Denormalised counts via observer: `users.followers_count`, `users.following_count`
- `/@{username}/followers` + `/@{username}/following` list pages
- Tests: can't follow self, composite uniqueness, count invariants

### 1.5 — Home timeline

- Dashboard becomes the feed: `posts.parent_id IS NULL AND user_id IN (followed_ids + self_id)`, order by `created_at DESC`
- Index on `posts.user_id + created_at DESC` confirmed in 1.3
- Infinite scroll: Inertia v3 merge-on-visit with `only: ['posts']` and `?page=N` cursor
- Empty state when no follows yet, CTA to find players
- Feature test: feed respects follow graph; pagination advances without duplicating

### 1.6 — Engagement: likes + threaded replies

- `likes` table (user_id, post_id, created_at) + composite unique
- Reply = `Post` row with `parent_id` set; unlimited depth allowed
- UI: each post shows like + reply actions; reply opens inline composer; count badges hop on click (optimistic via Inertia `router.reload({ only: ['post'] })`)
- Post detail page: `GET /posts/{post}` → post + direct replies (`parent_id = post.id`), paginated. Click a reply to navigate to its subtree (same page, different id).
- Observers: likes_count, replies_count on `Post`
- Rejection rule: **only** top-level posts and direct replies show in the main feed; nested replies appear in thread view only
- Tests: like idempotence, reply creates post with correct parent, counts update

### 1.7 — Block + report (UI only, admin queue deferred)

- `blocks` pivot (blocker_id, blocked_id, created_at) + composite unique
- `reports` polymorphic (reporter_id, reportable_type, reportable_id, reason enum, status enum, created_at)
- `User::hasBlockRelationshipWith(User $other): bool` — canonical check used by feed scope, profile controller, reply controller
- Global post scope: hide posts from users blocked by viewer OR blocking viewer
- Profile visit when blocked: minimal "cannot view" page (not a 404 — gives plausible deniability)
- Follow creation: when A blocks B, delete existing rows in both directions
- Report UI: button on post and profile, modal to pick reason, writes row + shows toast
- **No admin UI here** — `/admin/reports` queue is Phase 3
- Tests: block removes both follow directions, feed excludes blocked posts both ways, reports table grows correctly

---

## Data model (final for Phase 1)

```
users
  id, name, email, password, email_verified_at, remember_token,
  username (unique, lowercase, regex), bio, avatar_path, timezone,
  is_admin, two_factor_*, followers_count, following_count,
  timestamps

games
  id, name, slug, timestamps

user_games (pivot)
  id, user_id, game_id, role, rank, hours_per_week, timestamps
  UNIQUE (user_id, game_id, role)

posts
  id, user_id, body (280), game_id?, parent_id?,
  likes_count, replies_count, timestamps
  INDEX (user_id, created_at DESC)
  INDEX (parent_id)

follows (pivot)
  follower_id, followed_id, created_at
  PRIMARY KEY (follower_id, followed_id)

likes (pivot)
  user_id, post_id, created_at
  PRIMARY KEY (user_id, post_id)

blocks (pivot)
  blocker_id, blocked_id, created_at
  PRIMARY KEY (blocker_id, blocked_id)

reports
  id, reporter_id, reportable_type, reportable_id, reason, status,
  timestamps
  INDEX (reportable_type, reportable_id)
  INDEX (status)
```

---

## Out of scope for Phase 1

Explicitly deferred:

- LFG-specific post fields (role required, rank range, starts_at, duration, slots, lfg_requests table) — Phase 2
- LFG board + filters — Phase 2
- DMs, real-time, notifications — Phase 3
- Admin queue for reports — Phase 3
- Search (US-9) — Should-have, post-Phase 1
- Online status (US-10) — Should-have
- LFG history (US-11) — Should-have
- Game API integrations, rank verification, email notifications, media galleries — Could-have v2+

---

## Exit criteria

- All 7 commits landed on main with CI green
- Two test users can: register → set username + add a game → follow each other → post → like → reply → block → reports persist
- Feed page loads in < 500ms locally with 100 posts per user, 5 follows
- Pest: all existing tests still pass, every new controller/action has coverage
- Pint + ESLint + Prettier + vue-tsc all clean
- README's roadmap row for Phase 1 → **Done**
