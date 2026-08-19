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

You do **not** need Steam, Lutris, Heroic, or a system-wide
[umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)
install. Somnilux downloads its own private copy of `umu-run` into
`~/.local/share/somnilux/`, so it doesn't depend on your distribution
packaging one.

`whiptail` is optional but recommended — the script falls back to plain text
prompts without it, but the guided TUI is nicer (and better tested):

```sh
sudo apt install whiptail    # Debian/Ubuntu/Mint
sudo dnf install newt        # Fedora/Nobara (provides whiptail)
sudo pacman -S libnewt       # Arch (provides whiptail)
```

## Quick start

Download and run the latest release:

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

## If the shortcut doesn't seem to do anything

The applications-menu shortcut writes everything the launcher prints to:

```
~/.local/share/somnilux/launch.log
```

That's the first place to look, and the most useful thing to attach to a
bug report. The installer itself keeps a separate debug log, whose path it
prints if it fails.

## Tested distributions

Somnilux has been tested on the following Linux distributions:

| Distribution | Stable | Notes |
| --- | --- | --- |
| Nobara 44 (Fedora) | ✅ | Primary development and testing machine. |

## Tested OpenXR runtimes

Somnium Space has been confirmed to run with the following OpenXR runtimes:

| Runtime | Stable | Headsets | Notes |
| --- | --- | --- | --- |
| SteamVR | ✅ | Quest 3 (via Steam Link) | Runs almost flawlessly. |

Anything not listed simply hasn't been tried yet, rather than being known
broken. If you get Somnilux working on another distribution, runtime or
headset — or find one of the above doesn't hold up — please
[open an issue](https://github.com/Vulps22/somnilux/issues) or ping me on
Discord (`@vulps22`). Good or bad, it all helps, and the tables above only
grow from reports.

## Known issues

- **Viewing your desktop from inside Somnium Space can crash the client**
  on some distributions.
- **The social app doesn't work in the launcher.**

## What's fixed

- Fixed `CertNameToStrW` not prefixing unrecognized certificate OIDs with `OID.` (crypt32)
- Added client-certificate requests over local mutual-TLS connections (secur32)
- Added async pause/resume support so a client can respond to a certificate request mid-handshake (secur32)
- Implemented `SECPKG_ATTR_ISSUER_LIST_EX` so a client can actually select which certificate to send (secur32)

## Layout

- `patches/` — the actual Wine source patches (`git format-patch` output,
  apply with `git am`), plus `BASE_COMMIT.txt` recording the exact upstream
  Wine commit they apply against. This is also how the LGPL "corresponding
  source" obligation for the prebuilt binaries below is satisfied: the
  unmodified base is already public (`wine-mirror/wine` /
  `gitlab.winehq.org/wine/wine`), and our diff on top of it is here.
- `scripts/install.sh` — the setup script: downloads a GE-Proton release and
  its own copy of `umu-run`, downloads this project's prebuilt patched
  `secur32`/`crypt32`/`rsaenh`, and wires up a working prefix. Handles both
  a fresh install and repairing an existing one.
- `supported/` — the Proton and Wine versions this project recommends,
  fetched by `install.sh` at run time so updates don't require a new script
  release.

## License

The setup scripts and this documentation are MIT-licensed (see `LICENSE`).
The patches in `patches/`, being modifications to Wine, are licensed under
Wine's own license, LGPL-2.1 (see
<https://gitlab.winehq.org/wine/wine/-/raw/master/LICENSE>).

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at
your own risk — the author accepts no responsibility for any damage, data
loss, or other consequences resulting from running this script.
