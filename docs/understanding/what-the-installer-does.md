# What the installer does

`install.sh` is a shell script you're welcome to read before running — it's
about 1,700 lines and it doesn't hide anything. This page is the summary.

**It never asks for `sudo`.** Everything goes under your home directory or the
install location you choose. No packages are installed, no system files are
modified.

## Step by step

### 1. Checks dependencies

`curl`, `tar`, and `python3` 3.10 or newer, before anything is downloaded. If
one is missing you're told which, rather than failing halfway.

### 2. Stops a running Somnium

Files in use can't be replaced safely, and any Wine command would block behind
the existing session. If something can't be stopped, it says so instead of
carrying on.

### 3. Fetches the supported versions

The list of Proton versions, the recommended default, and which published
binaries this installer can use are all fetched live from the project. That's
why a new Proton recommendation doesn't require a new script release.

### 4. Downloads its own `umu-run`

Into `~/.local/share/somnilux/umu/`, at a pinned version, checksum-verified.

Somnilux calls it by absolute path. It doesn't use, need, or interfere with a
system `umu-launcher` package — which is why it works on distributions that
don't package one.

### 5. Downloads GE-Proton

Checksum-verified, extracted to a directory named for the version with a
`-somnilux` suffix, beside your install location.

This is a **private copy**. Your Steam Proton installs under
`compatibilitytools.d/` are never read, written, or noticed — the suffix and
the location outside Steam's search path both exist to keep the two apart.

### 6. Installs the patched binaries

Downloaded from the project's own release, or from a local archive with
[`--use-local-dlls-at`](../install/options.md#-use-local-dlls-at-archive).

Before anything is written, the archive is checked: it must declare a format
this installer understands, and must contain only directories the installer
knows how to install. An unstamped or unexpected archive is refused outright.
See [Archive format](../contributing/archive-format.md).

Installs are **staged**, so an interrupted run can't leave your Proton copy
half-patched.

The files replaced are `secur32`, `crypt32`, `rsaenh`, `winedmo`, `kernelbase`
and five ffmpeg libraries — all within that private Proton copy. Nothing
outside it is touched. See [What's fixed and why](whats-fixed.md).

### 7. Creates the prefix and runs Somnium's installer

A Wine prefix is a self-contained fake Windows drive. Somnilux creates one at
your chosen location and runs **your** copy of Somnium's official installer
inside it.

That installer is Somnium's, unmodified, and Somnilux never supplies it — you
provide the file.

### 8. Generates the launch script

At `~/.local/share/somnilux/launch.sh`. This is what the desktop entry
actually runs, and it's a readable shell script too. Every launch it:

- Checks whether a newer Somnilux exists, and tells you — without downloading
  anything
- Detects your active OpenXR runtime and makes it reachable inside the
  container
- Offers to stop a [previous session](../run/restarting.md) if one is running
- Writes everything to `launch.log`

### 9. Creates the desktop entry

At `~/.local/share/applications/somnium-space.desktop`, using Somnium's own
icon converted with ImageMagick if it's available. Without ImageMagick you get
an entry with no icon, which works fine.

## What it never touches

- Your system Wine, if you have one
- Your Steam installation, or `compatibilitytools.d/`
- System packages, `/usr`, `/etc`, or anything needing root
- Your OpenXR runtime or its configuration
- Somnium's own binaries — see [Licensing](licensing.md)

## Repairing

Choosing repair re-runs steps 4, 5, 6, 8 and 9 against an install that already
exists. Your prefix and your Somnium install are left alone — nothing is
re-downloaded from Somnium and no settings are lost.

See [Layout on disk](layout.md) for where all of this ends up.
