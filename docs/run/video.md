# Video playback

In-world screens play, with sound and ARS reactive lighting.

Not every source works yet. This is the current state.

## What plays today

✅ works · ❌ doesn't

| Source | Video | Audio | Notes |
| --- | --- | --- | --- |
| YouTube | ✅ | ✅ | 360p |
| RTSP / RTSPT | ✅ | ❌ | How VRCDN streams to in-world players |
| VRCDN over HTTPS | ❌ | ❌ | Doesn't load |
| Twitch | ❌ | ❌ | Doesn't load |

!!! note "YouTube plays at 360p"
    YouTube no longer distributes its higher qualities with the sound included
    in the same stream, and 360p is the best one that still is. Anything
    sharper would play silently. This isn't a setting you can change.

## Audio over RTSP

RTSP video plays without sound. This is a known limitation and it's being
worked on — see [Known issues](../troubleshooting/known-issues.md).

## If video doesn't play at all

- **Check you're on the current fixes.** Video support arrived in Somnilux
  3.0. If you installed before that, run the installer again and choose
  repair — see [Updating](../install/updating.md).
- **Check the source** against the table above.
- **Give it a moment.** The first video of a session can take a few minutes to
  start. That's expected, and it's not a sign anything is wrong.
- **Check [`launch.log`](../troubleshooting/launch-log.md)** if it still won't
  play, and [report it](../troubleshooting/reporting.md).

Why these limits exist, and what had to be fixed in Wine to get video working
at all, is covered in
[What's fixed and why](../understanding/whats-fixed.md).
