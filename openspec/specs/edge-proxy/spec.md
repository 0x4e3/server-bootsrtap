# Edge Proxy Specification

## Purpose

Define the Docker and Traefik edge service hosted on `traefik_hosts`.

## Requirements

### Requirement: Traefik host membership

The system SHALL install Docker and Traefik only on hosts in the
`traefik_hosts` inventory group.

#### Scenario: A non-proxy host runs setup

- **WHEN** a host is not in `traefik_hosts`
- **THEN** setup does not install Docker or Traefik on that host

### Requirement: Managed Docker runtime

The system SHALL install Docker Engine, Docker CLI, containerd, Buildx, and
Compose v2 from Docker's Ubuntu repository and SHALL configure bounded local
container logs.

#### Scenario: A proxy host completes setup

- **WHEN** Docker provisioning succeeds
- **THEN** Docker, Buildx, and Compose are available and Docker uses the managed
  daemon configuration

### Requirement: HTTPS edge entrypoints

The system SHALL publish Traefik only on TCP 80 and 443, redirect HTTP traffic
to HTTPS, and use ACME HTTP-01 with the configured contact email.

#### Scenario: A publicly reachable proxy host has valid DNS

- **WHEN** TCP 80 and 443 reach the host and `traefik_acme_email` is configured
- **THEN** Traefik can obtain and persist ACME certificates for configured
  routers

### Requirement: Explicit application exposure

The system SHALL use Docker discovery with default exposure disabled and SHALL
expose an application only when that application's Traefik labels opt in.

#### Scenario: An unlabeled container joins the Docker host

- **WHEN** the container has no explicit Traefik enable label
- **THEN** Traefik does not publish it

### Requirement: Proxy network and observability

The system SHALL create the external `traefik` Docker network and persist
Traefik access logs for downstream security acquisition.

#### Scenario: Traefik completes deployment

- **WHEN** its compose project is running
- **THEN** the `traefik` network exists and access logs are written below
  `/opt/traefik/logs`

### Requirement: Proxy-specific CrowdSec coverage

The system SHALL add Traefik log acquisition and the Traefik CrowdSec collection
on proxy hosts and SHALL apply CrowdSec bouncer decisions to `DOCKER-USER`.

#### Scenario: A proxy host completes setup

- **WHEN** CrowdSec is configured after Traefik
- **THEN** `traefik.yaml` is present as an acquisition and the bouncer includes
  `DOCKER-USER`
