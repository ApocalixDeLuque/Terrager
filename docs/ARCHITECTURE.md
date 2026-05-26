# Architecture

Terrager is a native macOS SwiftUI app built around a small set of local runtime concepts.

## Layers

| Layer | Responsibility |
| --- | --- |
| `ServerProfile` | Persistent profile model for one Terraria world/server. |
| `RuntimeStatus` | Passive status from `screen`, `lsof`, process lists, logs, and generated join-info scripts. |
| `ServerViewModel` | App state, persistence, validation, refresh, and server actions. |
| SwiftUI views | Sidebar, overview, backups, logs, controls, and profile editor. |

## Runtime Directory

Terrager writes runtime data outside the repository:

```text
~/Library/Application Support/Terrager/
```

This keeps the open-source project free of worlds, generated configs, logs, public endpoints, and local machine state.

## Generated Files

| Path | Purpose |
| --- | --- |
| `config/server-profiles.json` | Saved profiles. |
| `config/rollback-settings.env` | Scheduled backup settings. |
| `config/public-endpoint.env` | Optional user-created public endpoint display values. |
| `serverconfigs/<profile>.serverconfig.txt` | Generated Terraria server config. |
| `logs/<profile>-server.log` | Server output log. |
| `scripts/*.sh` | Generated helper scripts. |
| `worlds/*.wld` | World files. |
| `worlds/backups/<profile>/*.wld` | Backup snapshots. |

## Process Model

Terrager starts Terraria servers in detached `screen` sessions:

```text
terraria-<profile-id>
```

The app uses that session name to send safe console commands such as `save` and `exit` without keeping a terminal window open.

## Public Networking

Terrager does not bundle a tunnel provider. It only reads optional display values from:

```text
~/Library/Application Support/Terrager/config/public-endpoint.env
```

That avoids shipping credentials, public IP addresses, public hostnames, router settings, or user-specific network details.
