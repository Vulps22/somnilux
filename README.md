# Somnilux

Wine/Proton patches and setup tooling for running [Somnium Space](https://somniumspace.com)
on Linux, in the absence of an official Linux-native client (currently in
closed beta, per Somnium staff).

**Not affiliated with Somnium Space Ltd, the Wine project, or WineHQ.**
This project does not distribute, modify, or redistribute any of Somnium's
own client/launcher binaries — you install those yourself from Somnium's
official installer. Everything here is a patch to Wine, which is free and
open source software (LGPL-2.1), aimed at fixing genuine Wine compatibility
bugs that this app happens to trigger.

## Status

Working. Run `scripts/install.sh` to install or repair a Somnium Space
setup on Linux.

This release is verified working with Somnium Space **3.2.5**. If you're
on a newer version and still running into problems, check whether a newer
release of this script is available.

## What's fixed

Two independent Wine bugs, both hit by Somnium's Launcher/Game Service
during their local mutual-TLS handshake and certificate handling under
Wine/Proton:

1. **`crypt32`: unrecognized certificate OIDs formatted wrong.**
   `CertNameToStrW` renders an RDN attribute OID with no registered
   friendly name as the bare dotted-decimal number; real Windows prefixes
   it with `OID.`. Apps that derive values (e.g. a cipher key) from a
   certificate's `Subject`/`Issuer` string get a different value than on
   real Windows whenever the certificate contains an OID Wine doesn't
   recognize by name.
2. **`secur32`/SChannel: no support for the SSPI pause-and-retry contract
   .NET uses for anonymous-start mutual TLS**, plus a related missing
   `SECPKG_ATTR_ISSUER_LIST_EX` implementation that meant a client could
   never learn which CAs a server would accept, and so could never select
   a certificate to send. Three patches: requesting/detecting the need for
   a client cert, the async pause/resume mechanism itself, and the
   `SECPKG_ATTR_ISSUER_LIST_EX` implementation — see each patch's own commit
   message for details.

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
