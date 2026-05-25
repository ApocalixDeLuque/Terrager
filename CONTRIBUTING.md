# Contributing

Thanks for improving Terrager.

## Local Setup

1. Install Terraria on macOS, or have a compatible `TerrariaServer` binary available.
2. Clone this repository.
3. Build the app:

```bash
scripts/build.sh
```

4. Run the generated app from `dist/Terrager.app`.

## Development Rules

- Do not commit worlds, logs, launch agents, private configs, tunnel credentials, IP addresses, or machine-specific paths.
- Keep runtime data under `~/Library/Application Support/Terrager`.
- Keep UI actions state-aware: do not offer destructive or impossible actions for the selected server state.
- Prefer passive status reads over active probes that connect to a running Terraria server.
- Keep the app useful without a public tunnel provider.
- Keep generated scripts generic and profile-driven.

## Pull Requests

Before opening a pull request:

```bash
scripts/check.sh
```

Include:

- What changed.
- Why it changed.
- How it was validated.
- Any known limitations.

## Releases

Releases are built by GitHub Actions when a `v*` tag is pushed. See [docs/BUILDING.md](docs/BUILDING.md).
