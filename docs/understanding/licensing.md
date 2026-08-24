# Licensing

Two licences, because Somnilux is two things: scripts and documentation
written for this project, and patches to Wine.

## The scripts and this documentation — MIT

`install.sh`, `build-artifacts.sh`, the workflows, and these pages are
MIT-licensed. See
[`LICENSE`](https://github.com/Vulps22/somnilux/blob/main/LICENSE).

## The Wine patches — LGPL-2.1

The patches in
[`patches/`](https://github.com/Vulps22/somnilux/tree/main/patches) are
modifications to Wine, so they carry Wine's own licence,
[LGPL-2.1](https://gitlab.winehq.org/wine/wine/-/raw/master/LICENSE). The
prebuilt binaries in the releases are built from them and carry the same
licence.

### How the source obligation is met

LGPL requires that the source corresponding to a distributed binary is
available. Somnilux satisfies this without re-hosting all of Wine:

- The **unmodified base** is already public, at
  [gitlab.winehq.org/wine/wine](https://gitlab.winehq.org/wine/wine) and its
  [GitHub mirror](https://github.com/wine-mirror/wine).
- The **exact commit** each patch set was built against is recorded in
  [`patches/BASE_COMMIT.txt`](https://github.com/Vulps22/somnilux/blob/main/patches/BASE_COMMIT.txt),
  along with the commands to reconstruct either tree.
- The **modifications** are `patches/`, as `git format-patch` output.

Base plus diff is the complete source. See
[Building from source](../contributing/building.md) to rebuild the binaries
and compare them against what's published.

## ffmpeg

Somnilux ships ffmpeg libraries because GE-Proton's build lacks a software AV1
decoder. The **source is unmodified upstream ffmpeg 8.1** — only the configure
line differs, by one flag, and that's recorded in the build script. ffmpeg's
own licence terms apply unchanged.

## Somnium Space itself

**Somnilux does not distribute, modify, or redistribute any of Somnium's
binaries.** You supply your own copy of Somnium's official installer, and it
runs unmodified.

No part of this project patches Somnium's code, bypasses its verification or
encryption, or reproduces anything from it. Diagnostic work read Wine's
behaviour to find Wine's bugs, and stopped there.

## Not affiliated

Not affiliated with, endorsed by, or connected to **Somnium Space Ltd**, the
**Wine project**, or **WineHQ**. Their names appear here to describe what this
works with.

## No warranty

This software is provided **"as is"**, without warranty of any kind. Use it at
your own risk — no responsibility is accepted for any damage, data loss, or
other consequences of running it.

Somnilux runs a third-party application under a compatibility layer neither of
those parties supports on Linux. It works well, and it's still a setup neither
vendor tests.
