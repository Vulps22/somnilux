# Somnilux

**Somnium Space on Linux**

![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Platform: Linux](https://img.shields.io/badge/platform-Linux-informational)
![Somnium Space](https://img.shields.io/badge/Somnium%20Space-3.2.5-success)
![Docs](https://img.shields.io/badge/docs-vulps22.github.io%2Fsomnilux-blue)

Wine/Proton patches and setup tooling for running [Somnium Space](https://somniumspace.com)
on Linux, in the absence of an official Linux-native client (currently in
closed beta, per Somnium staff).

**Not affiliated with Somnium Space Ltd, the Wine project, or WineHQ.**
This project never distributes, modifies, or redistributes any of Somnium's
own client/launcher binaries. You supply your own copy of Somnium's official
installer; Somnilux launches it for you once the environment is ready.
Everything here is a patch to Wine itself, free and open source software
(LGPL-2.1), fixing genuine Wine compatibility bugs that this app happens
to trigger.

## Requirements

- `curl`, `tar`, and `python3` 3.10 or newer — checked before anything is
  downloaded, and named for you if something is missing.
- A GPU driver and OpenXR runtime you can already run other VR titles with.
- `whiptail` is optional but recommended. Without it the installer falls back
  to plain text prompts, which work but are less well tested.

You do **not** need Steam, Lutris, Heroic, or a system-wide
[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) — Somnilux
downloads its own private copy of everything it needs.

## Quick start

First, get Somnium Space's own Windows installer from
[somniumspace.com](https://somniumspace.com) — the script will ask you where
you saved it. Somnilux never distributes it for you.

> Signing up for the first time? Use my referral code **VULPS22-WH22**.

Then download and run the latest release:

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

It'll walk you through installing fresh, or repairing an existing setup.

> Download the script and run it as a file, as above. Don't pipe it straight
> into a shell (`curl ... | bash`) — that consumes standard input, and the
> installer needs it to ask you questions.

Connect your headset to the PC **before** you launch. Detection happens once,
the moment Somnium starts, so a runtime with no headset attached to it has
nothing to report.

This release is verified working with Somnium Space **3.2.5**. If you're on a
newer version and still running into problems, check whether a newer release
of this script is available.

## Documentation

Full documentation lives at **<https://vulps22.github.io/somnilux/>**.

| | |
| --- | --- |
| [Installing](https://vulps22.github.io/somnilux/install/installing/) | What each step of the installer is doing |
| [Updating](https://vulps22.github.io/somnilux/install/updating/) | Update notices, and what "Update needed" means |
| [VR runtimes and headsets](https://vulps22.github.io/somnilux/run/vr-runtimes/) | Runtime detection, and `openxr.conf` when it isn't enough |
| [The launch window](https://vulps22.github.io/somnilux/run/launch-window/) | What the terminal that opens is telling you |
| [Video playback](https://vulps22.github.io/somnilux/run/video/) | What plays today, and what doesn't |
| [Common failures](https://vulps22.github.io/somnilux/troubleshooting/common-failures/) | Symptom, cause, fix |
| [Reading launch.log](https://vulps22.github.io/somnilux/troubleshooting/launch-log/) | The first thing to attach to a bug report |
| [Known issues](https://vulps22.github.io/somnilux/troubleshooting/known-issues/) | What's broken and what's being done about it |
| [Distro tips & tricks](https://vulps22.github.io/somnilux/distros/cachyos/) | Anything a particular distribution needs by hand |
| [What's fixed and why](https://vulps22.github.io/somnilux/understanding/whats-fixed/) | The Wine bugs behind all of this |
| [Building from source](https://vulps22.github.io/somnilux/contributing/building/) | Rebuilding the binaries a release ships |

## Compatibility

Confirmed on **CachyOS**, **Linux Mint** and **Nobara 44**, with **SteamVR**
and **WiVRn** driving a Quest 3, Quest 3S or PICO 4 Ultra. CachyOS needs a
couple of tweaks by hand — [they're written up here](https://vulps22.github.io/somnilux/distros/cachyos/).

Everything else is untested rather than broken. The full tables are in
[distribution notes](https://vulps22.github.io/somnilux/troubleshooting/distributions/)
and [VR runtimes](https://vulps22.github.io/somnilux/run/vr-runtimes/), and
they only grow from reports — so if you get Somnilux running on something not
listed, or find one of them doesn't hold up, please
[open an issue](https://github.com/Vulps22/somnilux/issues) or ping me on
Discord (`@vulps22`). Good or bad, it all helps.

## What's fixed

**Connecting to Somnium.** Wine couldn't do mutual-TLS client certificate
authentication, which the launcher and the Game Service need both between
themselves and against Somnium's servers. Four fixes across `crypt32` and
`secur32`, one of which — `SECPKG_ATTR_ISSUER_LIST_EX` — was simply
unimplemented in Wine.

**Video playback.** Five separate faults, each one hiding the next, across
`winedmo`, `kernelbase` and ffmpeg's build. Three of them are bugs in stock
GE-Proton rather than anything specific to Somnium, and affect any app that
plays media.

The detail, and why each one mattered, is in
[What's fixed and why](https://vulps22.github.io/somnilux/understanding/whats-fixed/).

## What's in this repo

- `patches/` — the Wine source patches, `git format-patch` output, split by
  the tree they apply to. This is also how the LGPL "corresponding source"
  obligation for the prebuilt binaries is met.
- `scripts/install.sh` — the setup script users run.
- `scripts/build-artifacts.sh` — builds every binary a release ships. A
  developer tool, never part of a release.
- `supported/` — versions and compatibility data, fetched at run time so
  publishing an update doesn't need a new script release.

See [Building from source](https://vulps22.github.io/somnilux/contributing/building/)
for how to reconstruct either Wine tree, and
[CONTRIBUTING.md](CONTRIBUTING.md) for the contribution process.

## License

The setup scripts and this documentation are MIT-licensed (see `LICENSE`).
The patches in `patches/`, being modifications to Wine, are licensed under
Wine's own license, LGPL-2.1 (see
<https://gitlab.winehq.org/wine/wine/-/raw/master/LICENSE>).

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at
your own risk — the author accepts no responsibility for any damage, data
loss, or other consequences resulting from running this script.
