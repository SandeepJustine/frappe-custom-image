# erpnext-custom

A production build pipeline for a custom Frappe image (ERPNext + HRMS +
Payments + CRM + Helpdesk), built directly from the **official
[frappe/frappe_docker](https://github.com/frappe/frappe_docker) layered
Containerfile** — not a hand-rolled Dockerfile — and published to GHCR
via GitHub Actions.

This repo owns exactly three things:

1. **`apps.json`** — which apps (and which branch of each) go into the
   image.
2. **`docker-bake.hcl`** — a `docker buildx bake` file that points at
   `frappe_docker`'s `images/custom/Containerfile` as a remote build
   context, so you always build with the same Containerfile that the Frappe
   team maintains and tests for custom app builds.
3. **`.github/workflows/build-and-push.yml`** — CI that builds, tags,
   caches, and pushes the image to GHCR.

Everything else (`docker-compose.yml`, `COOLIFY_DEPLOYMENT.md`) is for
running the resulting image in production on Coolify.

## Why remote-context instead of forking frappe_docker?

Forking `frappe_docker` means you now own merge conflicts every time
Frappe updates their Containerfile. Pointing `docker-bake.hcl`'s
`context` at `https://github.com/frappe/frappe_docker.git#main` (or a
pinned SHA/tag) means `docker buildx bake` clones frappe_docker fresh at
build time and runs *their* Containerfile with *your* `apps.json` baked
in via the standard `APPS_JSON_BASE64` build arg — the same mechanism
described in frappe_docker's own
[`docs/custom-apps.md`](https://github.com/frappe/frappe_docker/blob/main/docs/custom-apps.md).
You inherit every upstream security patch and version bump for free.

## Adding another app later

Edit `apps.json`:

```json
[
  { "url": "https://github.com/frappe/erpnext",   "branch": "version-16" },
  { "url": "https://github.com/frappe/hrms",      "branch": "version-16" },
  { "url": "https://github.com/frappe/payments",  "branch": "version-16" },
  { "url": "https://github.com/frappe/crm",       "branch": "version-16" },
  { "url": "https://github.com/frappe/helpdesk",  "branch": "version-16" },
  { "url": "https://github.com/your-org/your-custom-app", "branch": "main" }
]
```

Push to `main`. CI rebuilds and publishes a new tag automatically. Then,
on each existing site you want the new app on:

```bash
bench --site your-site.example.com install-app your-custom-app
```

(New sites get every installed-in-the-image app available via
`bench new-site` + `install-app` as normal — the image doesn't
auto-install apps onto every site, which is the correct/expected Frappe
behavior, not a limitation of this pipeline.)

For a private app repo, add a deploy-key-based URL or configure the
`APPS_JSON_BASE64` step in CI to inject credentials — see frappe_docker's
`custom-apps.md` for the private-repo variants (SSH URL + a mounted key,
or a token embedded in an HTTPS URL via a repository secret).

## Building locally

```bash
./scripts/build-local.sh dev-test version-16
```

This mirrors exactly what CI does, using your local Docker Buildx
instead of GHA cache.

## CI / tagging scheme

| Trigger | Tag produced |
|---|---|
| Push to `main` touching `apps.json`/`docker-bake.hcl` | `build-YYYY.MM.DD-<short-sha>` + `latest` |
| Push of a git tag `vX.Y.Z` | `vX.Y.Z` only (no `latest` bump) |
| Manual `workflow_dispatch` | Whatever tag you type in, `latest` optional via checkbox |

Pin `CUSTOM_TAG` to a specific `build-...` or `vX.Y.Z` tag in production
rather than tracking `latest`, so a bad upstream app commit can't
silently redeploy your stack.

## Build caching

`docker-bake.hcl` sets `cache-from`/`cache-to` with `type=gha`, so the
GitHub Actions cache stores built layers (base OS, Python venv, Node
modules, and per-app source/build layers) between runs. A rebuild
triggered only by, say, bumping the `helpdesk` branch will reuse
everything up to that app's layer instead of rebuilding
Frappe/ERPNext/HRMS/Payments/CRM from scratch.

## Deploying

See [`COOLIFY_DEPLOYMENT.md`](./COOLIFY_DEPLOYMENT.md) for the full
Coolify walkthrough (domain/Traefik setup, first-run `bench new-site`,
zero-downtime-ish redeploys, and a troubleshooting table).

`docker-compose.yml` in this repo is the compose file Coolify consumes;
it's structured the same way frappe_docker's own `pwd.yml`/production
compose examples are (mariadb, redis-cache, redis-queue, backend,
websocket, queue workers, scheduler, frontend) but with `image:` pointed
at this repo's GHCR image instead of the stock `frappe/erpnext` image.

## Repository layout

```
.
├── apps.json                          # apps + branches baked into the image
├── docker-bake.hcl                    # buildx bake definition (remote frappe_docker context)
├── docker-compose.yml                 # production stack for Coolify
├── .env.example                       # required env vars for docker-compose.yml
├── COOLIFY_DEPLOYMENT.md              # step-by-step Coolify deployment guide
├── scripts/
│   └── build-local.sh                 # local build helper mirroring CI
└── .github/
    └── workflows/
        └── build-and-push.yml         # CI: build, tag, cache, push to GHCR
```

## Security notes

- Never commit a real `.env`. `.gitignore` already excludes it.
- Prefer a private GHCR package with `permissions: packages: write`
  scoped to CI's `GITHUB_TOKEN` (already configured) over a personal
  access token.
- Pin `FRAPPE_DOCKER_REF` in `docker-bake.hcl` to a specific commit SHA
  once your stack is stable, so upstream Containerfile changes can't
  silently change your build without a deliberate bump on your side.
