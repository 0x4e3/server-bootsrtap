# Server Bootstrap

[![CI matrix Ubuntu 22.04](https://img.shields.io/badge/CI%20matrix-Ubuntu%2022.04-555?logo=ubuntu&logoColor=white)](https://github.com/0x4e3/server-bootsrtap/actions/workflows/checks.yaml)
[![CI matrix Ubuntu 24.04](https://img.shields.io/badge/CI%20matrix-Ubuntu%2024.04-555?logo=ubuntu&logoColor=white)](https://github.com/0x4e3/server-bootsrtap/actions/workflows/checks.yaml)
[![CI matrix Ubuntu 26.04](https://img.shields.io/badge/CI%20matrix-Ubuntu%2026.04-555?logo=ubuntu&logoColor=white)](https://github.com/0x4e3/server-bootsrtap/actions/workflows/checks.yaml)
[![Lint](https://github.com/0x4e3/server-bootsrtap/actions/workflows/lint.yaml/badge.svg)](https://github.com/0x4e3/server-bootsrtap/actions/workflows/lint.yaml)
[![Ansible Core](https://img.shields.io/badge/ansible--core-2.19%2B-EE0000?logo=ansible&logoColor=white)](https://docs.ansible.com/ansible/latest/)
[![Python](https://img.shields.io/badge/python-3.12%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-4C1)](LICENSE)

Production-oriented Ansible project for bootstrapping fresh Ubuntu 24.04
servers. It creates a key-only managed user, hardens SSH, applies an IPv4
firewall, installs operational tools and CrowdSec, and optionally deploys
Docker, Traefik, Vaultwarden, 3x-ui, and Telemt.

## Documentation

Read the **[Wiki](https://github.com/0x4e3/server-bootsrtap/wiki)** before a
real deployment. It is the operational source of truth and includes:

- copy-paste setup from a fresh server to a hardened host;
- Ansible Vault, inventory, host-group, and variable examples;
- safe SSH port migration, cloud firewall, IPv6, and CrowdSec requirements;
- Docker, Traefik, ACME, dashboard, Vaultwarden, 3x-ui, and Telemt setup;
- validation, recovery, troubleshooting, CI, and disposable test VM commands.

## Deployment Order

Do not skip stages:

```bash
# 1. Create the bootstrap user from the initial SSH account.
uv run ansible-playbook playbooks/bootstrap.yaml

# 2. First setup run while the server still listens on port 22.
uv run ansible-playbook playbooks/setup.yaml -e 'setup_ssh_port=22'

# 3. Later setup runs use the hardened SSH port by default.
uv run ansible-playbook playbooks/setup.yaml

# 4. Deploy configured application groups.
uv run ansible-playbook playbooks/apps.yaml
```

Before the first setup run, allow the hardened SSH port in every upstream
firewall or security group. A `traefik_hosts` server also needs public TCP 80
and 443. The full preflight checklist is in the [Wiki Quick
Start](https://github.com/0x4e3/server-bootsrtap/wiki/Quick-Start).

## Repository Layout

- `inventories/production/hosts.yaml`: managed hosts and group membership.
- `group_vars/`: safe baseline and group-specific variables.
- `group_vars/vault.yaml`: encrypted secrets, ignored by Git.
- `host_vars/`: per-host overrides.
- `playbooks/`: bootstrap, baseline setup, and application deployment.
- `roles/`: idempotent provisioning roles.

## Development

```bash
uv sync --group dev
uv run pre-commit install
uv run pre-commit install --hook-type commit-msg

just check-worktree
just test-lightweight
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development prerequisites and the
[Wiki Testing and CI](https://github.com/0x4e3/server-bootsrtap/wiki/Testing-and-CI)
page for the full test matrix and disposable Yandex Cloud VM workflow.
