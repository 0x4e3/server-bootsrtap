default: check-worktree

check:
    uv run pre-commit run --all-files

check-worktree:
    uv run yamllint .
    uv run bash scripts/check-ansible-syntax

test-bootstrap:
    bash tests/bootstrap/run.sh

test-bootstrap-vm:
    bash tests/bootstrap/lima.sh

test-setup-vm:
    bash tests/setup/lima.sh
