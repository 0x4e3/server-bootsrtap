# Contributing

## Prerequisites

- [uv](https://docs.astral.sh/uv/)
- Docker Desktop for the Bootstrap integration test
- [Lima](https://lima-vm.io/) for the full local VM test on macOS

## Setup

Install the repository-local tools and Git hooks:

```bash
uv sync --group dev
uv run pre-commit install
uv run pre-commit install --hook-type commit-msg
```

The commit-msg hook requires Conventional Commit subjects, for example
`feat(traefik): add secured dashboard`.

## Checks

Run all pre-commit hooks manually:

```bash
uv run pre-commit run --all-files
```

Or run the same checks with:

```bash
just check
```

Use `just check-worktree` to run the YAML and Ansible checks across the working
tree, including untracked files. Running `just` without a recipe does the same.

When `ANSIBLE_VAULT_PASSWORD_FILE` or `.vault_password` is available, the
Ansible syntax check uses the real Vault. Otherwise, it temporarily substitutes
an empty Vault file to validate playbook structure without secrets.

The pre-commit hook runs the Docker Bootstrap integration test whenever Ansible
configuration or Bootstrap test files change.

## Bootstrap Tests

Run the Docker integration test:

```bash
just test-bootstrap-lightweight
```

It provisions a disposable Ubuntu 24.04 SSH container, runs `bootstrap.yaml`
twice, and verifies the new user can connect with its key and use non-interactive
sudo. Package updates and reboot are intentionally disabled because a container
reboot cannot validate the host reboot path.

Run the full local VM test on macOS:

```bash
brew install lima
just test-bootstrap-heavy
```

The VM test creates a disposable Ubuntu 24.04 VM, runs package updates and a
real reboot, verifies SSH access and passwordless sudo for the Bootstrap user,
runs the playbook again for idempotence, then deletes the VM.

## Setup Test

Run the lightweight Docker validation:

```bash
just test-setup-lightweight
```

It renders the SSH, iptables, Docker, and Traefik templates with fixture values,
then validates their syntax in Docker. This runs in pre-commit and CI.

Run the full local Setup test on macOS:

```bash
just test-setup-heavy
```

It creates a disposable Ubuntu 24.04 VM with a pre-created Bootstrap user,
tests the SSH port transition, firewall rules, system tools, Docker, Traefik,
and CrowdSec, then runs `setup.yaml` again to verify idempotence.

## Yandex Cloud Test VM

Configure the Yandex Cloud CLI (`yc`) with the target cloud and folder, then
provide a subnet and SSH public key. The created Ubuntu 24.04 VM has 2 vCPUs,
2 GB memory, a 20 GB SSD boot disk, and a public IPv4 address.

```bash
YC_TEST_VM_SUBNET=default-ru-central1-a \
YC_TEST_VM_SSH_KEY="$HOME/.ssh/id_ed25519.pub" \
just test-yc-vm-create
```

The create recipe records the VM ID in `.test-yc-vm-id`. Deletion uses only
that recorded ID:

```bash
just test-yc-vm-delete
```
