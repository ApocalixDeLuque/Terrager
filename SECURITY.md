# Security

Terrager is a local macOS utility. It should never require publishing private server data or machine-specific network details.

## Sensitive Data

Do not commit:

- Terraria world files
- player files
- server logs
- generated server configs
- tunnel credentials
- local IP addresses
- public endpoints
- local LaunchAgents
- machine-specific paths

## Runtime Boundary

Terrager keeps runtime data under:

```text
~/Library/Application Support/Terrager/
```

Repository files should remain generic and portable.

## Public Networking

Terrager can display public join information from a user-created `public-endpoint.env` file. It does not bundle:

- tunnel providers
- tunnel credentials
- public hostnames
- public IP addresses
- router or firewall configuration

## Reporting

Please use GitHub Security Advisories for private reports:

[Open a security advisory](https://github.com/ApocalixDeLuque/Terrager/security/advisories/new)

If an issue must be public, remove secrets, IP addresses, endpoints, world files, and private logs before posting.
