# Building from source

Everything Somnilux ships can be rebuilt from public sources.
`scripts/build-artifacts.sh` does the whole build in one run — the patched
Wine DLLs from two separate trees, and ffmpeg.

It's a developer tool. It's tracked in git but never packaged into a release.

## What gets built

| From | Produces |
| --- | --- |
| Upstream Wine + `patches/wine/` | `secur32`, `crypt32`, `rsaenh` |
| GE's Wine tree + `patches/ge/` | `winedmo`, `kernelbase` |
| ffmpeg 8.1, one extra flag | `avcodec`, `avformat`, `avutil`, `swscale`, `swresample` |

Two Wine trees, because the video patches touch code that only exists once
GE-Proton's media rework is applied — that rework removes winegstreamer and
makes winedmo the sole Media Foundation backend, which upstream doesn't do.

## Reconstructing the trees

[`patches/BASE_COMMIT.txt`](https://github.com/Vulps22/somnilux/blob/main/patches/BASE_COMMIT.txt)
records the exact base commit for each and the commands to rebuild them. In
outline:

**Upstream** — clone `wine-mirror/wine`, check out the recorded commit
(Wine 11.15), and `git am` the four patches in `patches/wine/`.

**GE** — fetch the ValveSoftware/wine commit that is GE-Proton11-5's wine
submodule, apply GE's own `ge-video-rework` patches, then `git am` the four in
`patches/ge/`.

Three quirks in the GE tree, all recorded in `BASE_COMMIT.txt` and worth
knowing before you hit them:

- `0011-rsx` doesn't apply and isn't needed
- One hunk of `0006` — the one registering `winedmo.dll` instead of
  `winegstreamer.dll` — must be applied by hand
- Proton doesn't commit several generated files. Run `autoreconf -f`,
  `tools/make_requests`, `tools/make_specfiles` and
  `dlls/winevulkan/make_vulkan` before configuring. The last one `chdir`s
  internally, so run it from its own directory.

## ffmpeg

GE-Proton's ffmpeg has **no software AV1 decoder**, so AV1 falls back to a
hardware-only stub that fails every frame.

Their configure line uses `--enable-decoders`, which covers built-in decoders
only — decoders from external libraries each need their own flag. `libdav1d`
already ships in the GE tree for GStreamer's benefit; ffmpeg just wasn't
linked against it.

The build is ffmpeg 8.1 with **GE's exact configure line plus
`--enable-libdav1d`**. You can read GE's flags back at any time from
`avcodec_configuration()`.

Build dependencies: `libdav1d-devel` (note the `lib` prefix), `nasm`,
`gnutls-devel`, `xz-devel`, `bzip2-devel`.

This is a one-flag fix that would benefit every GE-Proton user.

## Running the build

```sh
./scripts/build-artifacts.sh
```

Paths are overridable by environment variable — `WINE_SOURCE_DIR`,
`WINE_GE_DIR`, `FFMPEG_DIR`, `OUT_DIR`, `ARCHIVE`, `REFERENCE_PROTON`, `JOBS`.

It stages everything into `build-artifacts/` and packages
`somnilux-binaries.tar.gz`.

## The two checks that matter

**`verify_sources`** greps each tree for a marker of our own patches *before*
building. This exists because a build once shipped from a tree checked out on
the wrong branch: every other check passed, because they all verified the
artefacts' *shape* and none verified their *content*.

**Soname verification** compares `DT_NEEDED` entries against a reference
Proton. A *gained* dependency is fine; a *missing* one fails the build. Always
check `readelf -d` sonames against the binary being replaced — that check has
caught a real problem.

The format number is not duplicated here: the script asks
`install.sh --supported-format` for it, so the writer and the reader can't
drift. See [Archive format](archive-format.md).

## Testing what you built

```sh
./scripts/install.sh --use-local-dlls-at ./somnilux-binaries.tar.gz
```

See [Testing a build](testing.md).
