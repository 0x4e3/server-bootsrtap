#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lima_home="$HOME"
work_dir="$(mktemp -d)"
control_path_dir="$(mktemp -d /tmp/server-bootstrap-ssh.XXXXXX)"
instance_name="server-bootstrap-e2e-$$"

lima() {
    HOME="$lima_home" limactl "$@"
}

cleanup() {
    lima delete --force --tty=false "$instance_name" || true
    rm -rf "$work_dir"
    rm -rf "$control_path_dir"
}
trap cleanup EXIT

test_key="$work_dir/bootstrap-test-key"
ssh-keygen -q -t ed25519 -N "" -f "$test_key"

lima start \
    --name "$instance_name" \
    --containerd=none \
    --cpus 2 \
    --memory 2 \
    --disk 10 \
    --mount-none \
    --tty=false \
    template:ubuntu-24.04

initial_user="$(lima shell "$instance_name" -- whoami)"
ssh_config="$(lima list --format '{{.SSHConfigFile}}' "$instance_name")"
ssh_port="$(awk '$1 == "Port" { print $2; exit }' "$ssh_config")"

lima shell "$instance_name" -- mkdir --parents .ssh
lima shell "$instance_name" -- chmod 0700 .ssh
lima shell "$instance_name" -- sh -c 'cat >> "$HOME/.ssh/authorized_keys"' < "$test_key.pub"
lima shell "$instance_name" -- chmod 0600 .ssh/authorized_keys

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
          ansible_user: $initial_user
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
        -e bootstrap_login_user_sudo_nopasswd=true \
        -e bootstrap_reboot_timeout=600
    "${ansible_playbook[@]}" \
        -e bootstrap_login_user_name=bootstrap-test \
        -e bootstrap_login_user_sudo_nopasswd=true \
        -e bootstrap_manage_updates=false
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
