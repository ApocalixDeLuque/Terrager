# Building and Releasing

## Local Build

```bash
scripts/build.sh
```

This creates:

```text
dist/Terrager.app
dist/Terrager.dmg
```

The build script:

1. Compiles `Sources/Terrager/Terrager.swift`.
2. Creates a macOS `.app` bundle.
3. Generates `AppIcon.icns` from `Resources/terrager.png`.
4. Applies ad-hoc codesigning.
5. Creates a compressed DMG.

## Validate

```bash
scripts/check.sh
```

## GitHub Release

Push a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions builds the DMG and publishes it to the release.

## Signing and Notarization

The public build is ad-hoc signed. Users may need to right-click and choose **Open** on first launch.

For a fully trusted macOS distribution, configure an Apple Developer ID certificate and notarization in the release workflow.
