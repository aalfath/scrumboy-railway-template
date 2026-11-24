# Scrumboy on Railway: https://github.com/markrai/scrumboy (AGPL-3.0)
# Upstream's official image, pinned by version and digest. The wrapper only adds
# a start script: Railway PORT -> BIND_ADDR, a memory limit from the cgroup, the
# encryption key kept on the volume, and an Owner account created on a
# loopback-only listener before the public port opens.
FROM ghcr.io/markrai/scrumboy:3.42.0@sha256:d9605646359c76d59be2164b3806203ed7cdb83c55a54131904fccd723dbc5c3

# The upstream image bakes BIND_ADDR=:8080; the start script sets it from PORT.
# Railway's edge overwrites X-Forwarded-For/-Proto, so trusting the first hop is safe.
ENV PORT=8080 \
    DATA_DIR=/data \
    SQLITE_PATH=/data/app.db \
    SCRUMBOY_MODE=full \
    SCRUMBOY_TRUST_PROXY=1

COPY --chmod=755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
