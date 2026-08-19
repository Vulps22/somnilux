# Somnilux install script — scope and feature plan

Reference spec for the setup script, agreed before any code is written.
Each implementation step should be committed once it's a complete,
runnable change — not left half-done across commits.

## What the script does NOT do

- Never downloads or redistributes Somnium's own installer or client
  binaries. The user always supplies the path to their own copy of the
  official installer.
- Never touches the shared, Steam-managed `compatibilitytools.d` Proton
  installs. Only ever creates/uses its own isolated Proton copy.
- Not a persistent tool. Runs once for install, maybe again later for a
  repair/update. No state file, no config it reads back on a later run.
  The one exception is the default prefix location itself, which acts as
  the de facto "did I already do this" check on a repair run (see below).

## TUI

- `whiptail`-based menus/prompts.
- At startup, check whether `whiptail` is available. If not, fall back to
  plain `read`-based text prompts — no attempt to detect the user's distro
  or offer an install command for `whiptail`.
- Every `whiptail` screen uses `--backtitle "somnilux — github.com/Vulps22/somnilux"`
  so the repo link is always visible, pinned at the top.

## Top-level flow

First screen: **Install** or **Repair**.

### Repair flow

1. Check the default prefix location (`~/Games/umu/umu-somnium`, umu's own
   default for `GAMEID=umu-somnium` when `WINEPREFIX` isn't set).
2. Found → use it.
3. Not found → tell the user nothing was found at the default location,
   and ask them to provide the prefix path manually.
4. Re-apply the patched `secur32`/`crypt32`/`rsaenh` into that prefix's
   Proton copy, and refresh the `.desktop` entry. Does not touch the
   prefix's own game data/registry beyond that.

### Install flow

1. Prompt for the path to Somnium's own installer executable (a file the
   user already has locally — never fetched by the script).
2. Prompt for where to put the prefix. Pre-filled with the umu default
   (`~/Games/umu/umu-somnium`) as a suggestion, but fully overridable —
   don't assume everyone wants it on their home/OS drive; some users have
   several game drives.
3. Pick a Proton version:
   - Menu populated from `supported/proton.txt` (see below), fetched
     fresh from the `somnilux` GitHub repo every run — no local caching,
     no staleness logic.
   - Default selection comes from `supported/default.txt`.
   - If the user picks anything other than the default entry, show a
     warning built dynamically from `supported/default.txt`'s two lines:
     `"This version of Proton is untested and may break the launcher.
     {default proton version} and Wine {default wine version} is
     recommended."` The warning text is never hardcoded in the script.
4. The isolated, patched Proton copy is extracted as a sibling directory
   next to the chosen prefix location (same drive/parent folder as
   whatever the user picked in step 2) — colocated with the game data,
   not in a separate fixed location, and not in Steam's
   `compatibilitytools.d`. Named `<proton-version>-somnilux` (e.g.
   `GE-Proton11-5-somnilux`).
5. Create the prefix (via `umu-run`, `GAMEID=umu-somnium`).
6. Download this project's prebuilt, patched `secur32.so`/`.dll`,
   `crypt32.so`/`.dll`, `rsaenh.dll` (GitHub Release assets on
   `somnilux`) and install them into the isolated Proton copy from step 4
   (originals kept as `.orig`, matching the manual convention used
   throughout this project).
7. Hand off to Somnium's own installer, run inside the new prefix, for
   the user to actually install Somnium.
8. Create a `.desktop` entry pointing at the installed Launcher inside
   the prefix, with `PROTONPATH`/`WINEPREFIX`/`GAMEID` baked into the
   `Exec=` line — since Somnium's own installer doesn't create one, and
   without it there's no Linux start-menu entry at all.

## `supported/` folder (lives in the `somnilux` repo, fetched at runtime)

- `supported/proton.txt` — list of GE-Proton releases actually verified
  end-to-end against Somnium (Launcher reaches home page, connects into
  VR). This is the list the picker menu and the "untested" warning
  actually consult at runtime.
- `supported/wine.txt` — general reference list of the underlying Wine
  versions this project's prebuilt DLLs are known compatible with
  (currently just `11.15`). Documentation for whoever adds the next
  verified entry to `proton.txt` — not automatically cross-referenced by
  the script itself (that would require inspecting an arbitrary Proton
  release's own Wine base at runtime, which is out of scope for now).
- `supported/default.txt` — two lines: the recommended Proton version,
  then its corresponding Wine version. Drives both the menu's
  pre-selected default and the exact wording of the untested-version
  warning.

Starting content: `proton.txt` = `GE-Proton11-5`; `wine.txt` = `11.15`;
`default.txt` = `GE-Proton11-5` / `11.15`.

## Prerequisite (not part of the script itself)

The script depends on prebuilt release binaries existing on `somnilux`.
Before/alongside building the script, publish a GitHub Release there with
the patched `secur32.so`/`.dll`, `crypt32.so`/`.dll`, `rsaenh.dll`, built
from the merged `release` branch in `wine-source` (schannel fixes +
crypt32 OID fix combined, built from one consistent source tree).
