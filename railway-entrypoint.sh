#!/bin/sh
# Start script for Scrumboy on Railway. Every failure exits non-zero, so
# Railway's ON_FAILURE restart policy restarts the service.
set -eu

DATA_DIR="${DATA_DIR:-/data}"
PORT="${PORT:-8080}"
SETUP_PORT="${SCRUMBOY_SETUP_PORT:-9931}"
OWNER_EMAIL="${SCRUMBOY_OWNER_EMAIL:-admin@example.com}"
OWNER_NAME="${SCRUMBOY_OWNER_NAME:-Owner}"
OWNER_PASSWORD="${SCRUMBOY_OWNER_PASSWORD:-}"
unset SCRUMBOY_OWNER_PASSWORD

log() { echo "railway-entrypoint: $*"; }
die() { echo "railway-entrypoint: FATAL: $*" >&2; exit 1; }

# Scrumboy's Owner is whoever bootstraps an empty instance, and before that the
# API accepts anonymous reads and writes. Never open the public port without it.
[ -n "$OWNER_PASSWORD" ] || die "SCRUMBOY_OWNER_PASSWORD is empty; the first visitor would become the owner."
[ "${#OWNER_PASSWORD}" -ge 12 ] || die "SCRUMBOY_OWNER_PASSWORD must be at least 12 characters."
case "$OWNER_EMAIL" in *@*) ;; *) die "SCRUMBOY_OWNER_EMAIL must be an email address." ;; esac

mkdir -p "$DATA_DIR"
[ -w "$DATA_DIR" ] || die "$DATA_DIR is not writable (is the volume mounted?)"

# Go heap limit from the container's memory limit (85 %), unless set already.
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
    mem=$(cat /sys/fs/cgroup/memory.max)
    case "$mem" in
        ''|max|*[!0-9]*) ;;
        *) GOMEMLIMIT="$((mem / 100 * 85))B"; export GOMEMLIMIT; log "GOMEMLIMIT=$GOMEMLIMIT" ;;
    esac
fi

# Encryption key (2FA secrets, reset tokens, calendar feed URLs): base64 of 32
# bytes, generated once and kept on the volume next to the database.
KEY_FILE="$DATA_DIR/encryption.key"
if [ -z "${SCRUMBOY_ENCRYPTION_KEY:-}" ]; then
    if [ ! -s "$KEY_FILE" ]; then
        (umask 077; head -c 32 /dev/urandom | base64 > "$KEY_FILE.tmp" && mv "$KEY_FILE.tmp" "$KEY_FILE")
        log "generated a new encryption key at $KEY_FILE (back it up with the database)"
    fi
    SCRUMBOY_ENCRYPTION_KEY=$(cat "$KEY_FILE")
    export SCRUMBOY_ENCRYPTION_KEY
fi

SETUP_URL="http://127.0.0.1:$SETUP_PORT"
setup_pid=""
stop_setup() {
    if [ -n "$setup_pid" ]; then
        kill -TERM "$setup_pid" 2>/dev/null || true
        wait "$setup_pid" 2>/dev/null || true
        setup_pid=""
    fi
}
trap 'stop_setup; rm -f /tmp/bootstrap.json /tmp/bootstrap.out' EXIT

start_setup() {
    BIND_ADDR="127.0.0.1:$SETUP_PORT" /scrumboy >/tmp/setup.log 2>&1 &
    setup_pid=$!
    i=0
    until wget -q -T 2 -O /dev/null "$SETUP_URL/healthz" 2>/dev/null; do
        kill -0 "$setup_pid" 2>/dev/null || { cat /tmp/setup.log >&2; die "setup instance exited before it was ready"; }
        i=$((i + 1)); [ "$i" -lt 120 ] || die "setup instance not ready after 60 s"
        sleep 0.5
    done
}

bootstrap_available() {
    st=$(wget -q -T 5 -O - "$SETUP_URL/api/auth/status") || die "could not read /api/auth/status"
    echo "$st" | grep -Eq '"bootstrapAvailable"[[:space:]]*:[[:space:]]*true'
}

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

PW_HASH_FILE="$DATA_DIR/.owner-password.sha256"
pw_hash=$(printf '%s' "$OWNER_PASSWORD" | sha256sum | cut -d' ' -f1)

# 1. Create the Owner on a loopback-only instance before the public port opens.
start_setup
if bootstrap_available; then
    (umask 077; printf '{"email":"%s","password":"%s","name":"%s"}' \
        "$(json_escape "$OWNER_EMAIL")" "$(json_escape "$OWNER_PASSWORD")" "$(json_escape "$OWNER_NAME")" > /tmp/bootstrap.json)
    wget -q -T 20 -O /tmp/bootstrap.out --header 'Content-Type: application/json' --header 'X-Scrumboy: 1' \
        --post-file /tmp/bootstrap.json "$SETUP_URL/api/auth/bootstrap" 2>/tmp/bootstrap.err \
        || { cat /tmp/bootstrap.err >&2; die "owner bootstrap failed; refusing to open the public port"; }
    rm -f /tmp/bootstrap.json /tmp/bootstrap.out
    bootstrap_available && die "owner bootstrap did not take effect; refusing to open the public port"
    (umask 077; echo "$pw_hash" > "$PW_HASH_FILE")
    log "created the Owner account $OWNER_EMAIL"
else
    log "Owner account already exists"
fi
stop_setup

# 2. Password rotation: if SCRUMBOY_OWNER_PASSWORD changed since the last boot,
#    set it on the Owner with upstream's recover-owner (server is not running).
if [ ! -s "$PW_HASH_FILE" ]; then
    (umask 077; echo "$pw_hash" > "$PW_HASH_FILE")
elif [ "$(cat "$PW_HASH_FILE")" != "$pw_hash" ]; then
    if printf '%s\n' "$OWNER_PASSWORD" | /scrumboy recover-owner --email "$OWNER_EMAIL" --password-stdin >/tmp/recover.log 2>&1; then
        (umask 077; echo "$pw_hash" > "$PW_HASH_FILE")
        log "SCRUMBOY_OWNER_PASSWORD changed: Owner password updated and sessions signed out"
    else
        log "WARNING: SCRUMBOY_OWNER_PASSWORD changed but the Owner password was not updated (is $OWNER_EMAIL still the Owner's email?): $(tail -n 1 /tmp/recover.log)"
    fi
fi
rm -f /tmp/recover.log /tmp/setup.log /tmp/bootstrap.err
trap - EXIT
unset OWNER_PASSWORD pw_hash

# 3. The real server, as PID 1 so it gets Railway's signals directly.
export BIND_ADDR=":$PORT"
log "serving on :$PORT, data in $DATA_DIR"
exec /scrumboy "$@"
