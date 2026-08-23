# The launch window

Starting Somnium Space opens a terminal window. That's deliberate — it tells
you what's happening, and means a launch that fails says so instead of doing
nothing at all.

```
Starting Somnium Space Launcher
Detected OXR Runtime: SteamVR
Launching: env PROTONPATH=... WINEPREFIX=... umu-run ".../Somnium Space Launcher.exe"
===================================================================

You can safely close this window.
```

## You can close it

Closing the window does **not** stop Somnium. The launcher and the game keep
running. Leave it open or close it, whichever you prefer.

## What the lines mean

**`Detected OXR Runtime:`** — which OpenXR runtime Somnilux found active and
made reachable from inside the container. If this says something unexpected,
or `none detected` when you expected a headset, that's your problem right
there.

The usual cause is launching before the headset was ready. Detection runs
once, at launch, so your headset must be connected and your runtime already
running **before** you start Somnium. Close it, bring the runtime up, and
launch again — see [VR runtimes and headsets](vr-runtimes.md).

**`Launching:`** — the exact command being run, with the Proton path, prefix,
and launcher executable. Useful in a bug report, and useful if you want to see
precisely what Somnilux does on your behalf.

You may also see an **update notice** before any of this, if a newer Somnilux
has been published. It waits ten seconds, or presses on immediately if you hit
++enter++. Nothing is downloaded — see [Updating](../install/updating.md).

If Somnium is already running, you'll be asked about
[restarting](restarting.md) first.

## Where the real output goes

The window is a summary. Everything else — the full launcher output, umu, and
Proton — goes to:

```
~/.local/share/somnilux/launch.log
```

That file is the single most useful thing to attach to a bug report. It's
overwritten on each launch, so grab it before starting another session.

See [Reading launch.log](../troubleshooting/launch-log.md) for what's in it,
and [Common failures](../troubleshooting/common-failures.md) if the window
appears and then nothing else happens.

!!! note "No window at all?"
    The desktop entry asks for a terminal. On a desktop with no terminal
    handler installed, nothing may appear — but Somnium still launches, and
    `launch.log` is still written. Anything needing an answer falls back to a
    graphical dialog.
