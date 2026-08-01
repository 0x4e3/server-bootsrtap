#!/usr/bin/env sh
set -eu

printf '%s\n' "$AUTHORIZED_KEY" > /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys

exec /usr/sbin/sshd -D -e
