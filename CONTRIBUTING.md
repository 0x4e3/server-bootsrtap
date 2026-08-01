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
just test-bootstrap
```

It provisions a disposable Ubuntu 24.04 SSH container, runs `bootstrap.yaml`
twice, and verifies the new user can connect with its key and use non-interactive
sudo. Package updates and reboot are intentionally disabled because a container
reboot cannot validate the host reboot path.

Run the full local VM test on macOS:

```bash
brew install lima
just test-bootstrap-vm
```

The VM test creates a disposable Ubuntu 24.04 VM, runs package updates and a
real reboot, verifies SSH access and passwordless sudo for the Bootstrap user,
runs the playbook again for idempotence, then deletes the VM.

## Setup Test

Run the full local Setup test on macOS:

```bash
just test-setup-vm
```

It creates a disposable Ubuntu 24.04 VM with a pre-created Bootstrap user,
tests the SSH port transition, firewall rules, system tools, Docker, Traefik,
and CrowdSec, then runs `setup.yaml` again to verify idempotence.
