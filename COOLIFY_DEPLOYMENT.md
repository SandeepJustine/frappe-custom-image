# Deploying to Coolify

This guide walks through taking the image built by `.github/workflows/build-and-push.yml`
and running it as a production ERPNext (+ HRMS/Payments/CRM/Helpdesk) stack
on Coolify.

## 1. Prerequisites

- A Coolify server (v4) with a public IP and a domain pointed at it.
- The GHCR image already built at least once (push to `main`, or run the
  workflow manually) so `ghcr.io/sandeepjustine/erpnext-custom:latest` exists.
- If your GHCR package is **private**, create a GHCR personal access
  token (read:packages) and add it as a "Docker Registry" credential in
  Coolify → Servers → your server → Registries, or make the package
  public under package settings.

## 2. Create the resource in Coolify

1. **Projects → New Project → + New Resource → Docker Compose.**
2. Point it at this repository (or paste `docker-compose.yml` directly
   if you're not connecting a git source).
3. Set the **Base Directory** to the repo root (where `docker-compose.yml`
   lives).
4. Under **Environment Variables**, set at minimum:
   - `CUSTOM_IMAGE` — `ghcr.io/sandeepjustine/erpnext-custom`
   - `CUSTOM_TAG` — pin this to a real build tag once you're past initial
     testing (e.g. `build-2026.08.01-abc1234`), not `latest`
   - `DB_ROOT_PASSWORD` — generate with `openssl rand -base64 24`
   - `SITE_NAME` — the domain you'll expose, e.g. `erp.example.com`

## 3. Domain / routing (the most common Coolify + Frappe pitfall)

Coolify uses Traefik in front of your containers. Point Coolify's domain
setting **only at the `frontend` service**, and target container port
`8080` (that's the nginx frontend's listening port in the layered image).

- Do **not** also try to expose `backend` or `websocket` on a domain —
  they're internal-only; `frontend`'s nginx proxies to them by service
  name (`backend:8000`, `websocket:9000`), which works because Coolify
  puts all services in the same compose project on one Docker network.
- If you've run other Frappe/ERPNext stacks on this same Coolify server
  before, double-check for **stale Traefik router labels** from a
  previous deployment using the same domain — leftover labels from a
  deleted-but-not-fully-cleaned resource are a common cause of
  "504 Gateway Timeout" or requests silently landing on the wrong
  container. Coolify → Servers → Proxy → check the generated Traefik
  config, or `docker inspect` the old container if it's still around.
- Give this resource's Traefik router label a name that's unique per
  ERPNext instance if you're running multiple client sites on one
  Coolify server (e.g. `traefik.http.routers.<client>-frontend.rule=...`),
  the same way you would for parallel ERPNext-on-Coolify deployments —
  reusing the default/auto-generated router name across two stacks on
  the same server is what causes routing conflicts.

## 4. First deploy

Click **Deploy**. Coolify will pull the image and bring up:
`mariadb`, `redis-cache`, `redis-queue`, `backend`, `websocket`,
`queue-short`, `queue-long`, `scheduler`, `frontend`.

Watch the logs for `mariadb` and `backend` — `backend` will crash-loop
harmlessly until MariaDB reports healthy and the site exists (next step).

### MariaDB version note

`docker-compose.yml` pins `mariadb:10.6`, matching what frappe_docker's
own compose files test against for Frappe/ERPNext v16. If you change
this, confirm the target MariaDB version is one ERPNext v16 actually
supports before deploying — mismatched MariaDB versions are a frequent
source of cryptic migration/collation errors on first `bench new-site`,
and it's a much easier fix before there's data in the volume than after.

### Redis URL format

The compose file sets `REDIS_CACHE` / `REDIS_QUEUE` as full URLs
(`redis://redis-cache:6379`), which is the format the layered image's
common_site_config expects. If you ever hand-edit
`sites/common_site_config.json` inside the container, keep this
`redis://host:port` form — a bare `host:port` without the scheme will
fail silently in ways that only show up when a background job tries to
enqueue.

## 5. Create the site (one-time)

Open a shell into the **backend** container from Coolify (Resource →
`backend` service → **Terminal**), then:

```bash
bench new-site $SITE_NAME \
  --mariadb-root-password "$DB_ROOT_PASSWORD" \
  --admin-password "choose-a-strong-admin-password" \
  --no-mariadb-socket

# Install the apps this image was built with (matches apps.json)
bench --site $SITE_NAME install-app erpnext
bench --site $SITE_NAME install-app hrms
bench --site $SITE_NAME install-app payments
bench --site $SITE_NAME install-app crm
bench --site $SITE_NAME install-app helpdesk

# Make this the default site the frontend nginx serves
bench use $SITE_NAME
```

Restart the `frontend` and `backend` services from Coolify afterward so
nginx picks up the new site.

## 6. Ongoing deploys (new image versions)

1. CI publishes a new tag automatically on every push to `main` that
   touches `apps.json` or `docker-bake.hcl` (see the root `README.md`
   for the exact tagging scheme), or on a pushed `vX.Y.Z` git tag.
2. In Coolify, update the `CUSTOM_TAG` environment variable to the new
   tag and hit **Redeploy** — Coolify will pull the new image and
   recreate the containers. Sites/data live in the `sites` and
   `mariadb-data` named volumes and are untouched by this.
3. If the new image adds a **new app** (i.e. you added an entry to
   `apps.json`), run `bench --site $SITE_NAME install-app <app-name>`
   once in the backend container's terminal after the redeploy — adding
   an app to the image doesn't retroactively install it on existing
   sites.
4. If a deploy changes Frappe/app schema, run a migration once from the
   backend terminal:
   ```bash
   bench --site $SITE_NAME migrate
   ```

## 7. Backups

Coolify can schedule volume backups, but for Frappe/ERPNext prefer
`bench backup` (it produces a consistent DB dump + files tarball you can
restore with `bench restore`), scheduled via a cron entry on the host or
an extra one-shot service in the compose file that runs
`bench --site $SITE_NAME backup --with-files` on a schedule and writes
to a mounted volume you separately back up off the Coolify server.

## 8. Troubleshooting checklist

| Symptom | Likely cause |
|---|---|
| `504 Gateway Timeout` on the site domain | Traefik routing to the wrong/old container, or `frontend` up but `backend` still crash-looping — check `backend` logs first |
| `backend` restarts forever | Site not created yet (step 5), or `DB_ROOT_PASSWORD` mismatch between `mariadb` and `backend`/`frontend` env |
| Background jobs (emails, scheduled reports) never run | `scheduler` or `queue-*` containers not actually running — check they're not silently crash-looping; verify `REDIS_QUEUE` URL format |
| New app not visible after redeploy | You updated `apps.json`/rebuilt the image but forgot `bench install-app` on the existing site (step 6.3) |
| Deploy uses an old image despite a new push | `CUSTOM_TAG` still set to a stale tag, or Coolify's registry cache — set `pull_policy: always` (already set in this compose file) and force a redeploy |
