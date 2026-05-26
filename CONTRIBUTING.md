# Contributing

Thanks for improving Terrager. The project should stay focused: a native macOS manager for Terraria dedicated server worlds.

## Development Rules

| Rule | Why |
| --- | --- |
| Keep runtime files out of git | Worlds, logs, generated configs, and local launch agents are user data. |
| Avoid hardcoded network details | Public endpoints and tunnel providers must be user-configured. |
| Keep actions state-aware | Do not offer destructive or impossible actions for the selected server state. |
| Prefer passive status reads | Avoid unnecessary active probes against running Terraria servers. |
| Keep generated scripts generic | Scripts should be profile-driven and portable across Macs. |

## Local Setup

1. Install Terraria on macOS, or have a compatible `TerrariaServer` binary available.
2. Clone the repository.
3. Build the app.

```sh
scripts/build.sh
open dist/Terrager.app
```

## Verification Checklist

- [ ] `scripts/check.sh` passes.
- [ ] `dist/Terrager.app` opens.
- [ ] No worlds, logs, tunnel credentials, IP addresses, hostnames, or machine-specific paths are committed.
- [ ] Profile changes still write runtime data under `~/Library/Application Support/Terrager`.
- [ ] Server actions remain disabled when they would be unsafe for the current state.
- [ ] Public endpoint behavior still works without bundling a tunnel provider.

## Pull Requests

Use concise conventional commits:

```text
feat: add backup inventory controls
fix: preserve profile runtime paths
docs: refresh build guide
```

Include:

- what changed
- why it changed
- how it was validated
- known limitations

## Releases

Releases are built by GitHub Actions. See [docs/BUILDING.md](docs/BUILDING.md).
