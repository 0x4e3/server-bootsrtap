#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$output_dir"
}
trap cleanup EXIT

"$repo_root/.venv/bin/ansible-playbook" \
    -i localhost, \
    -c local \
    "${BASH_SOURCE[0]%/*}/render.yaml" \
    -e "output_dir=$output_dir"

python3 -m json.tool "$output_dir/daemon.json" >/dev/null
docker compose -f "$output_dir/traefik-compose.yaml" config --quiet
docker run --rm \
    --cap-add NET_ADMIN \
    --volume "$output_dir:/fixtures:ro" \
    ubuntu:24.04 \
    sh -euc 'apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends iptables openssh-server >/dev/null && mkdir --parents /run/sshd && sshd -t -f /fixtures/sshd_config && iptables-restore --test /fixtures/rules.v4'
