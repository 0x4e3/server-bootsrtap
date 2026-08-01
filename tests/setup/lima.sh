#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lima_home="$HOME"
work_dir="$(mktemp -d)"
control_path_dir="$(mktemp -d /tmp/server-bootstrap-ssh.XXXXXX)"
instance_name="server-bootstrap-setup-e2e-$$"
bootstrap_user="bootstrap-test"
ssh_hardening_port=22571

lima() {
    HOME="$lima_home" limactl "$@"
}

cleanup() {
    if [[ "${KEEP_TEST_VM:-false}" == "true" ]]; then
        return
    fi
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
    --port-forward "$ssh_hardening_port:$ssh_hardening_port,static=true" \
    --tty=false \
    template:ubuntu-24.04

ssh_config="$(lima list --format '{{.SSHConfigFile}}' "$instance_name")"
initial_ssh_port="$(awk '$1 == "Port" { print $2; exit }' "$ssh_config")"

lima shell "$instance_name" -- sudo useradd --create-home --shell /bin/bash --groups sudo "$bootstrap_user"
lima shell "$instance_name" -- sudo install --directory --owner "$bootstrap_user" --group "$bootstrap_user" --mode 0700 "/home/$bootstrap_user/.ssh"
lima shell "$instance_name" -- sudo tee "/home/$bootstrap_user/.ssh/authorized_keys" < "$test_key.pub" >/dev/null
lima shell "$instance_name" -- sudo chown "$bootstrap_user:$bootstrap_user" "/home/$bootstrap_user/.ssh/authorized_keys"
lima shell "$instance_name" -- sudo chmod 0600 "/home/$bootstrap_user/.ssh/authorized_keys"
lima shell "$instance_name" -- sudo sh -c "printf '%s ALL=(ALL) NOPASSWD:ALL\\n' '$bootstrap_user' > /etc/sudoers.d/90-$bootstrap_user"
lima shell "$instance_name" -- sudo chmod 0440 "/etc/sudoers.d/90-$bootstrap_user"

test_repo="$work_dir/repo"
mkdir "$test_repo"
tar --exclude=.git --exclude=.venv --exclude=group_vars/vault.yaml -cf - -C "$repo_root" . | tar -xf - -C "$test_repo"

cat > "$test_repo/group_vars/vault.yaml" <<EOF
---
vault_traefik_acme_email: "bootstrap-test@example.invalid"
vault_traefik_dashboard_password: "bootstrap-test-password"
EOF

cat > "$work_dir/inventory.yaml" <<EOF
---
all:
  children:
    traefik_hosts:
      hosts:
        setup-test:
          ansible_host: 127.0.0.1
          ansible_port: $initial_ssh_port
          ansible_user: $bootstrap_user
          ansible_ssh_private_key_file: $test_key
EOF

export HOME="$work_dir/home"
export ANSIBLE_SSH_CONTROL_PATH_DIR="$control_path_dir"
mkdir "$HOME"

ansible_playbook=("$repo_root/.venv/bin/ansible-playbook" -i "$work_dir/inventory.yaml" playbooks/setup.yaml)
ansible_ssh_options="{\"ansible_ssh_common_args\":\"-oUserKnownHostsFile=$work_dir/known_hosts -oStrictHostKeyChecking=accept-new\"}"
(
    cd "$test_repo"
    "${ansible_playbook[@]}" -e "$ansible_ssh_options" -e "bootstrap_login_user_name=$bootstrap_user" -e "setup_ssh_port=$initial_ssh_port" -e "traefik_acme_email=bootstrap-test@example.invalid"
    "${ansible_playbook[@]}" -e "$ansible_ssh_options" -e "bootstrap_login_user_name=$bootstrap_user" -e "setup_ssh_port=$ssh_hardening_port" -e "traefik_acme_email=bootstrap-test@example.invalid" | tee "$work_dir/setup-second-run.log"
)

grep --extended-regexp "setup-test[[:space:]]+:.*changed=0" "$work_dir/setup-second-run.log"

ssh_options=(
    -i "$test_key"
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$work_dir/known_hosts"
    -p "$ssh_hardening_port"
)
test "$(ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 id -un)" = "$bootstrap_user"
ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "sudo -n true"

if ssh -i "$test_key" -o BatchMode=yes -o ConnectTimeout=5 -p "$initial_ssh_port" "$bootstrap_user"@127.0.0.1 true; then
    exit 1
fi

ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "command -v mtr traceroute iperf3 nmap iftop iotop btop"
ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "sudo systemctl is-active docker crowdsec crowdsec-firewall-bouncer"
ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "sudo docker inspect --format '{{.State.Running}}' traefik | grep --fixed-strings true"
ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "sudo docker port traefik 80/tcp | grep --fixed-strings ':80'"
ssh "${ssh_options[@]}" "$bootstrap_user"@127.0.0.1 "sudo iptables -S INPUT | grep --fixed-strings -- '-P INPUT DROP'"
