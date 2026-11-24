# Deploy and Host Scrumboy on Railway

Scrumboy is a self-hosted project management and issue tracker. It gives you customizable boards with your own columns, sprints and priority tiers, cross-project workload and flow analytics, realtime collaboration, a sticky-note wall, JSON and Trello import, webhooks, and an MCP endpoint so AI coding agents can read and update the same boards.

## About Hosting Scrumboy

Scrumboy is a single Go binary with SQLite, so this template runs one service with one volume at `/data` for the database, uploaded images and the encryption key. Its first user becomes the instance Owner, and until that user exists the API accepts anonymous reads and writes. This template creates the Owner on a listener bound to 127.0.0.1 before the public port opens, from a generated password, and refuses to start without one. The deploy form has no prompts. After deploy, open the public URL and sign in as `admin@example.com` with `SCRUMBOY_OWNER_PASSWORD` from the service's Variables tab, then change the email under user settings if you like.

## Common Use Cases

* A sprint or kanban board for a small team, with the data on your own volume
* Workload and flow analytics across several projects at once
* Giving AI coding agents (Claude Code, Cursor) a real board to file and update work through MCP

## Dependencies for Scrumboy Hosting

* One Railway volume at `/data` (SQLite database, uploads, encryption key)
* No database service, cache or external account; SMTP and OIDC are optional

### Deployment Dependencies

* Scrumboy source and releases: [github.com/markrai/scrumboy](https://github.com/markrai/scrumboy) (AGPL-3.0), [v3.42.0](https://github.com/markrai/scrumboy/releases/tag/v3.42.0)
* Configuration reference: [environment variables](https://github.com/markrai/scrumboy/blob/v3.42.0/docs/environment-variables.md)
* Template source: [aalfath/scrumboy-railway-template](https://github.com/aalfath/scrumboy-railway-template)

### Implementation Details

**What you get:** one `Scrumboy` service built from our GitHub repo, which pins the official image `ghcr.io/markrai/scrumboy:3.42.0` by digest. It listens on `PORT` 8080, Railway checks `/healthz`, and a crash exits non-zero so Railway restarts it. It needs about 30 MB of RAM, so it fits Railway's Free plan (0.5 GB).

**Variables:** `SCRUMBOY_OWNER_PASSWORD` is a generated 32-character secret. Change it in Variables and redeploy to reset the Owner password: the start script applies it with upstream's `recover-owner` and signs out existing sessions. `SCRUMBOY_OWNER_EMAIL` (default `admin@example.com`) is only used to create the Owner and to apply a new password, so if you change the Owner's email in the app, change this variable too. `SCRUMBOY_PUBLIC_BASE_URL` is your Railway domain, used for reset links and MCP OAuth discovery; set it to your custom domain if you add one.

**Optional features:** password-reset and notification email (`SCRUMBOY_SMTP_HOST`, `SCRUMBOY_SMTP_FROM`, `SCRUMBOY_SMTP_USERNAME`, `SCRUMBOY_SMTP_PASSWORD`), single sign-on (`SCRUMBOY_OIDC_ISSUER`, `SCRUMBOY_OIDC_CLIENT_ID`, `SCRUMBOY_OIDC_CLIENT_SECRET`, `SCRUMBOY_OIDC_REDIRECT_URL`) and web push (`SCRUMBOY_VAPID_*`). Add the variables to the service to switch them on; see upstream's docs.

**AI agents (MCP):** the streamable HTTP endpoint is `https://YOUR-DOMAIN/mcp/rpc` with OAuth sign-in, for example `claude mcp add --transport http scrumboy https://YOUR-DOMAIN/mcp/rpc`. Scripts can use an `sb_` API token created in the web UI.

**Anonymous boards:** like upstream, signed-out visitors can open `/anon` to create a throwaway board that expires after 90 days, rate-limited to 5 per IP per hour and 20 per hour for the instance. They can't see your projects.

**Backups and updates:** back up the whole `/data` volume; the encryption key in `/data/encryption.key` must stay with the database. New Scrumboy versions reach you as a Railway update notice when we bump the pin in our repo; read its `CHANGELOG.md` before you apply one.

## Why Deploy Scrumboy on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Scrumboy on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
