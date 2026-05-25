# Terrager

Terrager is a macOS manager for hosting Terraria dedicated server worlds from a Mac.

It provides a native SwiftUI interface for creating server profiles, starting and stopping worlds safely, saving, backing up, restoring from backups, importing `.wld` files, viewing logs, and showing join information for local network play.

![Terrager logo](Resources/terrager.png)

## Features

- Create reusable Terraria server profiles.
- Generate Terraria server config files from the app.
- Start Terraria dedicated servers in detached `screen` sessions.
- Save, backup, and safe-stop worlds from the UI.
- Import existing `.wld` worlds.
- List and manage backups, including disk usage.
- Schedule automatic backup snapshots only while matching servers are running.
- Show same-Wi-Fi join host and port.
- Optionally show a user-configured public endpoint.
- Store all runtime data under `~/Library/Application Support/Terrager`.

## Requirements

- macOS 13 or newer.
- Terraria installed from Steam, or a compatible `TerrariaServer` binary selected in the app.
- The macOS `screen` command, included with macOS.

Terrager does not bundle Terraria, Terraria server binaries, worlds, private configs, public tunnel credentials, or IP addresses.

## Install

Download `Terrager.dmg` from the GitHub Releases page, open it, and run `Terrager.app`.

The current build is ad-hoc signed. If macOS warns that the app is from an unidentified developer, right-click the app, choose **Open**, and confirm. A future notarized release can remove that extra step.

## Build Locally

```bash
scripts/build.sh
```

Outputs:

- `dist/Terrager.app`
- `dist/Terrager.dmg`

Run validation:

```bash
scripts/check.sh
```

## Runtime Data

Terrager creates and manages:

```text
~/Library/Application Support/Terrager/
  config/
  logs/
  scripts/
  serverconfigs/
  worlds/
  worlds/backups/
```

These files are intentionally not part of the repository.

## Public Access

Terrager can display public join information, but it does not bundle or configure a public tunnel provider. Configure your own tunnel or port-forwarding solution and then create:

```text
~/Library/Application Support/Terrager/config/public-endpoint.env
```

Example:

```bash
PUBLIC_HOST=example.example.net
PUBLIC_PORT=12345
PUBLIC_LOCAL_PORT=7777
```

If `PUBLIC_LOCAL_PORT` is omitted, the endpoint is shown for any selected profile.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Building and releasing](docs/BUILDING.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

MIT. See [LICENSE](LICENSE).
