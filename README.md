# SquadUp

> **"X for gamers"** — a social platform where every user is a player profile, every post can be an LFG signal, and finding regular teammates is a first-class action rather than an afterthought in a Discord server.

**Status:** Phase 0 (foundation) — infra only, no app features yet. See [the brief](briefs/squadup-brief.md) for scope and roadmap.

---

## What this repo is

A portfolio build of a Twitter-shaped social network for competitive team-game players. The product direction is deliberately narrow — clan and squad coordination, not general social — so the data model and UX have a reason to differ from yet-another-X-clone.

It's also a ground-up Docker study: everything — dev *and* production — runs in containers, with Postgres, Redis, Reverb, MinIO, queue workers, a reverse proxy, and horizontal app replicas orchestrated by Compose. The stack is intentionally built from plain Laravel + Docker primitives rather than `laravel/sail`, so each piece is visible and explicable.

## Tech stack

| Layer | Choice | Version |
|---|---|---|
| Runtime | PHP | 8.4 |
| Framework | Laravel | 13.x |
| Frontend | Vue 3 + Inertia.js | Vue 3.5, Inertia 3 |
| Styling | Tailwind CSS | 4.x |
| UI primitives | Reka UI | 2.x |
| Type safety | TypeScript | 5.x |
| Build tool | Vite | 8.x |
| Auth | Laravel Fortify (2FA-ready) | 1.34+ |
| Type-safe routes | Laravel Wayfinder | 0.1.14+ |
| Database | PostgreSQL | 16 |
| Cache / sessions / queues | Redis | 7 |
| Websockets | Laravel Reverb *(commit 3)* | — |
| Object storage | MinIO (S3-compatible) | latest |
| Reverse proxy | Traefik *(commit 2)* | — |
| Testing | Pest | 4.x |
| Orchestration | Docker Compose | — |

## Quick start

Prerequisites: Docker Desktop or OrbStack running. Nothing else — no PHP, Node, or Composer needed on the host.

```bash
git clone git@github.com:flyingearl/squadup.git
cd squadup
cp .env.example .env
docker compose up --build
```

First build takes 5-10 minutes (PHP extensions compile from source). Afterwards, `docker compose up` starts in seconds. Open http://localhost:8080.

### Default ports on the host

| Service | Port | Notes |
|---|---|---|
| App (via Traefik) | `8080` | Laravel welcome page / SPA — load-balanced across 2 replicas |
| Traefik dashboard | `8081` | http://localhost:8081 — shows discovered services, replicas, healthchecks |
| Reverb (websockets) | `8082` | Browser WebSocket endpoint for real-time features |
| Vite dev server | `5173` | Runs in a container; HMR websocket for hot-reload |
| Mailpit SMTP | `1025` | Laravel's mail connection target (dev) |
| Mailpit web UI | `8025` | http://localhost:8025 — view outbound mail |
| Postgres | `5432` | `squadup / squadup / squadup` (db / user / pass, dev only) |
| Redis | `6379` | no auth, dev only |
| MinIO S3 API | `9000` | `squadup / squadup-secret` |
| MinIO console | `9001` | http://localhost:9001 |

Credentials live in `.env.example` — they're dev defaults, not secrets, and only reachable from `localhost`.

## Architecture

Current state (end of Phase 0 commit 4):

```
   localhost:8080 ─▶ traefik ─▶ dashboard :8081                localhost:5173 ─▶ vite (HMR)
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
      ┌────────┐                  ┌────────┐
      │ app-1  │                  │ app-2  │   nginx + php-fpm 8.4 + supervisor
      └───┬────┘                  └───┬────┘
          └──────────┬─────────────────┘
                     │
    ┌─────┬──────────┼──────────┬──────────┬──────────┬───────────┐
    ▼     ▼          ▼          ▼          ▼          ▼           ▼
 ┌────┐ ┌────┐  ┌────────┐  ┌───────┐  ┌────────┐ ┌───────┐ ┌─────────┐
 │ pg │ │redis│ │ reverb │  │ minio │  │  queue │ │ sched │ │ mailpit │
 │    │ │     │ │  :8082 │  │:9000/1│  │ worker │ │ uler  │ │ :8025   │
 └────┘ └─────┘ └────────┘  └───────┘  └────────┘ └───────┘ └─────────┘
```

The `vite` service is dev-only (defined in `docker-compose.override.yml`) and doesn't ship to production.

Planned topology at end of Phase 0:

```
                        ┌────────────┐
                 :443 ──▶│  Traefik   │
                        └─────┬──────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              ┌──────────┐        ┌──────────┐
              │  app-1   │        │  app-2   │
              └────┬─────┘        └────┬─────┘
                   └──────┬─────────────┘
                          │
   ┌────────┬────────┬────┼────┬────────┬─────────┬─────────┐
   ▼        ▼        ▼    ▼    ▼        ▼         ▼         ▼
┌──────┐ ┌─────┐ ┌──────┐ ┌─────┐ ┌─────────┐ ┌────────┐ ┌──────┐
│  pg  │ │redis│ │reverb│ │minio│ │  queue  │ │mailpit │ │ vite │
│      │ │     │ │      │ │     │ │ worker  │ │  :8025 │ │ HMR  │
└──────┘ └─────┘ └──────┘ └─────┘ └─────────┘ └────────┘ └──────┘
                              ▲
                              │
                       ┌──────┴─────┐
                       │ scheduler  │
                       └────────────┘
```

## What each container does

| Service | Image | Role |
|---|---|---|
| `traefik` | `traefik:v3.1` | Reverse proxy + load balancer. Docker-label discovery, dashboard on `:8081`. |
| `app` (×2 replicas) | built from `Dockerfile` | Laravel SPA. nginx + php-fpm 8.4 + supervisor. Only role that runs migrations (`CONTAINER_ROLE=web`). |
| `reverb` | same app image | Laravel Reverb websocket server, bound to `:8080` inside, mapped to `localhost:8082` on the host. |
| `queue-worker` | same app image | `php artisan queue:work` — processes queued jobs via Redis. |
| `scheduler` | same app image | `php artisan schedule:work` — Laravel-native cron replacement. |
| `postgres` | `postgres:16-bookworm` | Primary database. `postgres-data` named volume. `pg_isready` healthcheck. |
| `redis` | `redis:7-bookworm` | Cache, sessions, queue broker, and Reverb scaling channel. `redis-cli ping` healthcheck. |
| `minio` | `minio/minio:latest` | S3-compatible object storage. `s3` filesystem driver connects via `AWS_ENDPOINT=http://minio:9000`. |
| `minio-init` | `minio/mc:latest` | One-shot: waits for MinIO, creates the `squadup` bucket, sets a download policy. Exits after running. |
| `mailpit` | `axllent/mailpit:latest` | SMTP catcher. Laravel sends to `mailpit:1025`; view the inbox at http://localhost:8025. |
| `vite` *(dev only)* | `node:20-bookworm-slim` | Runs `npm install` on first boot, then `npm run dev`. Provides Tailwind + Vue HMR and triggers Wayfinder type generation. Lives in `docker-compose.override.yml` so it doesn't ship to production. |

All PHP-side services (app, reverb, queue-worker, scheduler) share the same built image. They differ only in the command that `supervisord`/`entrypoint` execs and the `CONTAINER_ROLE` env var (which tells the entrypoint whether to run migrations).

### Why a `docker-compose.override.yml`?

Compose automatically merges `docker-compose.override.yml` on top of the base file when you run `docker compose up`. This repo uses the split deliberately:

- **`docker-compose.yml`** — the production-shaped stack. Shared between dev and CI.
- **`docker-compose.override.yml`** — dev-only additions: the Vite container, bind mounts, anything that shouldn't ship.
- **`docker-compose.prod.yml`** *(coming in commit 5)* — production-only settings: pre-built assets, read-only filesystems, no source bind mounts. Run with `docker compose -f docker-compose.yml -f docker-compose.prod.yml up`.

### Proving round-robin works

Every response from the app carries an `X-Served-By` header set to the container ID of the replica that handled it. Hit the app a few times:

```bash
for i in 1 2 3 4; do curl -sI http://localhost:8080 | grep -i served-by; done
```

Expected output — two distinct container IDs alternating:
```
X-Served-By: 7f3a8d9e1234
X-Served-By: 9c2b5f1a6789
X-Served-By: 7f3a8d9e1234
X-Served-By: 9c2b5f1a6789
```

You can also visit the Traefik dashboard (http://localhost:8081) and browse to **HTTP → Services → app** to see both replicas listed as live backends.

## Useful commands

```bash
# Start / stop
docker compose up --build         # build + start
docker compose up                 # start (no rebuild)
docker compose down               # stop + remove containers (volumes kept)
docker compose down -v            # stop + wipe volumes (full reset)

# Logs
docker compose logs -f app        # tail app logs
docker compose logs postgres      # last Postgres logs
docker compose ps                 # status + healthchecks

# Shell into an app replica (Compose picks one of the two automatically)
docker compose exec app bash      # interactive shell
docker compose exec app php artisan migrate:fresh --seed
docker compose exec app composer install
docker compose exec app php artisan tinker

# Target a specific replica
docker compose exec --index=1 app bash   # squadup-app-1
docker compose exec --index=2 app bash   # squadup-app-2

# DB access (from host)
docker compose exec postgres psql -U squadup -d squadup

# Redis CLI
docker compose exec redis redis-cli
```

## Project structure

```
.
├── app/                    # Laravel backend (controllers, models, Fortify actions)
├── resources/js/           # Vue 3 + Inertia SPA (pages, components, composables)
├── routes/                 # web.php, settings.php
├── database/migrations/    # Postgres schema
├── tests/                  # Pest 4 feature + unit tests
├── docker/                 # nginx, php.ini, supervisord, entrypoint.sh
├── Dockerfile              # Single-stage dev image (multi-stage refactor in a later commit)
├── docker-compose.yml      # app + postgres + redis + minio
├── briefs/squadup-brief.md # Authoritative scope, user stories, roadmap
└── .env.example            # Copy to .env on first boot
```

## Roadmap

This is a phased build. Each phase has explicit exit criteria in the [brief](briefs/squadup-brief.md).

| Phase | Scope | Status |
|---|---|---|
| **0 — Foundation** | Docker Compose (app, Postgres, Redis, MinIO, Reverb, queue, scheduler, LB, Vite), GitHub Actions CI | In progress (commits 1-4 of ~6 done) |
| **1 — Core social** | Posts, follows, timeline, likes, replies, profiles, game catalog | Planned |
| **2 — LFG differentiator** | LFG post schema, filterable LFG board, join-request flow | Planned |
| **3 — DMs & real-time** | 1:1 and group DMs, Reverb-backed delivery, notifications, admin reports queue | Planned |
| **4 — Polish & portfolio packaging** | Seeded demo data, architecture docs, deploy, a11y + perf pass | Planned |

## Not building (scope lockouts)

To stay shippable within a realistic solo-dev window, the following are explicitly out of scope for v1:

- Spaces / audio rooms
- Ads, promoted posts, any monetisation
- Native mobile apps (responsive web only)
- Federation / ActivityPub
- Automated moderation (report & block only)
- Game API integrations (ranks are self-reported)
- Social login (email/password + optional 2FA via Fortify)
- Voice chat (Discord already wins at this)

Full list in the [brief](briefs/squadup-brief.md).

## License

[MIT](LICENSE) *(LICENSE file to be added)*
