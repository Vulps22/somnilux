# Somnilux

**Somnium Space on Linux**

![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Platform: Linux](https://img.shields.io/badge/platform-Linux-informational)
![Somnium Space](https://img.shields.io/badge/Somnium%20Space-3.2.5-success)

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

- `curl`, `tar`, and `python3` 3.10 or newer — the script checks for these
  before it does anything and tells you if something's missing.
- A GPU driver and OpenXR runtime you can already run other VR titles with.

You do **not** need Lutris, Heroic, or a system-wide
[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)
install, and you don't need Steam unless you intend to use SteamVR to
access Somnium Space. Somnilux downloads its own private copy of `umu-run`
into `~/.local/share/somnilux/`, so it doesn't depend on your distribution
packaging one.

`whiptail` is optional but recommended — the script falls back to plain text
prompts without it, but the guided TUI is nicer (and better tested):

```sh
sudo apt install whiptail    # Debian/Ubuntu/Mint
sudo dnf install newt        # Fedora/Nobara (provides whiptail)
sudo pacman -S libnewt       # Arch (provides whiptail)
```

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

This release is verified working with Somnium Space **3.2.5**. If you're
on a newer version and still running into problems, check whether a newer
release of this script is available.

### If it says the fixes don't match

The patched binaries are published separately from the script, and each
installer only installs a build laid out the way it expects.

- **"Update needed"** — newer fixes exist than this script knows how to
  install. It carries on with the newest it can use; grab the latest release
  when you want the rest.
- **"No compatible fixes found"** or **"Incompatible fixes"** — nothing
  published matches this script, so nothing has been installed. That's a
  mistake on my end rather than anything you did, so please
  [open an issue](https://github.com/Vulps22/somnilux/issues).

### Update notices

Starting Somnium checks whether a newer Somnilux has been published, and says
so before carrying on to the launcher. It waits ten seconds, or presses on
straight away if you hit Enter. Nothing is downloaded or changed — updating is
still running the installer yourself.

If you're offline it stays quiet and launches as usual.

## The launch window

Starting Somnium opens a terminal window telling you what it's doing:

```
Starting Somnium Space Launcher
Detected OXR Runtime: SteamVR
Launching: env PROTONPATH=... WINEPREFIX=... umu-run ".../Somnium Space Launcher.exe"
===================================================================

You can safely close this window.
```

Closing that window does not stop Somnium. It's there so you can see which
OpenXR runtime was picked up, and so that a launch which fails says so
instead of doing nothing at all.

Everything else — the full launcher, umu and Proton output — goes to:

```
~/.local/share/somnilux/launch.log
```

That's the most useful thing to attach to a bug report. The installer keeps
a separate debug log, whose path it prints if it fails.

## VR runtimes

The shortcut runs `~/.local/share/somnilux/launch.sh`, which works out which
OpenXR runtime is active each time you start the game and makes it reachable
from inside the container umu runs Somnium in. Switching runtime needs no
reinstall and no configuration — set your runtime as active the usual way and
start Somnium again.

Runtimes installed under your home directory (SteamVR, per-user Flatpaks,
Envision builds) need nothing extra. System-wide Flatpak and `/opt` installs
have their install directory shared into the container automatically.

If your runtime needs something this doesn't work out on its own, create:

```
~/.local/share/somnilux/openxr.conf
```

with one `NAME=value` environment assignment per line. When that file exists
it replaces the automatic detection entirely, so include every variable you
need:

```
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
PRESSURE_VESSEL_FILESYSTEMS_RW=/var/lib/flatpak/app/io.github.wivrn.wivrn
```

If you need one of these, please [open an issue](https://github.com/Vulps22/somnilux/issues)
with your runtime and the contents — it usually means the automatic detection
should be handling your case.

## Restarting

Starting Somnium while it's already running stops the previous session first,
then starts a clean one. This clears a stuck launcher, which otherwise leaves
a `wineserver` holding the prefix and makes every later start hang silently.

It asks first, and it applies to a healthy session too — if Somnium is up and
working, continuing will close it and start over:

- In the launch window it counts down ten seconds. Press Ctrl+C to cancel,
  or Enter to go immediately.
- If no terminal could be opened, it shows a dialog instead. If nothing
  answers it within thirty seconds it goes ahead, on the assumption that you
  launched it because the old session was stuck.

Only processes belonging to this Somnilux prefix are stopped; other Wine or
Proton games running at the same time are left alone.

## Video playback

In-world screens play, with sound and ARS reactive lighting. What works today:

| Source | Video | Audio | Notes |
| --- | --- | --- | --- |
| YouTube | ✅ | ✅ | 360p |
| RTSP / RTSPT | ✅ | ❌ | How VRCDN streams to in-world players |
| VRCDN over HTTPS | ❌ | ❌ | Doesn't load |
| Twitch | ❌ | ❌ | Doesn't load |

YouTube is capped at 360p because Somnium asks `yt-dlp` for a single stream,
and 360p is the best YouTube still serves with the audio already in it —
everything above that is video-only and would play silently. Sound seemed the
better trade.

## Tested distributions

Somnilux has been tested on the following Linux distributions:

✅ confirmed working · ⚠️ untested · ❌ known broken

| Distribution | Stable | Notes |
| --- | --- | --- |
| Arch Linux | ⚠️ | Untested |
| Bazzite | ⚠️ | Untested |
| Debian | ⚠️ | Untested |
| Fedora | ⚠️ | Untested |
| Linux Mint | ✅ | |
| Manjaro | ⚠️ | Untested |
| Nobara 44 | ✅ | |
| openSUSE | ⚠️ | Untested |
| Pop!_OS | ⚠️ | Untested |
| Ubuntu | ⚠️ | Untested |

## Tested OpenXR runtimes

Somnium Space has been confirmed to run with the following OpenXR runtimes:

✅ confirmed working · ⚠️ untested · ❌ known broken

| Runtime | Stable | Headsets | Notes |
| --- | --- | --- | --- |
| SteamVR | ✅ | Quest 3 | |
| WiVRn | ✅ | Quest3, Quest 3s |  |
| Monado | ⚠️ | | Untested |

Untested doesn't mean broken — just that nobody has reported back yet. If
you get Somnilux working on any of the above, on something not listed, or
find one of them doesn't hold up, please
[open an issue](https://github.com/Vulps22/somnilux/issues) or ping me on
Discord (`@vulps22`). Good or bad, it all helps, and these tables only grow
from reports.

## Known issues

- **Viewing your desktop from inside Somnium Space can crash the client**
  on some distributions.
- **The social app doesn't work in the launcher.**
- **Video playback is partial** — see [Video playback](#video-playback) for
  what plays and what doesn't. These fixes are a large job and arrive in
  stages as they become available.

## What's fixed

**Connecting to Somnium.** Wine couldn't do mutual-TLS client certificate
authentication, which the launcher and the Game Service need both between
themselves and against Somnium's servers.

- Fixed `CertNameToStrW` not prefixing unrecognized certificate OIDs with `OID.` (crypt32)
- Added client-certificate requests over local mutual-TLS connections (secur32)
- Added async pause/resume support so a client can respond to a certificate request mid-handshake (secur32)
- Implemented `SECPKG_ATTR_ISSUER_LIST_EX` so a client can actually select which certificate to send (secur32)

**Video playback.** Five separate faults, each one hiding the next.

- Stopped `IMFSchemeHandler::BeginCreateObject` downloading the whole resource
  before returning, which deadlocked the media engine and froze the client (winedmo)
- Remote http(s) media is opened by URL instead of being fetched in full first —
  minutes of waiting, and 185MB, for one video (winedmo)
- Added support for RTSP and RTSPT streams (winedmo)
- Built ffmpeg with `--enable-libdav1d`, so AV1 video decodes at all — GE-Proton's
  own build has no software AV1 decoder and fails every frame
- Pointed `yt-dlp` at a client that still serves picture and sound in one stream,
  so YouTube videos have audio (kernelbase)

The deadlock, the pre-download and the missing AV1 decoder are bugs in stock
GE-Proton rather than anything specific to Somnium — they affect any app that
plays media.

## Layout

- `patches/` — the Wine source patches (`git format-patch` output, apply with
  `git am`), split by the tree they apply to. `patches/wine/` goes on upstream
  Wine; `patches/ge/` goes on GE-Proton's tree, because the video fixes touch
  code that only exists once GE's own media rework has been applied.
  `BASE_COMMIT.txt` records both base commits and how to rebuild either tree.
  This is also how the LGPL "corresponding source" obligation for the prebuilt
  binaries below is satisfied: the unmodified base is already public
  (`wine-mirror/wine` / `gitlab.winehq.org/wine/wine`), and our diff on top of
  it is here.
- `scripts/install.sh` — the setup script: downloads a GE-Proton release and
  its own copy of `umu-run`, installs this project's prebuilt patched binaries
  over that Proton, and wires up a working install. Handles both a fresh
  install and repairing an existing one. It also generates
  `~/.local/share/somnilux/launch.sh`, which is what the desktop shortcut
  actually runs.
- `scripts/build-artifacts.sh` — builds every binary a release ships: the Wine
  DLLs from both trees above, and ffmpeg. A developer tool, never part of a
  release.
- `supported/` — the Proton and Wine versions this project recommends, the
  current script release, and which published binaries each version of the
  installer is able to use. Fetched at run time by `install.sh`, and by the
  launch script when it checks for updates, so publishing an update doesn't
  require a new script release just to announce it.

## License

The setup scripts and this documentation are MIT-licensed (see `LICENSE`).
The patches in `patches/`, being modifications to Wine, are licensed under
Wine's own license, LGPL-2.1 (see
<https://gitlab.winehq.org/wine/wine/-/raw/master/LICENSE>).

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at
your own risk — the author accepts no responsibility for any damage, data
loss, or other consequences resulting from running this script.
