# Server Bootstrap

[![CI](https://github.com/0x4e3/server-bootsrtap/actions/workflows/checks.yaml/badge.svg)](https://github.com/0x4e3/server-bootsrtap/actions/workflows/checks.yaml)

Production-oriented Ansible project for bootstrapping Ubuntu 24.04 servers from a fresh install.

## Contents

- [What It Does](#what-it-does)
- [Project Layout](#project-layout)
- [Host Groups](#host-groups)
- [Roles](#roles)
- [Inventory Example](#inventory-example)
- [Variable Example](#variable-example)
- [Development](#development)
- [Usage](#usage)
- [Semaphore Notes](#semaphore-notes)
- [Operational Notes](#operational-notes)

## What It Does

- Creates the non-root bootstrap login user and installs its SSH key from Ansible Vault
- Updates the system with `apt`, then reboots during the one-time bootstrap
- Configures SSH hardening, the IPv4 firewall, and operational tools through the repeatable setup playbook
- Sets a shared bootstrap password and forces its change on first login

## Project Layout

```text
.
├── ansible.cfg
├── group_vars/
│   ├── all.yaml
│   ├── telemt_hosts.yaml
│   ├── three_x_ui_hosts.yaml
│   ├── traefik_hosts.yaml
│   └── vaultwarden_hosts.yaml
├── host_vars/
│   └── ubuntu-01.yaml
├── inventories/
│   └── production/
│       └── hosts.yaml
├── playbooks/
│   ├── bootstrap.yaml
│   ├── apps.yaml
│   └── setup.yaml
└── roles/
    ├── system_tools/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   └── tasks/main.yaml
    ├── ssh_hardening/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   ├── tasks/main.yaml
    │   └── templates/sshd_config.j2
    ├── iptables_firewall/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   ├── tasks/main.yaml
    │   └── templates/rules.v4.j2
    ├── docker/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   ├── tasks/main.yaml
    │   └── templates/daemon.json.j2
    ├── crowdsec/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   └── tasks/main.yaml
    ├── traefik/
    │   ├── defaults/main.yaml
    │   ├── handlers/main.yaml
    │   ├── tasks/main.yaml
    │   └── templates/compose.yaml.j2
    └── users/
        ├── defaults/main.yaml
        ├── handlers/main.yaml
        └── tasks/main.yaml
    └── apps/
        ├── three_x_ui/
        ├── telemt/
        └── vaultwarden/
```

## Host Groups

- Every host receives SSH hardening, iptables, operational tools, native CrowdSec, and the firewall bouncer.
- `traefik_hosts` receive Docker Engine, Buildx, Compose, and Traefik.
- `vaultwarden_hosts`, `three_x_ui_hosts`, and `telemt_hosts` receive their corresponding application through `playbooks/apps.yaml`.
- Every service host must also belong to `traefik_hosts`, which opens TCP `80` and `443`. Application ports stay closed at the host firewall.

## Roles

### `users`

Purpose:

- Creates Linux users from `bootstrap_users`
- Sets each user's shell, groups, and home directory
- Sets an initial shared bootstrap password once
- Forces a password change on first login
- Installs authorized SSH keys
- Manages per-user `NOPASSWD` sudoers files when explicitly requested

Input variables:

- `bootstrap_users`
- `bootstrap_users_default_shell`
- `bootstrap_user_append_groups`
- `bootstrap_users_default_password`
- `bootstrap_users_password_salt`

Example:

```yaml
bootstrap_users:
  - name: deploy
    home: /srv/deploy
    shell: /bin/bash
    groups:
      - sudo
    ssh_public_keys:
      - "ssh-ed25519 AAAAC3Nza... deploy@example"
    sudo_nopasswd: false
    force_password_change: true
    create_home: true
    state: present

  - name: ops
    groups:
      - sudo
    ssh_public_keys:
      - "ssh-ed25519 AAAAC3Nza... ops@example"
```

### `ssh_hardening`

Purpose:

- Installs `openssh-server`
- Renders a hardened `/etc/ssh/sshd_config.d/00-ansible-hardening.conf`
- Validates the config before applying it
- Configures the Ubuntu SSH socket listen port
- Restarts SSH service and socket safely
- Waits for the new SSH port to become reachable
- Switches Ansible to the configured SSH port for subsequent tasks

Input variables:

- `ssh_hardening_port`
- `ssh_hardening_current_port`
- `ssh_hardening_permit_root_login`
- `ssh_hardening_password_authentication`
- `ssh_hardening_max_auth_tries`
- `ssh_hardening_ciphers`
- `ssh_hardening_macs`
- `ssh_hardening_kex_algorithms`
- `ssh_hardening_hostkey_algorithms`
- `ssh_hardening_extra_options`

By default, `ssh_hardening_allow_users` allows `bootstrap_login_user_name` when set.

### `system_tools`

Purpose:

- Installs a standard troubleshooting and network toolkit
- Uses Ubuntu 24.04 package names via `apt`
- Is designed to run independently through `playbooks/setup.yaml`

Input variables:

- `system_tools_packages`

Default package set:

```yaml
system_tools_packages:
  - mtr
  - traceroute
  - iperf3
  - nmap
  - iftop
  - iotop
  - btop
```

### `iptables_firewall`

Purpose:

- Installs `iptables-persistent` and manages persistent IPv4 filter rules
- Allows established connections and loopback traffic
- Drops invalid packets and rejects all new inbound traffic except configured TCP and UDP ports
- Baseline configuration allows only `ssh_hardening_port`; `traefik_hosts` also allow Traefik entrypoints `80` and `443`

Input variables:

- `iptables_open_tcp_ports`
- `iptables_open_udp_ports`

Example:

```yaml
iptables_open_tcp_ports:
  - "{{ ssh_hardening_port }}"
iptables_open_udp_ports:
  - 500
  - 4500
```

### `docker`

Purpose:

- Installs Docker Engine from Docker's official Ubuntu repository
- Installs Buildx and Docker Compose v2 plugins
- Enables BuildKit and configures bounded local container logs
- Adds configured users to the `docker` group
- Runs on `traefik_hosts`

Input variables:

- `docker_users`
- `docker_daemon_config`
- `docker_packages`

Default daemon configuration:

```yaml
docker_daemon_config:
  features:
    buildkit: true
  log-driver: local
  log-opts:
    max-size: "10m"
    max-file: "3"
```

Use `docker buildx build` for advanced builds and `docker compose up -d` to run Compose projects. Users in the `docker` group have root-equivalent access to the host. Expose application traffic only through Traefik on `traefik_hosts`, not by adding individual application ports to the firewall.

### `traefik`

Purpose:

- Runs Traefik on `traefik_hosts` with Docker discovery disabled by default for unlabeled containers
- Listens only on TCP `80` and `443`, redirects HTTP to HTTPS, and obtains certificates through Let's Encrypt HTTP-01
- Stores ACME data in `/opt/traefik/letsencrypt/acme.json` and access logs in `/opt/traefik/logs/access.log`
- Creates the shared external Docker network `traefik` for proxied applications

Input variables:

- `traefik_acme_email`
- `traefik_image`
- `traefik_docker_network`
- `traefik_dashboard_enabled`
- `traefik_dashboard_host`
- `traefik_dashboard_username`
- `traefik_dashboard_password`

Application containers must join the `traefik` network and set explicit `traefik.enable=true` labels. The dashboard is disabled by default. To expose it over HTTPS, set `traefik_dashboard_enabled: true`, its hostname and username in `group_vars/traefik_hosts.yaml`, and `vault_traefik_dashboard_password` in `group_vars/vault.yaml`. It is protected with HTTP basic authentication.

### `vaultwarden`

Purpose:

- Runs Vaultwarden with its SQLite database persisted in `/opt/vaultwarden/data`
- Exposes the Bitwarden-compatible web vault only through Traefik and HTTPS
- Disables public registration by default

Required variables:

- `vaultwarden_domain`
- `vaultwarden_admin_token`, supplied from Ansible Vault

### `three_x_ui`

Purpose:

- Runs 3x-ui with its SQLite database persisted in `/opt/3x-ui/data`
- Exposes its web panel through Traefik and HTTPS
- Routes each configured Xray inbound from public `443` to its own internal port by TLS SNI

Required variables:

- `three_x_ui_panel_domain`
- `three_x_ui_inbounds`

Each inbound needs a unique hostname and internal port. Configure the matching port and TLS hostname in 3x-ui itself. Traefik passes this TLS traffic through, so the Xray inbound, not Traefik, must hold a valid certificate for its hostname. Use DNS-01 or another certificate flow that does not require direct public access to the Xray container.

### `telemt`

Purpose:

- Runs the pinned `whn0thacked/telemt-docker:3.3.39` image on `telemt_hosts`
- Keeps the Telemt TOML configuration outside the container at `/opt/telemt/config/telemt.toml`
- Routes fake-TLS traffic through Traefik TCP passthrough by `HostSNI`

Required variables:

- `telemt_config`, supplied from Ansible Vault
- `telemt_sni_hostname`
- `telemt_listen_port`, default `1234`

`telemt_sni_hostname` must equal the fake-TLS domain in `telemt_config` (`censorship.tls_domain`). The compose labels use `traefik.tcp`, not the typo `traefik.tcl`.

### `crowdsec`

Purpose:

- Installs CrowdSec and `crowdsec-firewall-bouncer-iptables` from the official APT repository
- Installs and enables `rsyslog` so SSH events are written to `/var/log/auth.log`
- Installs the `crowdsecurity/sshd` collection and acquires SSH logs
- Updates installed Hub content daily through a managed cron job
- Applies decisions to `INPUT` on every host and `DOCKER-USER` on `traefik_hosts`

Input variables:

- `crowdsec_collections`
- `crowdsec_hub_update_enabled`
- `crowdsec_hub_update_hour`
- `crowdsec_hub_update_minute`
- `crowdsec_firewall_bouncer_iptables_chains`
- `crowdsec_acquisitions`

The native firewall bouncer consumes CrowdSec `ban` decisions. Its package generates and stores the local API key in the bouncer configuration with restricted permissions.

## Inventory Example

`inventories/production/hosts.yaml`

```yaml
all:
  children:
    bootstrap:
      hosts:
        server-01:
          ansible_host: 203.0.113.10
          ansible_user: root
        server-02:
        server-03:
        server-04:
    traefik_hosts:
      hosts:
        server-01:
        server-02:
        server-03:
        server-04:
    vaultwarden_hosts:
      hosts:
        server-01:
    three_x_ui_hosts:
      hosts:
        server-01:
        server-02:
        server-03:
    telemt_hosts:
      hosts:
        server-01:
        server-02:
```

Initial bootstrap should connect as `root` or another account that already has sudo privileges.

## Variable Example

`group_vars/all.yaml`

```yaml
bootstrap_manage_updates: true
bootstrap_reboot_timeout: 1800
ansible_ssh_common_args: "-o StrictHostKeyChecking=accept-new"

bootstrap_users_default_shell: /bin/bash
bootstrap_users_default_password: "{{ vault_bootstrap_users_default_password }}"
bootstrap_users_password_salt: "{{ vault_bootstrap_users_password_salt }}"
bootstrap_login_user_name: bootstraper
bootstrap_login_user_groups:
  - sudo
bootstrap_login_user_sudo_nopasswd: true
bootstrap_login_user_force_password_change: false
bootstrap_login_user_ssh_public_keys: "{{ vault_bootstrap_login_user_ssh_public_keys }}"

ssh_hardening_port: 2222
setup_ssh_port: "{{ ssh_hardening_port }}"
ssh_hardening_permit_root_login: "no"
ssh_hardening_password_authentication: "no"
ssh_hardening_max_auth_tries: 3
```

`group_vars/vault.yaml` must be created with Ansible Vault and define the bootstrap secrets:

```yaml
vault_bootstrap_login_user_ssh_public_keys:
  - "ssh-ed25519 AAAAC3Nza... bootstraper@example"
vault_bootstrap_users_default_password: "use-a-strong-random-password"
vault_bootstrap_users_password_salt: "use-a-random-sha512-crypt-salt"
vault_traefik_acme_email: "ops@example.com"
vault_traefik_dashboard_password: "use-a-strong-random-password"
vault_vaultwarden_admin_token: "a-long-random-admin-token"
```

Set the application variables in their corresponding host-group files:

```yaml
 # group_vars/vaultwarden_hosts.yaml
 vaultwarden_domain: vault.example.com
 vaultwarden_admin_token: "{{ vault_vaultwarden_admin_token }}"
```

```yaml
# group_vars/three_x_ui_hosts.yaml

three_x_ui_panel_domain: xui.example.com
three_x_ui_inbounds:
  - hostname: vless.example.com
    port: 10001
  - hostname: trojan.example.com
    port: 10002

```

```yaml
# group_vars/telemt_hosts.yaml
telemt_sni_hostname: habr.com
telemt_config: "{{ vault_telemt_config }}"
```

Store the full Telemt TOML, including proxy secrets, in `vault_telemt_config` in `group_vars/vault.yaml`. Its `[server] port` must match `telemt_listen_port`, and `[censorship] tls_domain` must match `telemt_sni_hostname`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, checks, and Bootstrap
test instructions.

## Usage

Run the one-time bootstrap from the initial SSH port:

```bash
ansible-playbook playbooks/bootstrap.yaml
```

Run setup for the first time from the initial SSH port. The example uses the default port `22`:

```bash
ansible-playbook playbooks/setup.yaml -e 'setup_ssh_port=22'
```

Run setup again after SSH hardening:

```bash
ansible-playbook playbooks/setup.yaml
```

Deploy application roles after the matching hosts have completed setup:

```bash
ansible-playbook playbooks/apps.yaml
```

Run against a specific inventory explicitly:

```bash
ansible-playbook -i inventories/production/hosts.yaml playbooks/bootstrap.yaml
```

Run the first setup against a specific inventory:

```bash
ansible-playbook \
  -i inventories/production/hosts.yaml \
  playbooks/setup.yaml \
  -e 'setup_ssh_port=22'
```

Override variables at runtime:

```bash
ansible-playbook \
  -i inventories/production/hosts.yaml \
  playbooks/setup.yaml \
  -e 'setup_ssh_port=22' \
  -e 'ssh_hardening_port=2223'
```

Limit to one host:

```bash
ansible-playbook \
  -i inventories/production/hosts.yaml \
  playbooks/bootstrap.yaml \
  --limit ubuntu-01
```

## Semaphore Notes

- Use the repository root as the project source.
- Set the inventory to `inventories/production/hosts.yaml`.
- Use `playbooks/bootstrap.yaml` once to create the bootstrap user, update packages, and reboot.
- Run `playbooks/setup.yaml -e 'setup_ssh_port=22'` once after bootstrap to configure SSH, the firewall, operational tools, Docker, and Traefik.
- Use `playbooks/apps.yaml` to deploy Vaultwarden, 3x-ui, and Telemt to their service groups.
- Store the bootstrap user's SSH key in `group_vars/vault.yaml`, Ansible Vault, or an equivalent Semaphore secret-backed vault file.
- Store other environment-specific values in `group_vars`, `host_vars`, or Semaphore extra vars.
- No interactive prompts are required.
- The project is safe to split into separate templates later because roles are variable-driven and idempotent.

## Operational Notes

- Ensure every managed user has at least one valid SSH public key before disabling password authentication.
- Store `vault_bootstrap_login_user_ssh_public_keys`, `vault_bootstrap_users_default_password`, and `vault_bootstrap_users_password_salt` in Ansible Vault or Semaphore secrets rather than plain text.
- `vault_bootstrap_users_password_salt` is sanitized to valid `sha512_crypt` characters automatically; avoid symbols other than letters, digits, `.`, and `/` if you want predictable salts.
- If you see `Host key verification failed`, either add the server key to `known_hosts` with `ssh-keyscan` or keep `ansible_ssh_common_args: "-o StrictHostKeyChecking=accept-new"` for first bootstrap.
- If you change `ssh_hardening_port`, update your firewall and security group rules first.
- On Ubuntu 24.04, SSH may use socket activation by default; this project configures and restarts `ssh.socket` so the custom SSH port is applied.
- The first bootstrap play uses the inventory connection user only to create `bootstrap_login_user_name`; package updates and reboot run after reconnecting as that user.
- `bootstrap_login_user_force_password_change` defaults to `false` so bootstrap can reconnect non-interactively with the vault-managed SSH key.
- The first `playbooks/setup.yaml` run must use `setup_ssh_port` set to the current SSH port. SSH hardening then resets the connection and uses `ssh_hardening_port` for the remaining setup roles.
- When the controller reaches a host through NAT, set `ssh_hardening_current_port` to the port exposed on the host itself so the firewall can preserve it during an SSH port migration.
- Subsequent `playbooks/setup.yaml` runs default `setup_ssh_port` to `ssh_hardening_port`.
- Add every service host to `traefik_hosts`, then add it to the relevant `vaultwarden_hosts`, `three_x_ui_hosts`, or `telemt_hosts` groups.
- The bootstrap playbook reboots the server when `bootstrap_manage_updates` is `true`.
- Ubuntu 24.04 provides `iperf3`, so that package is used for the requested `iperf` tool in `system_tools_packages`.
- The bootstrap password is only applied once per managed user; later runs do not overwrite user-changed passwords unless you remove the marker file in `{{ bootstrap_users_password_marker_dir }}`.
- With SSH password and keyboard-interactive authentication disabled, an expired password generally must be changed from console access or after temporarily relaxing SSH auth policy.
