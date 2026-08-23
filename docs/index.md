# Somnilux

**Somnium Space on Linux.**

Wine/Proton patches and setup tooling for running
[Somnium Space](https://somniumspace.com) on Linux, in the absence of an
official Linux-native client (currently in closed beta, per Somnium staff).

## Quick start

**1. Get Somnium Space's own Windows installer** from
[somniumspace.com](https://somniumspace.com). Somnilux never distributes it
for you — the script will ask where you saved it.

!!! tip "Signing up for the first time?"
    Use my referral code **VULPS22-WH22**.

**2. Download the latest Somnilux release** and run it:

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

!!! warning "Run it as a file, not through a pipe"
    Don't pipe the script straight into a shell (`curl ... | bash`). That
    consumes standard input, and the installer needs it to ask you questions.

**3. Answer the prompts.** The script walks you through a fresh install or
repairs an existing one. See [Installing](install/installing.md) if you want
to know what each step is doing.

**4. Launch Somnium** from your desktop's start menu. A terminal window opens
showing which OpenXR runtime was detected — you can
[safely close it](run/launch-window.md).

### Before you start

- `curl`, `tar`, and `python3` 3.10 or newer. The script checks for these
  first and tells you if something's missing.
- A GPU driver and OpenXR runtime you can already run other VR titles with.
- `whiptail` is optional but recommended (`newt` on Fedora/Nobara, `libnewt`
  on Arch) — without it the script falls back to plain text prompts.

You do **not** need Lutris, Heroic, a system-wide
[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher), or
Steam — unless you intend to use SteamVR to reach Somnium Space. Somnilux
downloads its own private copy of `umu-run`.

## Where to go next

- **[Installation](install/installing.md)** — the long-form walkthrough,
  command-line options, updating, and removing it again.
- **[Running](run/launch-window.md)** — the launch window, VR runtimes, video
  playback, and restarting cleanly.
- **[Troubleshooting](troubleshooting/launch-log.md)** — reading `launch.log`,
  common failures, and how to report a problem.
- **[Understanding](understanding/whats-fixed.md)** — what these patches
  actually fix in Wine, what the installer does to your system, and licensing.
- **[Contributing](contributing/building.md)** — building the binaries,
  the archive format scheme, and the release process.

## Not affiliated

Not affiliated with Somnium Space Ltd, the Wine project, or WineHQ. This
project never distributes, modifies, or redistributes any of Somnium's own
client or launcher binaries. You supply your own copy of Somnium's official
installer; Somnilux launches it for you once the environment is ready.
Everything here is a patch to Wine itself — free and open source software
(LGPL-2.1) — fixing genuine Wine compatibility bugs that this app happens to
trigger.

Somnilux is provided as is, with no responsibility taken for damage or data
loss. See [Licensing](understanding/licensing.md).
