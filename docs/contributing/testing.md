# Testing a build

## Installing a local archive

```sh
./scripts/install.sh --use-local-dlls-at ./somnilux-binaries.tar.gz
```

Installs the patched binaries from a local `.tar.gz` instead of downloading
them from a release. Everything else about the install is unchanged, including
every format check — the archive must still declare a format this installer
understands and contain only directories it knows how to install.

That's deliberate. Testing a build that skipped the checks would defeat the
point of having them.

## The smoke test

**Launch Somnium and check its own logs report no errors and no maintenance
mode.**

```
<prefix>/drive_c/users/steamuser/AppData/Local/Temp/Somnium Space Ltd/logs/launcher_output_log.log
<prefix>/drive_c/users/steamuser/AppData/Local/Temp/Somnium Space Ltd/logs/game_service_output_log.log
```

Somnium's own logs, not `launch.log`. Wine's side can look completely clean
while Somnium's own code records the real failure — a certificate problem
shows up as an auth error there and as nothing at all in Wine's output.

`verify_sources` in `build-artifacts.sh` covers the build-side half of this
(it would have caught a build shipping unpatched crypto). This is the
launch-side half.

## Before every run

Check for stale processes:

```sh
ps aux | grep -iE "somnium|umu-run|wine|proton"
```

A leftover process holds the prefix's wineserver lock, and new launches hang
silently. Kill anything left over before relaunching.

The generated `launch.sh` handles this for users, offering to stop a previous
session. When testing by hand you're bypassing that.

## Testing a clean install

To verify what a new user actually gets, remove the existing install first —
`~/.local/share/somnilux`, the `-somnilux` Proton directory, the desktop
entry — while leaving Somnium itself in place, then install straight from
GitHub.

See [Uninstalling](../install/uninstalling.md) for what to remove and what to
keep.

## Test environment

```sh
PROTONPATH=/path/to/GE-ProtonXX-X-somnilux \
WINEPREFIX=/path/to/prefix \
GAMEID=umu-somnium \
  umu-run "<prefix>/drive_c/Program Files/Somnium Space/Somnium Space Launcher.exe"
```

Useful for tracing with `WINEDEBUG`, which the desktop-entry path discards.

!!! warning "Launch through the traced command, not into it"
    Somnium must be **fully closed first and launched through** the traced
    command. Attaching to an already-running desktop-entry session gets
    nothing — Proton sets `WINEDEBUG=-all` there and the output is discarded.
    A trace was lost this way once.
