default: check-worktree

check:
    uv run pre-commit run --all-files

check-worktree:
    uv run yamllint .
    uv run bash scripts/check-ansible-syntax

test-bootstrap-lightweight:
    bash tests/bootstrap/lightweight.sh

test-bootstrap-heavy:
    bash tests/bootstrap/heavy.sh

test-setup-lightweight:
    bash tests/setup/lightweight.sh

test-setup-heavy:
    bash tests/setup/heavy.sh

test-lightweight: test-bootstrap-lightweight test-setup-lightweight

test-heavy: test-bootstrap-heavy test-setup-heavy

test: test-lightweight test-heavy
