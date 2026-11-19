#!/bin/sh
set -eu

ACCESS_DIR="$HOME/.local/share/tailscale-private-ssh"
TS="$ACCESS_DIR/bin/tailscale"
SOCKET="$ACCESS_DIR/tailscaled.sock"

# The upstream is an OpenSSH service on the same container. Verify its
# authentication settings before running this script. Keep the local and
# tailnet ports separate so neither collides with the platform's SSH entry.
LOCAL_PORT="${LOCAL_PORT:-22222}"
TAILNET_PORT="${TAILNET_PORT:-2222}"
for port in "$LOCAL_PORT" "$TAILNET_PORT"; do
    case "$port" in ''|*[!0-9]*) printf '端口必须是数字\n' >&2; exit 1 ;; esac
    [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
done

# Confirm authorization and verify that an SSH service answers on loopback.
# Merely creating a Serve rule would leave a broken connection if sshd is down.
"$TS" --socket="$SOCKET" ip -4
python3 - "$LOCAL_PORT" <<'PY'
import socket
import sys

with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=5) as connection:
    with connection.makefile("rb") as stream:
        if not stream.readline(256).startswith(b"SSH-"):
            raise SystemExit("本地端口没有返回 SSH 握手标识")
PY

# Serve publishes TCP to the private tailnet according to its access policy.
# --bg stores the rule so it can resume when the daemon runs again.
"$TS" --socket="$SOCKET" serve --bg --tcp="$TAILNET_PORT" "tcp://127.0.0.1:$LOCAL_PORT"
"$TS" --socket="$SOCKET" serve status
