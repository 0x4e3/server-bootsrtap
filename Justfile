default: check-worktree

check:
    uv run pre-commit run --all-files

check-worktree:
    uv run yamllint .
    uv run bash scripts/check-ansible-syntax
