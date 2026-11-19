#!/bin/sh
set -eu
umask 077

# Put the official tailscale and tailscaled binaries in this directory's bin/.
# Keep the state directory private. It stores this server's device identity.
ACCESS_DIR="$HOME/.local/share/tailscale-private-ssh"
BIN_DIR="$ACCESS_DIR/bin"
SOCKET="$ACCESS_DIR/tailscaled.sock"
mkdir -p "$ACCESS_DIR"
chmod 700 "$ACCESS_DIR"

# A responsive local API means the daemon already exists. Its login state can
# still be NeedsLogin. Starting a second daemon would reuse its state and socket.
if "$BIN_DIR/tailscale" --socket="$SOCKET" status --json >/dev/null 2>&1 ||
   "$BIN_DIR/tailscale" --socket="$SOCKET" version --daemon >/dev/null 2>&1; then
    exit 0
fi

# Run without a kernel TUN device. No subnet routes or public listener are
# configured here. nohup keeps the process from closing with the terminal.
nohup "$BIN_DIR/tailscaled" --tun=userspace-networking \
    --state="$ACCESS_DIR/tailscaled.state" --socket="$SOCKET" \
    --port=0 >"$ACCESS_DIR/tailscaled.log" 2>&1 </dev/null &
daemon_pid=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$daemon_pid" 2>/dev/null || break
    if "$BIN_DIR/tailscale" --socket="$SOCKET" version --daemon >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done
printf '检查启动日志：%s\n' "$ACCESS_DIR/tailscaled.log" >&2
exit 1
