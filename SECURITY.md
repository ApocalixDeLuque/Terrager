# Security Policy

## Supported Versions

Security updates are handled on the latest released version.

## Reporting a Vulnerability

Open a private security advisory on GitHub if available. If not, open an issue with minimal reproduction details and avoid posting secrets, credentials, private IPs, world files, or logs that contain private player information.

## Sensitive Data

Terrager should never require committing:

- Terraria world files.
- Player files.
- Tunnel credentials.
- Launch agents from a local machine.
- Local IP addresses or public endpoints.
- Logs from private servers.

If sensitive data is accidentally committed, rotate any exposed credentials and remove the data from git history before publishing.
