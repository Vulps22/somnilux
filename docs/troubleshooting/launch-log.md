# Reading launch.log

```
~/.local/share/somnilux/launch.log
```

Everything a launch does goes here — Somnilux's own steps, then umu, Proton
and the launcher. [The launch window](../run/launch-window.md) shows a summary;
this file has the detail.

!!! warning "It's overwritten every launch"
    Copy it before starting another session, or you'll lose the failing one.

## A healthy launch, annotated

This is a real, working launch. Yours will differ in paths and runtime, but
the shape should match.

```
[18:37:43] Starting Somnium Space Launcher
[18:37:43] update check: up to date
[18:37:43] prefix:  /mnt/games/somnium-space-vr
[18:37:43] proton:  /mnt/games/GE-Proton11-5-somnilux
[18:37:43] No existing session found for this prefix.
```

Somnilux's own preamble. `update check` is informational either way.
`prefix` and `proton` are worth a glance — if they point somewhere you don't
recognise, the launch script is stale and a repair will regenerate it.
`No existing session found` means nothing was left over; if something was,
you'd get the [restart prompt](../run/restarting.md) here instead.

```
[18:37:43] OpenXR: manifest /home/vulps/.config/openxr/1/active_runtime.json
[18:37:43] OpenXR: resolves to .../SteamVR/steamxr_linux64.json
[18:37:43] OpenXR: runtime library .../SteamVR/bin/linux64/vrclient.so
[18:37:43] OpenXR: no extra container paths needed for this runtime.
[18:37:44] Detected OXR Runtime: SteamVR
```

Runtime detection, step by step. This is the most useful block in the file
when VR isn't working: it shows the manifest it found, what that resolved to,
and whether extra paths had to be shared into the container. A runtime under
your home directory needs no extra paths, so that line is normal.

If this block ends in `none detected`, your runtime wasn't active when you
launched. See [VR runtimes](../run/vr-runtimes.md).

```
[18:37:44] Launching: env PROTONPATH=... WINEPREFIX=... umu-run ".../Somnium Space Launcher.exe"
[18:37:44] ===================================================================
```

The exact command. Everything after the `===` line comes from umu, Proton and
Somnium rather than from Somnilux.

```
INFO: umu-launcher version 1.4.4 (...)
INFO: steamrt4 is up to date
INFO: Running 'GE-Proton11-5-x86_64' using runtime 'steamrt4'
ProtonFixes[...] INFO: All checks successful
Proton: Executable is a unix path, launching with 'umu.exe'.
ntsync: up and running.
```

umu starting the container and Proton starting Wine. `ntsync: up and running`
is a good sign. The launch is working by this point.

## Expected lines

These look alarming and are not:

| Line | What it means |
| --- | --- |
| `WARN: Game title not found in CSV` | Somnium isn't in umu's game database. Expected — it's not a Steam game. |
| `No early stage global protonfix found` | No per-game workarounds needed. Expected. |
| `Proton: Error: unable to use parent for game drive, path ...` | Proton couldn't map a parent directory as a drive. Harmless; the launch continues. |
| `Executable is a unix path, launching with 'umu.exe'` | Normal for a non-Steam launch. |

They appear in every healthy launch, including the annotated one above.

## `fixme:` lines — please do report these

A `fixme:` line means Somnium called a Windows function that **Wine hasn't
implemented**, or has only stubbed out. Wine carries on regardless, which is
why a launch full of them can still work perfectly.

Don't let that make you dismiss them. **Every fix Somnilux ships started as
something Wine wasn't doing properly**, and an unimplemented function is the
most direct signal that a gap exists. A `fixme:` in the moments before
something breaks is often naming the cause outright.

So, the useful stance:

- **Don't chase them yourself.** Wine is chatty, plenty of stubs are genuinely
  harmless, and a `fixme:` is not proof it caused *your* problem.
- **Don't filter them out of a report.** Attach the log whole. Which ones
  matter is exactly the judgement that's easier to make with the full picture,
  and easier for me than for you.
- **If you can tie one to a broken feature, say so.** "These lines appeared the
  instant the screen went black" is a genuinely valuable report — that's the
  shape of how the video and certificate bugs were found.

`err:` lines are worth the same treatment. Some are routine; some name a real
failure.

## When it goes wrong

Look for where the log **stops**, not for the scariest-looking line. Wine's
output is verbose by design, and the last thing that happened is usually more
informative than the loudest thing that happened.

**The log ends right after `Starting Somnium Space Launcher`** — Somnilux
failed before reaching umu. Check the `prefix` and `proton` lines exist and
point at directories that are really there.

**It ends at or just after the `===` line** — umu or Proton failed to start.
Check `python3 --version` is 3.10+, and that the Proton directory wasn't
removed.

**It reaches `ntsync: up and running` and then stops** — Wine started and the
launcher itself is the problem. This is where
[Somnium's own logs](#somniums-own-logs) matter more than this file.

**`err:sync:RtlpWaitForCriticalSection ... 60 sec`** — something deadlocked.
If this happens while a video is playing on a current install, that's worth
[reporting](reporting.md).

## Somnium's own logs

Wine's side can look perfectly clean while Somnium's own code logs the real
reason. Inside your prefix:

```
<prefix>/drive_c/users/steamuser/AppData/Local/Temp/Somnium Space Ltd/logs/launcher_output_log.log
<prefix>/drive_c/users/steamuser/AppData/Local/Temp/Somnium Space Ltd/logs/game_service_output_log.log
```

There are `-Prev.log` variants of each holding the previous run. If the
launcher opens but won't connect or sign in, check these first — a
maintenance-mode notice or an auth error shows up here and nowhere else.

## The installer's log

Install-time problems go somewhere different:

```
${XDG_RUNTIME_DIR:-/tmp}/somnilux-<your uid>-debug.log
```

The installer prints this path when a step fails.

## What to attach to a report

`launch.log` in full. It's short — usually well under a hundred lines — so
attach the whole thing rather than the part you think is relevant.

It contains your home directory path and your install paths. If your username
is something you'd rather not publish, replace it throughout before posting;
nothing else in the file is sensitive.
