# Application Delivery Specification

## Purpose

Define delivery constraints for Vaultwarden, 3x-ui, and Telemt applications.

## Requirements

### Requirement: Shared application placement

The system SHALL deploy an application only when its host belongs to both its
application-specific inventory group and `traefik_hosts`.

#### Scenario: An application host lacks proxy membership

- **WHEN** an application role targets a host outside `traefik_hosts`
- **THEN** the role fails before application deployment

### Requirement: Vaultwarden delivery

The system SHALL require a Vaultwarden domain and secret admin token, persist
Vaultwarden data below `/opt/vaultwarden/data`, and expose the service only
through Traefik HTTPS.

#### Scenario: Vaultwarden is configured with required inputs

- **WHEN** the host belongs to `vaultwarden_hosts` and required values are set
- **THEN** the Vaultwarden compose project runs with persistent data and no
  directly published application host port

### Requirement: 3x-ui delivery

The system SHALL require a panel domain and nonempty, unique inbound hostnames
and ports. It SHALL route the panel through HTTPS and route configured inbounds
through Traefik TLS passthrough.

#### Scenario: A 3x-ui inbound is configured

- **WHEN** its hostname and internal port are unique and valid
- **THEN** Traefik creates a TLS-passthrough router for that hostname without
  publishing the internal inbound port on the host

### Requirement: Telemt delivery

The system SHALL require a nonempty secret Telemt configuration and SNI hostname,
persist the configuration with restricted permissions, and route it through
Traefik TLS passthrough.

#### Scenario: Telemt configuration is deployed

- **WHEN** the host belongs to `telemt_hosts` and required inputs are valid
- **THEN** the configuration is stored below `/opt/telemt/config` with mode 0600
  and the application is not directly host-published

### Requirement: Application secret isolation

The system SHALL source application tokens and secret configuration from vault
values and SHALL not render those values into tracked repository files.

#### Scenario: An operator reviews the repository

- **WHEN** the application configuration is stored correctly
- **THEN** secret tokens and Telemt configuration are absent from tracked group
  and host variable files
