# Configuration

Terrager keeps configuration in the user runtime directory, not in the repository.

## Profiles

Profiles are stored at:

```text
~/Library/Application Support/Terrager/config/server-profiles.json
```

Each profile controls:

| Field | Meaning |
| --- | --- |
| Server name | Display name in the app. |
| World name/path | Terraria `.wld` file and generated world metadata. |
| Seed/size/difficulty/evil | New-world generation settings. |
| Port/max players | Terraria server networking and capacity. |
| Executable path | User-selected `TerrariaServer` binary. |
| Config/log paths | Generated runtime files. |

## TerrariaServer Binary

Terrager checks common Terraria install locations first. If it cannot find a compatible binary, choose one in the profile editor.

> [!IMPORTANT]
> The binary is not bundled because Terraria is proprietary software.

## Backups

Manual and scheduled backups are written to:

```text
~/Library/Application Support/Terrager/worlds/backups/<profile-id>/
```

Scheduled backups only copy worlds for profiles whose `screen` session is running.

## Public Endpoint

Terrager can display public join information if the user configures it.

Create:

```text
~/Library/Application Support/Terrager/config/public-endpoint.env
```

Example:

```env
PUBLIC_HOST=play.example.net
PUBLIC_PORT=7777
PUBLIC_LOCAL_PORT=7777
```

| Variable | Required | Meaning |
| --- | --- | --- |
| `PUBLIC_HOST` | Yes | Hostname shown to players. |
| `PUBLIC_PORT` | Yes | Public port shown to players. |
| `PUBLIC_LOCAL_PORT` | No | Show endpoint only for profiles using this local port. |

Terrager does not create tunnels, configure routers, or store provider credentials.

## LaunchAgent

Scheduled backups install a user LaunchAgent:

```text
~/Library/LaunchAgents/com.terrager.rollback-scheduler.plist
```

The helper checks once per minute and creates a backup only when:

- scheduled backups are enabled
- the configured interval has elapsed
- at least one matching profile is running
