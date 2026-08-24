# VR runtimes and headsets

Somnilux works out which OpenXR runtime is active **every time you start the
game**, and makes it reachable from inside the container umu runs Somnium in.

!!! warning "Your headset must be connected to the PC before you launch"
    Starting your OpenXR runtime is **not enough**. The headset itself has to
    be connected and awake — plugged in, or linked wirelessly and actually
    paired through to the PC — *before* you start Somnium.

    Detection happens once, at the moment you start Somnium. A runtime running
    with no headset attached to it has nothing to report, so detection fails
    even though the runtime itself is working fine.

    **Order that works:** connect the headset → confirm the runtime sees it →
    launch Somnium.

    Got it the wrong way round? Nothing is broken. Close Somnium, connect the
    headset, and launch again.

Switching runtime needs no reinstall and no configuration. Bring your runtime
up the usual way and start Somnium again.

The detected runtime is printed in [the launch window](launch-window.md):

```
Detected OXR Runtime: SteamVR
```

## What works without any setup

Runtimes installed **under your home directory** — SteamVR, per-user Flatpaks,
Envision builds — need nothing extra.

System-wide **Flatpak** and **`/opt`** installs have their install directory
shared into the container automatically.

## Confirmed working

✅ confirmed · ⚠️ untested · ❌ known broken

| Runtime | Status | Headsets |
| --- | --- | --- |
| SteamVR | ✅ | Quest 3 |
| WiVRn | ✅ | Quest 3, Quest 3S |
| Monado | ⚠️ | — |

Untested doesn't mean broken — it means nobody has reported back yet. These
tables only grow from reports, so if you get Somnium running on something not
listed, please [say so](../troubleshooting/reporting.md). Good or bad, it all
helps.

## When automatic detection isn't enough

If your runtime needs something Somnilux doesn't work out on its own, create:

```
~/.local/share/somnilux/openxr.conf
```

with one `NAME=value` environment assignment per line:

```sh
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
PRESSURE_VESSEL_FILESYSTEMS_RW=/var/lib/flatpak/app/io.github.wivrn.wivrn
```

!!! warning "It replaces detection entirely"
    When that file exists, it **replaces** the automatic detection rather than
    adding to it. Include every variable you need, not just the extra one.

Delete the file to go back to automatic detection.

If you find you need one of these, please
[open an issue](https://github.com/Vulps22/somnilux/issues/new/choose) with
your runtime and the contents of your file. It usually means detection should
be handling your case on its own, and that's a fixable bug rather than
something you should have to carry locally.
