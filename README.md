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

## Quick start

Download and run the latest release:

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

It'll walk you through installing fresh, or repairing an existing setup.

This release is verified working with Somnium Space **3.2.5**. If you're
on a newer version and still running into problems, check whether a newer
release of this script is available.

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
- `scripts/install.sh` — the setup script: downloads a GE-Proton release,
  downloads this project's prebuilt patched `secur32`/`crypt32`/`rsaenh`,
  and wires up a working prefix. Handles both a fresh install and
  repairing an existing one.

## License

The setup scripts and this documentation are MIT-licensed (see `LICENSE`).
The patches in `patches/`, being modifications to Wine, are licensed under
Wine's own license, LGPL-2.1 (see
<https://gitlab.winehq.org/wine/wine/-/raw/master/LICENSE>).
