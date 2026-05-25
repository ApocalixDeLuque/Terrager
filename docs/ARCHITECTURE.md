# Architecture

Terrager is a native macOS SwiftUI app built from a single Swift source file.

## App Layers

- `ServerProfile`: persistent profile model for one Terraria world/server.
- `RuntimeStatus`: passive runtime status collected from `screen`, `lsof`, process lists, logs, and generated join-info scripts.
- `ServerViewModel`: app state, actions, persistence, and background refresh.
- SwiftUI views: sidebar, overview, backups, logs, controls, and profile editor.

## Runtime Directory

Runtime files live outside the repository:

```text
~/Library/Application Support/Terrager/
```

This keeps the open-source repository free of worlds, private configs, logs, and local machine state.

## Generated Files

Terrager creates:

- `config/server-profiles.json`
- `config/rollback-settings.env`
- `config/public-endpoint.env` when users choose to add one manually
- `serverconfigs/<profile>.serverconfig.txt`
- `logs/<profile>-server.log`
- `scripts/*.sh`
- `worlds/*.wld`
- `worlds/backups/<profile>/*.wld`

Generated scripts are intentionally generic and profile-driven.

## Server Process Model

Terrager starts Terraria servers in detached `screen` sessions named from the profile id:

```text
terraria-<profile-id>
```

This allows the app to send safe console commands such as `save` and `exit` without keeping a terminal window open.

## Public Networking

Terrager does not bundle a tunnel provider. It reads optional public endpoint values from:

```text
~/Library/Application Support/Terrager/config/public-endpoint.env
```

This avoids shipping provider credentials, public IPs, or user-specific network details.
