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

test-yc-vm-create:
    #!/usr/bin/env bash
    set -euo pipefail
    state_file=".test-yc-vm-id"
    instance_name="${YC_TEST_VM_NAME:-server-bootstrap-test}"
    : "${YC_TEST_VM_SUBNET:?Set YC_TEST_VM_SUBNET to the Yandex Cloud subnet name.}"
    : "${YC_TEST_VM_SSH_KEY:?Set YC_TEST_VM_SSH_KEY to an SSH public key file.}"
    if [[ -e "$state_file" ]]; then
        echo "Refusing to create a VM while $state_file exists. Delete the recorded VM first."
        exit 1
    fi
    yc compute instance create \
        --name "$instance_name" \
        --zone "${YC_TEST_VM_ZONE:-ru-central1-a}" \
        --cores 2 \
        --memory 2 \
        --core-fraction 20 \
        --create-boot-disk "size=20,type=network-ssd,image-family=ubuntu-2404-lts,image-folder-id=standard-images,auto-delete=true" \
        --network-interface "subnet-name=$YC_TEST_VM_SUBNET,nat-ip-version=ipv4" \
        --ssh-key "$YC_TEST_VM_SSH_KEY"
    instance_id="$(yc compute instance get --name "$instance_name" --format json | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
    printf '%s\n' "$instance_id" > "$state_file"
    echo "Created $instance_name ($instance_id)."

test-yc-vm-delete:
    #!/usr/bin/env bash
    set -euo pipefail
    state_file=".test-yc-vm-id"
    if [[ ! -s "$state_file" ]]; then
        echo "No recorded test VM in $state_file."
        exit 1
    fi
    instance_id="$(<"$state_file")"
    yc compute instance delete --id "$instance_id"
    rm "$state_file"
