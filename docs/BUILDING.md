# Building

## Local Build

```sh
scripts/build.sh
```

Outputs:

| Artifact | Purpose |
| --- | --- |
| `dist/Terrager.app` | App bundle. |
| `dist/Terrager.dmg` | Compressed disk image. |

The build script:

1. Compiles `Sources/Terrager/Terrager.swift`.
2. Creates a macOS `.app` bundle.
3. Generates `AppIcon.icns` from `Resources/terrager.png`.
4. Applies ad-hoc codesigning.
5. Creates a compressed DMG.

## Validate

```sh
scripts/check.sh
```

The check script rebuilds, verifies the code signature, and verifies the DMG metadata.

## GitHub Release

Release by tag:

```sh
git tag v0.1.1
git push origin v0.1.1
```

Or trigger manually from GitHub Actions.

The workflow builds the DMG and attaches it to a GitHub release when the run is tag-based.

## Signing

The public build is ad-hoc signed. Users may need to right-click and choose **Open** on first launch.

For fully trusted macOS distribution, configure:

- Apple Developer ID Application certificate
- hardened runtime
- notarization credentials
- stapling after notarization

> [!NOTE]
> Terrager intentionally avoids bundling Terraria binaries, worlds, logs, tunnel config, or machine-specific values into release artifacts.
