# Video playback

In-world screens play, with sound and ARS reactive lighting. Getting there
meant fixing five separate faults in Wine and GE-Proton, each of which was
hiding the next — see [What's fixed and why](../understanding/whats-fixed.md).

Some sources still don't work. This page is the honest current state.

## What plays today

✅ works · ❌ doesn't

| Source | Video | Audio | Notes |
| --- | --- | --- | --- |
| YouTube | ✅ | ✅ | 360p |
| RTSP / RTSPT | ✅ | ❌ | How VRCDN streams to in-world players |
| VRCDN over HTTPS | ❌ | ❌ | Doesn't load |
| Twitch | ❌ | ❌ | Doesn't load |

## Why YouTube is capped at 360p

Somnium asks `yt-dlp` for a **single** stream and plays whatever URL it prints
back. 360p is the best quality YouTube still serves with the audio already
inside that one stream — everything above it is video-only and would play
silently.

Sound seemed the better trade. Playing a rave with a crisp picture and no
music is worse than a soft picture with music.

Getting past this needs both streams played together, which means something
locally recombining them before Somnium sees them. That's a real piece of work
rather than a setting, and it isn't built.

## Audio over RTSP

RTSP video works; audio over it does not, and this is unfixed.

It isn't a missing codec and it isn't a missing track — the audio is there in
the stream and decodes fine elsewhere. Diagnosing it properly needs a trace
against a **live** stream, because Somnium's server-side allowlist rejects
local URLs, so a self-hosted test server is no help. That means waiting for a
live event to debug against.

## If video doesn't play at all

- **Check you're on the current fixes.** Video support arrived in Somnilux
  3.0. If you installed earlier, run the installer again and choose repair —
  see [Updating](../install/updating.md).
- **Check the source.** Against the table above, is it something that's
  expected to work?
- **Check [`launch.log`](../troubleshooting/launch-log.md).** A freeze that
  looks like a crash used to be the media engine deadlocking; if you see
  something like that on a current install, it's worth
  [reporting](../troubleshooting/reporting.md).

The first play of a YouTube link can take a while — Somnium's bundled
`yt-dlp.exe` is slow to start under Wine. Give it time before deciding it's
broken.

## AV1

AV1 video decodes correctly. GE-Proton's own ffmpeg build ships without a
software AV1 decoder, so every AV1 frame failed; Somnilux ships an ffmpeg
built with the decoder enabled. This affects any GE-Proton user playing AV1
content, not just Somnium.
