# Release process

!!! info "Still being written"
    This page is an outline. The content below is what it will cover.

## Planned contents

- The ordering constraint: main, then the binary archive, then the installer script
- Why any other order makes a correct installer refuse to install
- Tag naming: `Somnilux-<version>-for-<Somnium version verified against>`
- Prereleases, and how `releases/latest/download` skips them
- Bumping `UMU_VERSION` and `UMU_SHA256` together
- Release notes hardcode their own tag in the download URL
- Verifying the published script byte-for-byte after publishing
