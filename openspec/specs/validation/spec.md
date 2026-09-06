# Validation Specification

## Purpose

Define the checks that establish confidence in provisioning changes.

## Requirements

### Requirement: Static configuration validation

The system SHALL lint YAML and validate all playbook syntax before a change is
accepted.

#### Scenario: An Ansible-related file changes

- **WHEN** repository checks run
- **THEN** YAML linting and Ansible syntax validation pass for the changed
  configuration

### Requirement: Bootstrap integration validation

The system SHALL run a lightweight Bootstrap integration test that provisions an
ephemeral SSH target twice and verifies managed-user SSH and passwordless sudo.

#### Scenario: Bootstrap behavior changes

- **WHEN** the lightweight Bootstrap test runs
- **THEN** its second playbook run is idempotent and the created user can execute
  `sudo -n true`

### Requirement: Setup rendering validation

The system SHALL render and validate SSH, iptables, Docker, and Traefik setup
artifacts in a lightweight test.

#### Scenario: Setup templates change

- **WHEN** the lightweight setup test runs
- **THEN** rendered SSH and firewall configuration validate and Docker Compose
  configuration parses successfully

### Requirement: Ubuntu lightweight test matrix

The CI system SHALL run lightweight Bootstrap and Setup validation on Ubuntu
22.04, 24.04, and 26.04 runners and fixture images.

#### Scenario: A change is pushed or proposed

- **WHEN** the Checks workflow runs
- **THEN** each lightweight suite executes once for every configured Ubuntu
  matrix target

### Requirement: Full migration validation

The system SHALL provide an optional heavyweight local test that verifies real
VM provisioning, SSH port migration, services, firewall state, and idempotence.

#### Scenario: An operator runs the setup-heavy test on macOS with Lima

- **WHEN** the test completes successfully
- **THEN** SSH migration, required services, firewall policy, Traefik runtime,
  and repeat-run idempotence are verified
