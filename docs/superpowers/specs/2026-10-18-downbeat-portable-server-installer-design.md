# Downbeat Portable Server Installer and Code Pairing Design

> **Superseded:** Downbeat now processes downloads locally as defined in `2026-10-18-downbeat-local-processing-design.md`. This document is retained as historical design context only.

## Purpose

Downbeat will run its processing backend on the owner's always-on Windows 10 or Windows 11 x64 computer. A reusable installer must make initial setup, repair, updates, backup, and migration understandable without command-line work. Android and Windows clients pair by entering one short generated code; users do not enter a URL or scan a QR code.

The server remains personal and single-owner. Cloudflare provides secure public reachability and a minimal rendezvous service, but it never receives browser cookies, queue contents, or media through the pairing flow. Media processing and temporary output storage remain on the Windows server.

## Success Criteria

- A clean Windows computer can become the Downbeat server using one signed installer.
- The server and its secure tunnel start automatically after reboot without an interactive login.
- A client can pair using only a short, single-use code displayed by the server control panel.
- Pairing does not expose a reusable server administrator secret.
- A password-protected backup can move the server to another Windows computer while retaining its identity, configuration, queue history, and device registrations.
- Migration does not deactivate the old server until the restored server passes health and connectivity checks.
- Repair and updates preserve server data and can roll back after an installation failure.

## Deployment Architecture

### Windows server

The Windows installation contains:

- **Downbeat Server Service:** owns the API, job coordinator, queue database, delivery endpoints, and processor lifecycle.
- **Processor runtime:** an application-private Python runtime, `yt-dlp`, FFmpeg, and per-job working directories. System-wide Python and FFmpeg installations are not required.
- **Downbeat Server Control Panel:** a small desktop application for status, pairing, devices, backups, updates, restarts, and storage settings. Closing it does not stop the service.
- **Cloudflare Tunnel service:** establishes outbound-only connectivity to the public Downbeat hostname. No router port forwarding is required.
- **Updater/repair helper:** replaces versioned program files while preserving mutable server data.

Program files and mutable data use separate directories. The uninstaller offers an explicit choice to retain or remove server data; retaining data is the default.

### Public reachability

A named Cloudflare Tunnel maps a stable HTTPS hostname to the local Downbeat Server Service. The installer configures and verifies the tunnel, then stores its non-exportable operational credentials with Windows service-level access controls.

Clients communicate directly with the stable hostname after pairing. The pairing service is not in the path for normal job creation, progress, file delivery, or browser-cookie handoff.

### Pairing rendezvous service

A minimal Cloudflare Worker acts as a short-lived rendezvous service. It stores only:

- A cryptographically random pairing-code digest.
- The server's public HTTPS endpoint and public-key fingerprint.
- Creation and expiry times.
- A consumed flag or atomic consumption record.

The record expires after ten minutes and can be consumed once. The service never stores media URLs, cookies, queue data, files, device credentials, or the plaintext pairing code.

## Installer Experience

`Downbeat Server Setup.exe` presents three primary choices:

1. **Set up a new Downbeat Server**
2. **Restore an existing Downbeat Server**
3. **Repair or update this installation**

### New server

The installer:

1. Checks supported Windows version, architecture, administrator access, disk space, and network connectivity.
2. Installs versioned application files and registers the Downbeat and tunnel Windows services.
3. Generates the server identity and encryption keys locally.
4. Opens the Cloudflare authorization flow when account authorization is needed.
5. Creates or attaches the named tunnel and stable hostname.
6. Starts both services and verifies local and public health endpoints.
7. Opens the control panel with server status and a newly generated pairing code.

Python, FFmpeg, `yt-dlp`, service registration, firewall-safe tunnel connectivity, and directory permissions are implementation details hidden from the normal installer flow. An expandable diagnostics view remains available for troubleshooting.

### Restore existing server

The installer requests a `.downbeat-backup` file and its password, validates the archive before changing the machine, installs the matching or a compatible newer server version, restores data into a staging area, and tests the restored identity and tunnel. It only promotes the staged restoration after all checks pass.

### Repair or update

Repair verifies checksums and replaces damaged program files without regenerating identity or erasing mutable data. Updates use the same staged installation model. If the new service fails its health checks, the installer restores the previous executable version and database schema.

## Server Control Panel

The control panel shows:

- Overall state: Online, Starting, Offline, Updating, or Attention required.
- Current job activity and free storage.
- Public connectivity and the last successful connectivity check.
- Paired devices with user-editable names, last-seen times, and a **Remove** action.
- **Generate pairing code**.
- **Create backup** and **Restore backup**.
- **Check for updates**.
- **Restart server**.
- Storage location and retention settings.
- A concise diagnostics page with copyable, secret-redacted information.

Pairing codes are shown as eight unambiguous uppercase letters and digits, grouped for readability, for example `K7M4-P9Q2`. Characters that are easily confused, such as `0/O` and `1/I`, are excluded.

## Code-Only Pairing Protocol

### Server preparation

1. The control panel asks the server service to generate a code.
2. The server uses a cryptographically secure random generator; codes are never sequential.
3. The server creates an ephemeral pairing key and registers the code digest, endpoint, public-key fingerprint, and expiry with the rendezvous service.
4. The plaintext code is displayed only in the control panel.

Generating another code invalidates the previous unused code unless a future setting explicitly permits multiple concurrent codes.

### Client pairing

1. The user selects **Pair with Server** and enters the code.
2. The client submits the normalized code to the rendezvous service.
3. The rendezvous service atomically consumes the record and returns the endpoint, fingerprint, and server pairing material.
4. The client connects to the server over HTTPS and verifies that the presented server identity matches the returned fingerprint.
5. The client and server perform an ephemeral-key exchange and mutually prove possession of the pairing material.
6. The server issues a unique, revocable device credential scoped to client operations.
7. The client stores its credential and endpoint in platform-secure storage and prompts for a friendly device name.
8. Both sides erase temporary pairing secrets.

The code is rejected after ten minutes, after first use, after explicit cancellation, or after a newer code replaces it. Failed attempts are rate-limited by code and network source. Responses do not reveal whether a guessed code was previously valid, expired, or already consumed.

## Device Credentials

Each paired installation receives its own credential. Removing one device invalidates only that device. The server can rotate credentials after suspicious activity or protocol upgrades. The control panel never displays full credentials and all logs redact them.

Restored servers retain paired-device records and the server identity, allowing existing clients to continue connecting through the stable hostname. If a restored server cannot reclaim the prior hostname, it publishes the replacement endpoint against the retained server identity; clients may resolve the new endpoint through a signed recovery record without accepting a new server identity.

## Backup Format and Migration

### Included data

The encrypted backup contains:

- Server identity and public/private keys.
- Tunnel identity and hostname configuration needed for restoration.
- Server settings and storage policy.
- Queue and completed-history metadata, including source URLs required for **Download again**.
- Paired-device records.
- Database schema and application compatibility metadata.

Browser cookies, client-side login storage, active plaintext pairing codes, logs, partial downloads, and completed media files are excluded. Temporary media is never required to restore the server.

### Encryption

The backup is a versioned authenticated-encryption container. A key is derived from the user's backup password using a memory-hard password derivation function with a unique salt. The archive is integrity-checked before extraction. Passwords are never stored in the file or uploaded. A forgotten backup password cannot be recovered.

### Migration behavior

1. The old server creates the encrypted backup while continuing to operate.
2. The replacement computer restores into staging and performs local checks.
3. The replacement claims the stable tunnel identity and performs an external connectivity test.
4. Only after the test succeeds does the service mark the replacement as active.
5. If both machines are online, the most recently successful authorized restoration becomes active. Both control panels show a duplicate-server warning.
6. The old machine remains recoverable and is never automatically wiped or uninstalled.

If no backup is available, the installer creates a new server identity. Clients must then pair again, and old server history cannot be recovered.

## Data Locations and Portability

Installation paths are fixed and documented internally rather than inferred from the installing user's profile. Service data is accessible to the service account and administrators only. Large working/output directories may be moved from the control panel using a staged copy, verification, and atomic switch.

The installer embeds a compatible dependency set so it is reproducible later. Normal updates may refresh `yt-dlp`, FFmpeg, security libraries, and the application, but a saved installer can establish a working baseline without relying on whatever happens to be installed on the destination PC.

## Reliability and Failure Handling

- The services use automatic restart with bounded backoff and start at boot.
- Local downloads continue when the control panel is closed.
- Internet loss pauses external operations safely and resumes synchronization after connectivity returns.
- Tunnel failure does not corrupt active jobs; the control panel distinguishes processor health from public connectivity.
- Insufficient disk space prevents a new job before processing starts where size is known and fails safely otherwise.
- Backup and restore use staging files and atomic replacement, leaving the last valid state untouched on failure.
- Database migrations are versioned and backed up before update.
- Secret-bearing files never appear in ordinary diagnostics or logs.
- Uninstalling program files does not remove data unless the user explicitly selects that option.

## Security Boundaries

- Only HTTPS public endpoints are advertised.
- The tunnel accepts requests only for the Downbeat service; local administrative endpoints are not published.
- Control-panel administration is restricted to an interactive Windows administrator on the server machine.
- Pairing codes have sufficient entropy for their short validity period and are protected by rate limits and one-time atomic consumption.
- Client credentials are device-specific, revocable, and stored with Android Keystore or Windows Credential Manager/DPAPI-backed storage.
- Server and tunnel secrets are protected using Windows DPAPI and restricted filesystem ACLs.
- Restores require both the backup file and its password.
- The rendezvous service stores no user content and aggressively expires pairing records.

## Testing and Acceptance

Automated tests cover:

- Pairing-code generation, normalization, entropy rules, expiry, replacement, and single consumption.
- Atomic use under simultaneous pairing attempts.
- Incorrect-code throttling and non-enumerating error responses.
- Endpoint discovery and server-fingerprint verification.
- Device credential issuance, persistence, rotation, and revocation.
- Backup encryption, wrong-password rejection, tamper detection, version compatibility, and staging cleanup.
- Database and configuration restoration without media files.
- Installer new, repair, update, rollback, retain-data uninstall, and reinstall paths.
- Windows service startup after reboot and recovery after simulated crashes.
- Tunnel interruption and reconnection.
- Duplicate restored-server detection and active-instance selection.

Release acceptance requires tests on two Windows 10/11 x64 machines or equivalent clean virtual machines plus a real Android device. A user must be able to install a new server, pair using only the displayed code, submit and receive a download, create an encrypted backup, restore it on the replacement machine, and use the already-paired client without changing its server address or pairing again.

## Scope Boundaries

The first installer release does not include unattended enterprise deployment, multiple server owners, cloud media storage, automatic backup upload, router configuration, or recovery of a forgotten backup password. The rendezvous service exists only for pairing and endpoint recovery; it is not a general user account service.

