# Configuration

## Profiles

Profiles are stored in:

```text
~/Library/Application Support/Terrager/config/server-profiles.json
```

Each profile controls:

- Server display name.
- World name and world file path.
- Seed, size, difficulty, and world evil for new worlds.
- Port and max players.
- TerrariaServer executable path.
- Generated config and log paths.

## TerrariaServer Binary

Terrager checks common Terraria install locations first. If it cannot find a binary, choose one in the profile editor.

The binary is not bundled because Terraria is proprietary software.

## Backups

Manual and scheduled backups are written to:

```text
~/Library/Application Support/Terrager/worlds/backups/<profile-id>/
```

Scheduled backups only copy worlds for profiles whose `screen` session is running.

## Public Endpoint

Terrager can display a public join endpoint if the user configures one.

Create:

```text
~/Library/Application Support/Terrager/config/public-endpoint.env
```

Example:

```bash
PUBLIC_HOST=example.example.net
PUBLIC_PORT=12345
PUBLIC_LOCAL_PORT=7777
```

`PUBLIC_LOCAL_PORT` is optional. If it is present, Terrager shows the endpoint only for profiles using that local port.

## Launch Agents

The scheduled backup helper installs a user LaunchAgent:

```text
~/Library/LaunchAgents/com.terrager.rollback-scheduler.plist
```

The helper runs once per minute and creates a backup only when the configured interval has elapsed and at least one profile is running.
