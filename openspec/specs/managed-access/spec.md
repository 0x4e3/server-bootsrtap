# Managed Access Specification

## Purpose

Define the transition from an initial server identity to the managed,
key-authenticated administrative identity.

## Requirements

### Requirement: Bootstrap identity creation

The system SHALL create the configured bootstrap login user from an initial
inventory identity that is root or can become root.

#### Scenario: A fresh server has a privileged initial identity

- **WHEN** `bootstrap.yaml` runs against a host in the `bootstrap` group
- **THEN** the configured bootstrap login user exists with its configured home,
  shell, groups, and SSH public keys

### Requirement: Key-based managed access

The system SHALL install at least one configured public key for every present
managed user before key-only SSH policy is applied.

#### Scenario: A user lacks an SSH key

- **WHEN** bootstrap input defines a present user without public keys
- **THEN** provisioning fails before SSH access can be hardened

### Requirement: Controlled administrative privilege

The system SHALL manage passwordless sudo only for users explicitly configured
for it and SHALL validate generated sudoers files before applying them.

#### Scenario: Bootstrap user requests passwordless sudo

- **WHEN** a managed user has `sudo_nopasswd: true`
- **THEN** a valid `/etc/sudoers.d/90-<user>` file grants that user passwordless
  sudo access

### Requirement: One-time password initialization

The system SHALL set a managed user's initial password once and SHALL preserve
subsequent user-changed passwords during repeat provisioning.

#### Scenario: Bootstrap is rerun after password initialization

- **WHEN** the user's initialization marker already exists
- **THEN** the password initialization task makes no password change

### Requirement: Secret-backed bootstrap inputs

The system SHALL obtain bootstrap public keys, password, and password salt from
secret-backed values and SHALL keep the vault file out of version control.

#### Scenario: Required bootstrap secret is missing

- **WHEN** a required password, salt, or key value is empty
- **THEN** bootstrap fails validation without creating a partially configured
  managed account
