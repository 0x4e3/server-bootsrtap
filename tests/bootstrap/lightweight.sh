#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work_dir="$(mktemp -d)"
control_path_dir="$(mktemp -d /tmp/server-bootstrap-ssh.XXXXXX)"
container_id=""

cleanup() {
    if [[ -n "$container_id" ]]; then
        docker rm --force "$container_id" >/dev/null
    fi
    rm -rf "$work_dir"
    rm -rf "$control_path_dir"
}
trap cleanup EXIT

test_key="$work_dir/bootstrap-test-key"
ssh-keygen -q -t ed25519 -N "" -f "$test_key"

docker build \
    --tag server-bootstrap-test:latest \
    "$repo_root/tests/bootstrap"
container_id="$(docker run \
    --detach \
    --env "AUTHORIZED_KEY=$(<"$test_key.pub")" \
    --publish 127.0.0.1::22 \
    server-bootstrap-test:latest)"
ssh_port="$(docker port "$container_id" 22/tcp | cut -d: -f2)"

test_repo="$work_dir/repo"
mkdir "$test_repo"
tar --exclude=.git --exclude=.venv --exclude=group_vars/vault.yaml -cf - -C "$repo_root" . | tar -xf - -C "$test_repo"

cat > "$test_repo/group_vars/vault.yaml" <<EOF
---
vault_bootstrap_login_user_ssh_public_keys:
  - "$(<"$test_key.pub")"
vault_bootstrap_users_default_password: "bootstrap-test-password"
vault_bootstrap_users_password_salt: "bootstrap-test-salt"
EOF

cat > "$work_dir/inventory.yaml" <<EOF
---
all:
  children:
    bootstrap:
      hosts:
        bootstrap-test:
          ansible_host: 127.0.0.1
          ansible_port: $ssh_port
          ansible_user: root
          ansible_ssh_private_key_file: $test_key
EOF

export HOME="$work_dir/home"
export ANSIBLE_SSH_CONTROL_PATH_DIR="$control_path_dir"
mkdir "$HOME"

ansible_playbook=("$repo_root/.venv/bin/ansible-playbook" -i "$work_dir/inventory.yaml" playbooks/bootstrap.yaml)
(
    cd "$test_repo"
    "${ansible_playbook[@]}" \
        -e bootstrap_login_user_name=bootstrap-test \
        -e bootstrap_manage_updates=false \
        -e bootstrap_login_user_sudo_nopasswd=true
    "${ansible_playbook[@]}" \
        -e bootstrap_login_user_name=bootstrap-test \
        -e bootstrap_manage_updates=false \
        -e bootstrap_login_user_sudo_nopasswd=true
)

ssh_options=(
    -i "$test_key"
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$work_dir/known_hosts"
    -p "$ssh_port"
)
test "$(ssh "${ssh_options[@]}" bootstrap-test@127.0.0.1 id -un)" = "bootstrap-test"
ssh "${ssh_options[@]}" bootstrap-test@127.0.0.1 "sudo -n true"
