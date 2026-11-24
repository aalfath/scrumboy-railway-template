[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/scrumboy-2?utm_medium=integration&utm_source=button&utm_campaign=scrumboy)

# Scrumboy on Railway

One-click Railway template for [Scrumboy](https://github.com/markrai/scrumboy) **v3.42.0**, self-hosted project management with customizable boards, sprints, cross-project workload and flow analytics, and an MCP endpoint for AI coding agents.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| `Scrumboy` | this repo (`Dockerfile`), `FROM ghcr.io/markrai/scrumboy:3.42.0@sha256:d9605646359c76d59be2164b3806203ed7cdb83c55a54131904fccd723dbc5c3` | The web app and API on `PORT` 8080, health check `/healthz`, SQLite on a volume at `/data` |

No database service is needed. The volume holds the SQLite database, uploaded images and the encryption key (`/data/encryption.key`), so back up the whole volume. RAM: about 30 MB, so it fits Railway's Free plan (0.5 GB).

## The Owner account

Scrumboy's first user becomes the instance Owner, and before that user exists its API accepts anonymous reads and writes. So `railway-entrypoint.sh`:

1. refuses to start if `SCRUMBOY_OWNER_PASSWORD` is empty or shorter than 12 characters;
2. starts Scrumboy on `127.0.0.1:9931` only, creates the Owner through `/api/auth/bootstrap`, checks it took effect, and stops that instance;
3. only then starts the public server on `PORT`.

Any failure exits non-zero, so Railway restarts the service instead of serving an unclaimed instance.

After deploy, sign in as `admin@example.com` with `SCRUMBOY_OWNER_PASSWORD` from the service's Variables tab.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `SCRUMBOY_OWNER_PASSWORD` | `${{secret(32)}}` | Owner password. Change it and redeploy to reset the password (applied with upstream's `recover-owner`, which signs out existing sessions) |
| `SCRUMBOY_OWNER_EMAIL` | `admin@example.com` | Owner sign-in email. If you change the Owner's email in the app, change it here too |
| `SCRUMBOY_PUBLIC_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public origin for reset links and MCP OAuth discovery; set your custom domain here if you add one |
| `PORT` | `8080` | Port the app, the domain and the health check use |

Baked into the image: `DATA_DIR=/data`, `SQLITE_PATH=/data/app.db`, `SCRUMBOY_MODE=full`, `SCRUMBOY_TRUST_PROXY=1` (Railway's edge overwrites `X-Forwarded-*`). The start script sets `GOMEMLIMIT` to 85 % of the container's memory limit. Optional features (SMTP, OIDC, web push) switch on when you add their variables: see upstream's [environment variables](https://github.com/markrai/scrumboy/blob/v3.42.0/docs/environment-variables.md).

## AI agents (MCP)

Streamable HTTP endpoint with OAuth: `https://YOUR-DOMAIN/mcp/rpc`, for example

```sh
claude mcp add --transport http scrumboy https://YOUR-DOMAIN/mcp/rpc
```

Scripts can use an `sb_` API token created in the web UI (`POST /mcp`, see upstream's [API.md](https://github.com/markrai/scrumboy/blob/v3.42.0/API.md)).

## Updates

Railway sends deployers of this template an "update available" notice when `main` of this repo changes. Each version bump is listed in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Read it before you apply an update.

## Licence

Scrumboy is AGPL-3.0 by its authors. This wrapper (Dockerfile, start script, docs) is published under the same licence.
