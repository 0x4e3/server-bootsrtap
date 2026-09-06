# Host Baseline Specification

## Purpose

Define the repeatable security and operations baseline applied to every managed
Ubuntu host.

## Requirements

### Requirement: Supported production platform

The system SHALL document Ubuntu 24.04 as its production provisioning target.

#### Scenario: An operator prepares a production server

- **WHEN** the operator follows the deployment documentation
- **THEN** the documented server image is Ubuntu 24.04

### Requirement: Hardened SSH service

The system SHALL configure SSH to use the configured hardened port, disable root
login and password-based authentication, and allow the configured managed login
identity.

#### Scenario: Setup completes on a fresh server

- **WHEN** `setup.yaml` completes successfully
- **THEN** the managed user can authenticate with its public key on the hardened
  SSH port and root/password SSH authentication is disabled

### Requirement: Safe SSH port migration

The system SHALL preserve reachability during an SSH port migration by allowing
both the current and desired local SSH ports until the connection moves to the
desired port.

#### Scenario: Setup starts from the initial SSH port

- **WHEN** setup is invoked with `setup_ssh_port` set to the currently reachable
  port
- **THEN** it applies the local firewall safely, reconfigures SSH, resets the
  controller connection, and continues on the hardened port

### Requirement: Persistent IPv4 firewall

The system SHALL persist an IPv4 firewall that drops unsolicited inbound and
forwarded traffic, accepts loopback and established traffic, and permits only
configured TCP and UDP ports.

#### Scenario: A baseline host is configured

- **WHEN** setup applies the host baseline
- **THEN** the persisted firewall permits the hardened SSH port and rejects
  other unconfigured inbound traffic

### Requirement: IPv6 policy

The system SHALL disable IPv6 persistently and immediately on managed hosts.

#### Scenario: Setup completes

- **WHEN** the firewall role applies
- **THEN** the IPv6 disablement sysctl configuration is present and active

### Requirement: Operational tooling

The system SHALL install the standard troubleshooting tools: `mtr`,
`traceroute`, `iperf3`, `nmap`, `iftop`, `iotop`, and `btop`.

#### Scenario: A host completes setup

- **WHEN** setup finishes without error
- **THEN** each standard troubleshooting command is available on the host

### Requirement: CrowdSec protection

The system SHALL run CrowdSec, its iptables firewall bouncer, `rsyslog`, and
`cron`; it SHALL acquire SSH logs and apply decisions to the `INPUT` chain.

#### Scenario: A baseline host completes setup

- **WHEN** CrowdSec provisioning succeeds
- **THEN** the SSH collection and acquisition are installed and the CrowdSec
  services are enabled and active
