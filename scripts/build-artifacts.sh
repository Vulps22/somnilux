#!/usr/bin/env bash
set -euo pipefail

# Builds every binary Somnilux ships: the patched Wine DLLs and the ffmpeg
# libraries GE-Proton is missing an AV1 decoder in. Developer tool -- it is
# tracked in git but never packaged into a release.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="${SOMNILUX_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

WINE_SOURCE_DIR="${WINE_SOURCE_DIR:-$PROJECT_ROOT/wine-source}"
WINE_GE_DIR="${WINE_GE_DIR:-$PROJECT_ROOT/wine-ge}"
FFMPEG_DIR="${FFMPEG_DIR:-$PROJECT_ROOT/ffmpeg-build}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/build-artifacts}"
ARCHIVE="${ARCHIVE:-$PROJECT_ROOT/somnilux-binaries.tar.gz}"
REFERENCE_PROTON="${REFERENCE_PROTON:-/mnt/games/GE-Proton11-5-somnilux}"

FFMPEG_VERSION="8.1"
FFMPEG_TARBALL="ffmpeg-$FFMPEG_VERSION.tar.xz"
FFMPEG_URL="https://ffmpeg.org/releases/$FFMPEG_TARBALL"

UPSTREAM_DLLS=(secur32 crypt32 rsaenh)
GE_DLLS=(winedmo kernelbase)
FFMPEG_LIBS=(avcodec avformat avutil swscale swresample)

JOBS="${JOBS:-$(nproc)}"
FAILED=0

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
warn() { printf '   \033[33mWARNING\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31mFATAL\033[0m %s\n' "$*" >&2; exit 1; }

# require_tools tool...
require_tools() {
    local missing=() t
    for t in "$@"; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    [ "${#missing[@]}" -eq 0 ] || die "missing required tools: ${missing[*]}"
}

# require_pkgconfig module...
require_pkgconfig() {
    local missing=() m
    for m in "$@"; do
        pkg-config --exists "$m" 2>/dev/null || missing+=("$m")
    done
    [ "${#missing[@]}" -eq 0 ] || die "missing development packages: ${missing[*]}
On Fedora/Nobara: sudo dnf install libdav1d-devel gnutls-devel xz-devel bzip2-devel"
}

preflight() {
    say "Preflight"
    require_tools gcc make autoconf pkg-config curl tar nasm python3 readelf \
                  x86_64-w64-mingw32-gcc
    require_pkgconfig dav1d gnutls liblzma bzip2
    [ -d "$WINE_SOURCE_DIR" ] || die "wine-source not found at $WINE_SOURCE_DIR"
    [ -d "$WINE_GE_DIR" ]     || die "wine-ge not found at $WINE_GE_DIR"
    info "wine-source : $WINE_SOURCE_DIR ($(git -C "$WINE_SOURCE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'))"
    info "wine-ge     : $WINE_GE_DIR ($(git -C "$WINE_GE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'))"
    info "output      : $OUT_DIR"
    info "jobs        : $JOBS"
}

# generate_proton_sources tree
# Proton ships some of these out of sync with server/protocol.def and omits
# others entirely. make_requests and make_specfiles rewrite tracked files, so
# they must run every time -- an existence check never fires, and a stale
# server_protocol.h against a fresh ntsyscalls.h fails deep inside ntdll.
generate_proton_sources() {
    local tree="$1"
    [ -x "$tree/configure" ] || { info "autoreconf"; ( cd "$tree" && autoreconf -f >/dev/null 2>&1 ); }
    info "tools/make_requests"
    ( cd "$tree" && ./tools/make_requests >/dev/null ) || die "make_requests failed"
    info "tools/make_specfiles"
    ( cd "$tree" && ./tools/make_specfiles >/dev/null ) || die "make_specfiles failed"
    if [ ! -f "$tree/include/wine/vulkan.h" ]; then
        info "dlls/winevulkan/make_vulkan (chdirs internally, must run from its own directory)"
        ( cd "$tree/dlls/winevulkan" && python3 ./make_vulkan >/dev/null ) || die "make_vulkan failed"
    fi
}

# configure_wine tree
configure_wine() {
    local tree="$1"
    [ -f "$tree/build/Makefile" ] && return 0
    info "configure --enable-win64"
    mkdir -p "$tree/build"
    ( cd "$tree/build" && ../configure --enable-win64 >/dev/null ) \
        || die "configure failed in $tree"
}

# build_wine_dlls tree dll...
build_wine_dlls() {
    local tree="$1"; shift
    local d
    for d in "$@"; do
        info "make dlls/$d"
        make -j"$JOBS" -C "$tree/build/dlls/$d" >/dev/null \
            || die "build failed: $d in $tree"
    done
}

build_upstream_wine() {
    say "Wine (upstream) — ${UPSTREAM_DLLS[*]}"
    configure_wine "$WINE_SOURCE_DIR"
    build_wine_dlls "$WINE_SOURCE_DIR" "${UPSTREAM_DLLS[@]}"
}

build_ge_wine() {
    say "Wine (GE-Proton tree) — ${GE_DLLS[*]}"
    generate_proton_sources "$WINE_GE_DIR"
    configure_wine "$WINE_GE_DIR"
    build_wine_dlls "$WINE_GE_DIR" "${GE_DLLS[@]}"
}

# GE builds ffmpeg with --enable-decoders, which covers built-in decoders only.
# External-library decoders need their own flag, so their AV1 falls back to the
# hardware-only stub and returns ENOSYS on every frame.
build_ffmpeg() {
    say "ffmpeg $FFMPEG_VERSION (GE's configuration plus --enable-libdav1d)"
    local src="$FFMPEG_DIR/ffmpeg-$FFMPEG_VERSION" dst="$FFMPEG_DIR/dst"

    mkdir -p "$FFMPEG_DIR"
    if [ ! -d "$src" ]; then
        info "fetching $FFMPEG_TARBALL"
        curl -fL --progress-bar -o "$FFMPEG_DIR/$FFMPEG_TARBALL" "$FFMPEG_URL" \
            || die "failed to download ffmpeg"
        tar -xf "$FFMPEG_DIR/$FFMPEG_TARBALL" -C "$FFMPEG_DIR" || die "failed to extract ffmpeg"
    fi

    if [ ! -f "$src/ffbuild/config.mak" ]; then
        info "configure"
        ( cd "$src" && ./configure \
            --prefix="$dst" \
            --libdir="$dst/lib/x86_64-linux-gnu" \
            --arch=x86_64 --target-os=linux \
            --enable-shared --disable-static \
            --disable-everything --disable-programs --disable-doc --disable-inline-asm \
            --enable-lzma --enable-bzlib --enable-gnutls \
            --enable-demuxers --enable-protocol=https --enable-decoders --enable-encoders --enable-bsfs \
            --disable-decoder=vvc \
            --enable-libdav1d >/dev/null ) || die "ffmpeg configure failed"
    fi

    grep -q "^CONFIG_LIBDAV1D_DECODER=yes" "$src/ffbuild/config.mak" \
        || die "libdav1d decoder not enabled -- the AV1 fix would be silently absent"

    info "make (this is the slow one)"
    make -j"$JOBS" -C "$src" >/dev/null || die "ffmpeg build failed"
    make -C "$src" install >/dev/null || die "ffmpeg install failed"
}

# stage src dest
stage() {
    local src="$1" dest="$2"
    [ -f "$src" ] || die "expected build output missing: $src"
    install -Dm644 "$src" "$dest"
    info "$(printf '%10d  %s' "$(stat -c%s "$dest")" "${dest#$OUT_DIR/}")"
}

collect() {
    say "Staging artifacts"
    rm -rf "$OUT_DIR"

    local d
    for d in secur32 crypt32; do
        stage "$WINE_SOURCE_DIR/build/dlls/$d/$d.so" "$OUT_DIR/x86_64-unix/$d.so"
    done
    for d in "${UPSTREAM_DLLS[@]}"; do
        stage "$WINE_SOURCE_DIR/build/dlls/$d/x86_64-windows/$d.dll" "$OUT_DIR/x86_64-windows/$d.dll"
    done

    stage "$WINE_GE_DIR/build/dlls/winedmo/winedmo.so" "$OUT_DIR/x86_64-unix/winedmo.so"
    for d in "${GE_DLLS[@]}"; do
        stage "$WINE_GE_DIR/build/dlls/$d/x86_64-windows/$d.dll" "$OUT_DIR/x86_64-windows/$d.dll"
    done

    local f lib
    for f in "${FFMPEG_LIBS[@]}"; do
        lib=$(ls "$FFMPEG_DIR/dst/lib/x86_64-linux-gnu/lib$f.so."*.* 2>/dev/null | head -1)
        [ -n "$lib" ] || die "ffmpeg library missing: lib$f"
        stage "$lib" "$OUT_DIR/x86_64-linux-gnu/$(basename "$lib")"
    done
}

# A DLL whose DT_NEEDED sonames differ from the Proton binary it replaces will
# not load. Cheap to check here, miserable to debug in VR.
verify() {
    say "Verifying against $REFERENCE_PROTON"
    if [ ! -d "$REFERENCE_PROTON" ]; then
        warn "reference Proton not found, skipping soname verification"
        return 0
    fi

    local ours theirs a b name missing extra
    while IFS= read -r -d '' ours; do
        name=${ours#$OUT_DIR/}
        case "$name" in
            x86_64-unix/*)       theirs="$REFERENCE_PROTON/files/lib/wine/x86_64-unix/$(basename "$ours")" ;;
            x86_64-linux-gnu/*)  theirs="$REFERENCE_PROTON/files/lib/x86_64-linux-gnu/$(basename "$ours")" ;;
            *) continue ;;
        esac
        if [ ! -f "$theirs" ] && [ ! -f "$theirs.orig" ]; then
            warn "$name: no reference binary to compare against"
            continue
        fi
        [ -f "$theirs.orig" ] && theirs="$theirs.orig"
        a=$(readelf -d "$ours"   2>/dev/null | grep -oE 'lib[a-z0-9]+\.so\.[0-9]+' | sort -u)
        b=$(readelf -d "$theirs" 2>/dev/null | grep -oE 'lib[a-z0-9]+\.so\.[0-9]+' | sort -u)
        missing=$(comm -13 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | tr '\n' ' ')
        extra=$(comm -23 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | tr '\n' ' ')

        if [ -n "$missing" ]; then
            warn "$name: missing vs Proton: $missing"
            info "  Proton's build has this and ours does not. Install the matching"
            info "  -devel package, delete the ffmpeg ffbuild/config.mak so configure"
            info "  re-runs, and build again."
            FAILED=1
        fi
        [ -n "$extra" ] && info "$name: gained $extra"
        [ -z "$missing" ] && [ -z "$extra" ] && info "$name: sonames match"
    done < <(find "$OUT_DIR" -type f -name '*.so*' -print0)
}

package() {
    say "Packaging"
    rm -f "$ARCHIVE"
    tar -czf "$ARCHIVE" -C "$OUT_DIR" . || die "failed to create $ARCHIVE"
    info "$(printf '%10d  %s' "$(stat -c%s "$ARCHIVE")" "$ARCHIVE")"
    info "install with: install.sh --use-local-dlls-at $ARCHIVE"
}

main() {
    preflight
    build_upstream_wine
    build_ge_wine
    build_ffmpeg
    collect
    verify

    if [ "$FAILED" -eq 0 ]; then
        package
    fi

    if [ "$FAILED" -ne 0 ]; then
        say "Done with warnings"
        die "soname verification failed -- do not ship these binaries"
    fi
    say "Done"
    info "artifacts in $OUT_DIR"
}

main "$@"
