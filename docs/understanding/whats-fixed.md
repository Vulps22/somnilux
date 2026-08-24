# What's fixed and why

Somnium Space is a Windows application. Running it on Linux means running it
under Wine, and Wine had genuine bugs that this app happened to trigger.

**Everything Somnilux ships is a fix to Wine itself.** Somnium's own launcher,
client, and game service are never modified, patched, or redistributed — you
install those from Somnium's own installer, unchanged. If a fix had needed
changing Somnium's code rather than Wine's, it wouldn't have been made.

The patches are free software under Wine's own licence, and the full source is
in [`patches/`](https://github.com/Vulps22/somnilux/tree/main/patches). See
[Licensing](licensing.md).

## Connecting to Somnium

**The symptom:** the launcher starts, and then can't reach Somnium's servers.
No useful error — it simply doesn't connect.

**The cause:** Somnium uses mutual-TLS client certificate authentication, both
between the launcher and its game service and against Somnium's own backend.
Wine's implementation of Windows' TLS layer couldn't do it. Not "did it
badly" — several pieces of the mechanism were missing outright, and the
failure was silent at every one of them.

Four fixes, in `crypt32` and `secur32`:

- **Certificate names with unrecognized OIDs were rendered wrongly.** Windows
  prefixes an unknown identifier with `OID.`; Wine printed a bare number. That
  changed the certificate's computed hash, which quietly broke the connection.
- **A server asking for a client certificate was never asked for one.** Wine
  didn't request it, and didn't report the status that tells an application
  a certificate is needed — a status Wine had defined but never produced.
- **A handshake couldn't pause to fetch a certificate and resume.** Windows
  lets an application be interrupted mid-handshake, supply a certificate, and
  carry on. Wine's TLS library has no such pause, so it completed the
  handshake with an empty certificate instead. The fix bridges the two models.
- **An application couldn't find out which certificates a server would
  accept.** The query for that list was entirely unimplemented in Wine, so
  certificate selection came up empty every time.

The last one is the fix with the broadest value. Any .NET application doing
client-certificate authentication under Wine hits it, not just Somnium.

## Video playback

**The symptom:** in-world screens stayed blank, or the client froze hard
enough to look like a crash.

**The cause:** five separate faults, each hiding the next. Three are bugs in
stock GE-Proton that affect any media-playing application, not just Somnium.

- **Opening a video downloaded the entire file first.** The call that hands a
  URL to the media engine didn't return until the download finished, while
  holding a lock every other thread needed. The client froze for as long as it
  took — minutes, for one video.
- **Remote media was fetched in full before playing**, rather than streamed.
  185&nbsp;MB and several minutes for a single YouTube video.
- **AV1 video failed on every frame.** GE-Proton's ffmpeg is built without a
  software AV1 decoder, so it fell back to a hardware-only path that returned
  "not implemented" for everything. Somnilux ships an ffmpeg built with the
  decoder enabled.
- **RTSP streams weren't supported at all** — the format VRCDN uses to push
  live video to in-world screens.
- **YouTube videos played silently.** Somnium plays a single stream, and the
  tool it asks for one was returning a video-only URL.

### Why YouTube plays at 360p

Somnium asks for **one** stream and plays it. That means picture and sound
have to arrive together in the same stream, and 360p is the highest quality
YouTube still distributes that way — everything above it is video-only.

Given the choice between a sharp picture with no sound and a soft one with
music, sound won.

Raising it means recombining the video and audio streams locally before
Somnium ever sees them, which is a real piece of work rather than a
configuration change. It isn't built.

### Why audio over RTSP is still broken

RTSP video plays; the audio doesn't. It isn't a missing codec and it isn't a
missing track — the audio is present in the stream and decodes correctly
outside Somnium.

What's blocking it is diagnosis rather than difficulty. A useful trace needs a
**live** stream, because Somnium's server-side allowlist rejects local URLs,
so a self-hosted test server is no use. Progress waits on a live event to
debug against.

## What this means for trust

The patches are small, single-purpose, and readable. Each is one commit
against a public Wine source tree, and
[`patches/BASE_COMMIT.txt`](https://github.com/Vulps22/somnilux/blob/main/patches/BASE_COMMIT.txt)
records exactly which commit, so you can rebuild the binaries yourself and
compare — see [Building from source](../contributing/building.md).

The `crypt32` and `secur32` fixes are intended for submission upstream to
WineHQ, where they'd benefit every Wine user rather than living here.
