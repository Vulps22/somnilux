# Known issues

Current as of Somnium Space **3.2.5**. Anything fixed drops off this list.

For the full picture on what Somnilux fixes rather than what it doesn't, see
[What's fixed and why](../understanding/whats-fixed.md).

## Client

**Viewing your desktop from inside Somnium Space can crash the client.**
Reported on some distributions, not all. No workaround beyond avoiding the
feature.

**The social app doesn't work in the launcher.**

**Windows-style notifications don't appear.** Wine has no equivalent to
deliver them to. Nothing is broken; they're simply absent.

**The launcher window can vanish** if "minimize to taskbar" is enabled in its
settings — Wine has no system tray to minimize into. Turn the setting off.
Recovering from it is covered under [Restarting](../run/restarting.md).

## Video playback

Partial, and improving in stages. The current support table lives on
[Video playback](../run/video.md).

**Audio over RTSP doesn't work.** Video plays; sound doesn't. Being worked
on, but it can only be diagnosed against a live stream, so progress waits on a
live event to test against.

**VRCDN over HTTPS doesn't load at all.** Same blocker.

**Twitch doesn't load.**

**YouTube plays at 360p.** YouTube no longer distributes its higher qualities
with the sound in the same stream, and 360p is the best one that still is.
Raising it isn't a setting — it needs work that hasn't been built.

**The first video of a session is slow to start**, sometimes by a few minutes.
Expected, and not currently worked around.

## Platform

**Python 3.10+ is required**, which rules out some older long-term-support
distributions. See [Distribution notes](distributions.md#python-version).

**Only SteamVR and WiVRn are confirmed.** Everything else is untested rather
than known-broken — see [VR runtimes](../run/vr-runtimes.md).

## Reporting something not listed

Please do — see [Reporting a problem](reporting.md). A confirmation that
something *works* on an untested distribution or runtime is just as useful as
a bug report.
