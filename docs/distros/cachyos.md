# CachyOS

**Status: working.** Confirmed with a PICO 4 Ultra over WiVRn on KDE Plasma
(Wayland), for a two-hour session with no problems.

Two things need doing by hand first. Neither is hard, but the first one is
easy to mistake for a successful install, so it's worth reading both before
you start.

Both are bugs in Somnilux rather than in CachyOS, and both are being fixed —
this page goes away once they are.

## The installer stops before creating the launcher

**What you see:** the install appears to finish. Somnium, GE-Proton, the
patched binaries and `umu-run` are all there. But there's nothing in your
applications menu, no `~/.local/share/somnilux/launch.sh`, and no error
message telling you anything went wrong.

**What happened:** Somnium's own installer — the Inno Setup window that opens
partway through — exits with code 254 in some cases, including if you untick
"run now" or close it on the last page. Somnilux treats that as a failure and
stops immediately, which is *after* installing everything but *before*
creating the launch script, the desktop entry and the remembered paths.

The [debug log](../troubleshooting/launch-log.md) shows it as:

```
run_in_prefix: umu-run returned rc=254
```

**The fix:** run `install.sh` again and choose the second menu entry —
**Configure an existing installation**. It finds the install, re-applies the
patches, and creates the three missing pieces. If it can't find it at the
default location it asks you for the path.

!!! note "Why it doesn't say \"Repair\""
    That entry reads *Repair an existing install* once Somnilux has a
    remembered install location. Writing that location down is one of the
    steps that got skipped, so on this run it reads *Configure an existing
    installation* instead. Same thing, and after it finishes you'll get the
    Repair wording from then on.

Tracked as [#21](https://github.com/Vulps22/somnilux/issues/21).

## The launcher vanishes as soon as VR is running

**What you see:** with no VR runtime running, everything works and Somnium
starts in desktop mode. With a WiVRn session live, the launcher disappears the
moment file verification finishes — no crash dialog, no message, the whole
thing is just gone.

`launch.log` ends with:

```
X Error of failed request:  BadMatch (invalid parameter attributes)
  Major opcode of failed request:  131 (XInputExtension)
  Minor opcode of failed request:  28 (X_GetDeviceButtonMapping)
```

**What happened:** the Launcher is a WPF application, and WPF loads
`wintab32` — Wine's graphics-tablet support — for its stylus handling. Under
XWayland that makes Wine enumerate XInput1 devices, which fails. A fatal Xlib
error kills the process outright, so nothing gets the chance to report it.

It only shows up in VR because starting the WiVRn session makes input devices
appear *while the launcher is running*, and that rescan is what sets it off.

**The fix:** turn `wintab32` off in the prefix.

!!! warning "Close Somnium completely first"
    Wine rewrites `user.reg` when the prefix shuts down. Edit it while
    anything is still running and your change is thrown away.

Open `user.reg` in your install location, find the section headed:

```
[Software\\Wine\\DllOverrides]
```

and add this line among the others already there:

```
"wintab32"="disabled"
```

It's the same form as the `"atiadlxx"="disabled"` line Proton writes there
itself. It costs you nothing unless you actually use a drawing tablet — WPF
falls back to mouse input when the DLL isn't available — and because it lives
in the prefix, it survives a repair run.

Tracked as [#22](https://github.com/Vulps22/somnilux/issues/22).

!!! note "Not really a CachyOS problem"
    This one is a Wayland problem, not a distribution one. Any WPF launcher
    under XWayland with a VR runtime that hotplugs input devices should hit
    it. It's on this page because that's where it was reported — if it
    catches you on something else, please
    [say so](../troubleshooting/reporting.md) so the note can move somewhere
    more useful.

## Verified on

| | |
| --- | --- |
| Distribution | CachyOS x86_64, kernel 7.2.0-1-cachyos |
| Desktop | KDE Plasma 6.7.4, KWin on Wayland |
| Hardware | Ryzen 5 5600X, RX 7900 XT (RADV), 32 GB RAM |
| Headset | PICO 4 Ultra over WiVRn 26.6.2, client in SteamVR mode |
| Somnilux | `install.sh` 3.1, GE-Proton11-5-somnilux, umu-launcher 1.4.4, binaries build-1 |
| Locale | `fr_FR.UTF-8` |

With thanks to the user who worked both of these out and wrote them up.
