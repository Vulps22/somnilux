# Layout on disk

Two places, plus a desktop entry. Paths below assume the default install
location; substitute your own if you chose differently.

Somnilux remembers where it put things:

```sh
cat ~/.local/share/somnilux/paths.conf
```

## `~/.local/share/somnilux/`

Somnilux itself. Small — a few tens of megabytes.

| Path | What it is |
| --- | --- |
| `umu/umu-run` | The vendored launcher, called by absolute path |
| `umu/version` | Version stamp, so a changed pin re-downloads |
| `launch.sh` | Generated launch script — what the desktop entry runs |
| `launch.log` | Output of the most recent launch. [Overwritten each time](../troubleshooting/launch-log.md) |
| `openxr.conf` | Optional [runtime override](../run/vr-runtimes.md#when-automatic-detection-isnt-enough), only if you made one |
| `paths.conf` | Remembered install and Proton locations |
| `somnium-space.png` | Converted icon for the desktop entry |

## The patched Proton

```
~/Games/umu/GE-Proton11-5-somnilux/
```

A sibling of your install location, named for the Proton version with a
`-somnilux` suffix. A few gigabytes.

This is a private copy of GE-Proton with the patched Wine binaries installed
over it. It lives outside `compatibilitytools.d/` deliberately, so Steam never
sees it and never offers it for other games.

!!! warning "The suffix is the thing to check"
    Only directories ending `-somnilux` were created by this project. Your
    Steam Proton installs are under
    `~/.local/share/Steam/compatibilitytools.d/` and are never touched.

## The Wine prefix

```
~/Games/umu/umu-somnium/
```

Your chosen install location — a self-contained fake Windows drive holding
Somnium and nothing else. Size depends on Somnium.

| Path inside it | What it is |
| --- | --- |
| `drive_c/Program Files/Somnium Space/` | Somnium itself, as its own installer put it there |
| `drive_c/users/steamuser/AppData/Local/Temp/Somnium Space Ltd/logs/` | [Somnium's own logs](../troubleshooting/launch-log.md#somniums-own-logs) |

Those logs matter when the launcher starts but won't connect — Wine's side can
look clean while Somnium's own code records the real reason.

## The desktop entry

```
~/.local/share/applications/somnium-space.desktop
```

Runs `launch.sh` by absolute path, with `Terminal=true` so you get
[the launch window](../run/launch-window.md).

## Logs, at a glance

| Log | Where | When |
| --- | --- | --- |
| Launch | `~/.local/share/somnilux/launch.log` | Every launch, overwritten |
| Installer debug | `${XDG_RUNTIME_DIR:-/tmp}/somnilux-<uid>-debug.log` | Install and repair |
| Somnium's own | Inside the prefix, path above | Every run, with `-Prev` variants |

## Removing it

See [Uninstalling](../install/uninstalling.md), which walks these in the order
that keeps `paths.conf` readable until you're done with it.
