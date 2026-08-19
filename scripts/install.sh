#!/usr/bin/env bash
set -euo pipefail
trap 'stty sane 2>/dev/null || true; tput rmcup 2>/dev/null || true' EXIT

DEBUG_LOG="${XDG_RUNTIME_DIR:-/tmp}/somnilux-$(id -u)-debug.log"
if ! : > "$DEBUG_LOG" 2>/dev/null; then
    DEBUG_LOG=$(mktemp -t somnilux-debug.XXXXXX)
fi
DEBUG_N=0
dbg() {
    DEBUG_N=$((DEBUG_N + 1))
    printf '[%03d] %s pid=%s %s\n' "$DEBUG_N" "$(date +%H:%M:%S.%N)" "$$" "$1" >> "$DEBUG_LOG"
}

BACKTITLE="somnilux — github.com/Vulps22/somnilux"
CURL_TIMEOUT_OPTS=(--connect-timeout 10 --max-time 30)
CURL_TIMEOUT_OPTS_LARGE=(--connect-timeout 10 --max-time 600)
SUPPORTED_BASE_URL="https://raw.githubusercontent.com/Vulps22/somnilux/main/supported"
DEFAULT_PREFIX="$HOME/Games/umu/umu-somnium"
LAUNCHER_REL_PATH="drive_c/Program Files/Somnium Space/Somnium Space Launcher.exe"
ICON_REL_PATH="drive_c/Program Files/Somnium Space/SomniumEmblem.ico"
ICON_DEST_DIR="$HOME/.local/share/somnilux"
DLL_RELEASE_BASE_URL="https://github.com/Vulps22/somnilux/releases/download"
UMU_VERSION="1.4.4"
UMU_SHA256="eb590691841f7fad3fc3ad8fd5db4ccb87849fe7948e62b28ece7a4ee48cc851"
UMU_RELEASE_BASE_URL="https://github.com/Open-Wine-Components/umu-launcher/releases/download"
UMU_DEST="$HOME/.local/share/somnilux/umu"
UMU_RUN_BIN="$UMU_DEST/umu-run"
UMU_VERSION_STAMP="$UMU_DEST/version"

dbg "top-level: checking for whiptail"
HAVE_WHIPTAIL=0
if command -v whiptail >/dev/null 2>&1; then
    HAVE_WHIPTAIL=1
fi
dbg "top-level: HAVE_WHIPTAIL=$HAVE_WHIPTAIL"

# ui_menu outvar title prompt tag1 text1 [tag2 text2 ...]
# Writes the chosen tag into the caller's outvar. No subshell, no
# dependence on the caller's own stdout/pipe context.
ui_menu() {
    local -n __um_out="$1"
    shift
    local __um_title="$1" __um_prompt="$2"
    shift 2
    dbg "ui_menu: enter title=[$__um_title]"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        dbg "ui_menu: calling whiptail --menu"
        local __um_rc=0
        __um_out=$(whiptail --backtitle "$BACKTITLE" --title "$__um_title" --menu "$__um_prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3) || __um_rc=$?
        dbg "ui_menu: whiptail --menu returned rc=$__um_rc out=[$__um_out]"
        return "$__um_rc"
    fi

    echo "== $__um_title ==" >&2
    echo "$__um_prompt" >&2
    local __um_i=0 __um_tags=() __um_tag __um_text
    while [ $# -gt 0 ]; do
        __um_i=$((__um_i + 1))
        __um_tag="$1"
        __um_text="$2"
        __um_tags+=("$__um_tag")
        if [ -n "$__um_text" ]; then
            echo "  $__um_i) $__um_tag $__um_text" >&2
        else
            echo "  $__um_i) $__um_tag" >&2
        fi
        shift 2
    done
    local __um_choice
    while true; do
        read -r -p "Enter choice [1-$__um_i]: " __um_choice
        if [ "$__um_choice" -ge 1 ] 2>/dev/null && [ "$__um_choice" -le "$__um_i" ] 2>/dev/null; then
            __um_out="${__um_tags[$((__um_choice - 1))]}"
            dbg "ui_menu: fallback chose $__um_out"
            return
        fi
        echo "Invalid choice." >&2
    done
}

# ui_input outvar title prompt default
ui_input() {
    local -n __ui_out="$1"
    shift
    local __ui_title="$1" __ui_prompt="$2" __ui_default="${3:-}"
    dbg "ui_input: enter title=[$__ui_title]"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        dbg "ui_input: calling whiptail --inputbox"
        local __ui_rc=0
        __ui_out=$(whiptail --backtitle "$BACKTITLE" --title "$__ui_title" --inputbox "$__ui_prompt" 12 78 "$__ui_default" 3>&1 1>&2 2>&3) || __ui_rc=$?
        dbg "ui_input: whiptail --inputbox returned rc=$__ui_rc out=[$__ui_out]"
        return "$__ui_rc"
    fi

    echo "== $__ui_title ==" >&2
    [ -n "$__ui_default" ] && echo "(default: $__ui_default)" >&2
    local __ui_value
    read -r -e -i "$__ui_default" -p "$__ui_prompt: " __ui_value
    __ui_out="${__ui_value:-$__ui_default}"
    dbg "ui_input: fallback got value=[$__ui_out]"
}

# ui_msg title message [height] [width]
# No output value, so no nameref needed. Always succeeds: dismissing an
# informational box isn't a choice, and under set -e any non-zero return
# from here would abort the whole script.
ui_msg() {
    dbg "ui_msg: enter title=[$1]"
    local title="$1" message="$2" height="${3:-14}" width="${4:-78}"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        dbg "ui_msg: calling whiptail --msgbox height=$height width=$width message_len=${#message}"
        local rc=0
        whiptail --backtitle "$BACKTITLE" --title "$title" --msgbox "$message" "$height" "$width" 1>&2 || rc=$?
        dbg "ui_msg: whiptail --msgbox returned rc=$rc"
        return 0
    fi

    echo "== $title ==" >&2
    echo "$message" >&2
    read -r -p "Press Enter to continue..." _ || true
    return 0
}

MIN_PYTHON_VERSION="3.10"

# Checks for the tools we can't work without. whiptail is deliberately not
# included -- there's a plain-text fallback for it. python3 is needed by the
# vendored umu-run, so a missing or too-old one only shows up as a launcher
# that silently does nothing, long after this script has finished.
check_dependencies() {
    dbg "check_dependencies: enter"
    local missing=() cmd

    for cmd in curl tar python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        dbg "check_dependencies: missing=[${missing[*]}]"
        ui_msg "Missing dependencies" "This script needs the following, which aren't installed:

  ${missing[*]}

Install them with your distribution's package manager and run this again."
        exit 1
    fi

    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" 2>/dev/null; then
        local python_version
        python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null || echo "unknown")
        dbg "check_dependencies: python3 too old, got [$python_version]"
        ui_msg "Python too old" "umu-run needs Python $MIN_PYTHON_VERSION or newer, but python3 here is $python_version.

Somnium Space would install but the launcher would silently fail to start. Please update Python and run this again."
        exit 1
    fi
    dbg "check_dependencies: exit, all present"
}

# Sets SUPPORTED_PROTON_VERSIONS (array), DEFAULT_PROTON_VERSION, DEFAULT_WINE_VERSION.
fetch_supported_versions() {
    dbg "fetch_supported_versions: enter"
    local proton_txt default_txt

    dbg "fetch_supported_versions: curl proton.txt starting"
    if ! proton_txt=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$SUPPORTED_BASE_URL/proton.txt"); then
        dbg "fetch_supported_versions: curl proton.txt FAILED"
        ui_msg "Error" "Could not fetch the list of supported Proton versions from GitHub. Check your internet connection."
        exit 1
    fi
    dbg "fetch_supported_versions: curl proton.txt done, got [$proton_txt]"

    dbg "fetch_supported_versions: curl default.txt starting"
    if ! default_txt=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$SUPPORTED_BASE_URL/default.txt"); then
        dbg "fetch_supported_versions: curl default.txt FAILED"
        ui_msg "Error" "Could not fetch the default Proton/Wine version from GitHub. Check your internet connection."
        exit 1
    fi
    dbg "fetch_supported_versions: curl default.txt done, got [$default_txt]"

    mapfile -t SUPPORTED_PROTON_VERSIONS <<< "$proton_txt"
    DEFAULT_PROTON_VERSION=$(sed -n '1p' <<< "$default_txt")
    DEFAULT_WINE_VERSION=$(sed -n '2p' <<< "$default_txt")
    dbg "fetch_supported_versions: exit DEFAULT_PROTON_VERSION=$DEFAULT_PROTON_VERSION DEFAULT_WINE_VERSION=$DEFAULT_WINE_VERSION"
}

# pick_proton_version outvar
pick_proton_version() {
    local -n __pv_out="$1"
    dbg "pick_proton_version: enter"
    local __pv_menu_args=() __pv_version
    for __pv_version in "${SUPPORTED_PROTON_VERSIONS[@]}"; do
        if [ "$__pv_version" = "$DEFAULT_PROTON_VERSION" ]; then
            __pv_menu_args+=("$__pv_version" "(recommended)")
        else
            __pv_menu_args+=("$__pv_version" "")
        fi
    done

    local __pv_choice
    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        dbg "pick_proton_version: calling whiptail --menu"
        local __pv_rc=0
        __pv_choice=$(whiptail --backtitle "$BACKTITLE" --title "Choose a Proton version" \
            --default-item "$DEFAULT_PROTON_VERSION" \
            --menu "Recommended: $DEFAULT_PROTON_VERSION" 20 78 10 \
            "${__pv_menu_args[@]}" 3>&1 1>&2 2>&3) || __pv_rc=$?
        dbg "pick_proton_version: whiptail --menu returned rc=$__pv_rc choice=[$__pv_choice]"
    else
        ui_menu __pv_choice "Choose a Proton version" "Recommended: $DEFAULT_PROTON_VERSION" "${__pv_menu_args[@]}"
    fi

    if [ "$__pv_choice" != "$DEFAULT_PROTON_VERSION" ]; then
        dbg "pick_proton_version: non-default chosen, showing warning"
        ui_msg "Warning" "This version of Proton is untested and may break the launcher. $DEFAULT_PROTON_VERSION and Wine $DEFAULT_WINE_VERSION is recommended."
    fi

    dbg "pick_proton_version: exit choice=[$__pv_choice]"
    __pv_out="$__pv_choice"
}

# main_menu outvar
# Writes "install" or "repair" into outvar.
main_menu() {
    local -n __mm_out="$1"
    dbg "main_menu: enter"
    ui_menu __mm_out "somnilux" "Set up Somnium Space on Linux" \
        "install" "Install Somnium Space" \
        "repair" "Repair an existing install"
    dbg "main_menu: exit"
}

# 0 if the default prefix exists and has Somnium installed in it, 1 otherwise.
default_prefix_has_somnium() {
    dbg "default_prefix_has_somnium: checking $DEFAULT_PREFIX/$LAUNCHER_REL_PATH"
    [ -f "$DEFAULT_PREFIX/$LAUNCHER_REL_PATH" ]
}

# repair_flow outvar
# Writes the resolved prefix path into outvar.
repair_flow() {
    local -n __rf_out="$1"
    dbg "repair_flow: enter"

    if default_prefix_has_somnium; then
        dbg "repair_flow: found at default location"
        __rf_out="$DEFAULT_PREFIX"
        return
    fi

    dbg "repair_flow: not found at default, showing msg"
    ui_msg "Not found" "No Somnium install found at the default location ($DEFAULT_PREFIX)."

    local __rf_path
    while true; do
        dbg "repair_flow: asking for manual path"
        ui_input __rf_path "Existing prefix" "Enter the path to your existing Somnium prefix" ""
        expand_path __rf_path "$__rf_path"
        dbg "repair_flow: got path=[$__rf_path]"

        if [ -n "$__rf_path" ] && [ -f "$__rf_path/$LAUNCHER_REL_PATH" ]; then
            break
        fi

        dbg "repair_flow: path invalid, re-prompting"
        ui_msg "Not a Somnium prefix" "Couldn't find the Somnium Space Launcher inside:

  ${__rf_path:-(nothing entered)}

Expected it at <prefix>/$LAUNCHER_REL_PATH. Check the path and try again, or cancel to quit."
    done

    __rf_out="$__rf_path"
    dbg "repair_flow: exit prefix=[$__rf_out]"
}

# find_proton_dir_for_prefix outvar prefix_path
# Looks for a single *-somnilux sibling directory next to the prefix. If
# there isn't exactly one, asks the user which Proton version it is via
# the normal version picker. Writes the resolved Proton directory into
# outvar -- which may not exist yet, same as a fresh install; the caller
# (setup_proton_and_dlls) downloads it if needed.
find_proton_dir_for_prefix() {
    local -n __fp_out="$1"
    local __fp_prefix_path="$2"
    dbg "find_proton_dir_for_prefix: enter prefix_path=[$__fp_prefix_path]"
    local __fp_parent __fp_candidates=() __fp_version

    __fp_parent=$(dirname "$__fp_prefix_path")
    dbg "find_proton_dir_for_prefix: searching in parent=[$__fp_parent]"
    while IFS= read -r -d '' __fp_candidate; do
        __fp_candidates+=("$__fp_candidate")
    done < <(find "$__fp_parent" -maxdepth 1 -type d -name '*-somnilux' -print0 2>/dev/null)
    dbg "find_proton_dir_for_prefix: found ${#__fp_candidates[@]} candidate(s): ${__fp_candidates[*]:-none}"

    if [ "${#__fp_candidates[@]}" -eq 1 ]; then
        dbg "find_proton_dir_for_prefix: exit single candidate=[${__fp_candidates[0]}]"
        __fp_out="${__fp_candidates[0]}"
        return
    fi

    dbg "find_proton_dir_for_prefix: calling pick_proton_version"
    pick_proton_version __fp_version
    dbg "find_proton_dir_for_prefix: exit computed=[$__fp_parent/${__fp_version}-somnilux]"
    __fp_out="$__fp_parent/${__fp_version}-somnilux"
}

# expand_path outvar path
# Expands a leading ~ to $HOME into outvar.
expand_path() {
    local -n __ep_out="$1"
    __ep_out="${2/#\~/$HOME}"
}

# install_flow installer_path_var prefix_path_var proton_version_var proton_dir_var
install_flow() {
    local -n __if_installer="$1"
    local -n __if_prefix="$2"
    local -n __if_version="$3"
    local -n __if_dir="$4"
    dbg "install_flow: enter"

    ui_input __if_installer "Somnium installer" "Enter the path to the Somnium Space installer (.exe)" ""
    expand_path __if_installer "$__if_installer"
    dbg "install_flow: installer_path=[$__if_installer]"
    if [ ! -f "$__if_installer" ]; then
        dbg "install_flow: installer_path NOT FOUND, exiting"
        ui_msg "Error" "No file found at: $__if_installer"
        exit 1
    fi

    ui_input __if_prefix "Prefix location" "Where should Somnium be installed?" "$DEFAULT_PREFIX"
    expand_path __if_prefix "$__if_prefix"
    dbg "install_flow: prefix_path=[$__if_prefix]"

    dbg "install_flow: calling pick_proton_version"
    pick_proton_version __if_version
    dbg "install_flow: proton_version=[$__if_version]"

    __if_dir="$(dirname "$__if_prefix")/${__if_version}-somnilux"
    dbg "install_flow: exit proton_dir=[$__if_dir]"
}

# download_proton proton_version proton_dir
# Downloads, checksum-verifies, and extracts the given GE-Proton release
# into proton_dir. No-ops if proton_dir already exists.
download_proton() {
    dbg "download_proton: enter version=[$1] dest=[$2]"
    local version="$1" dest="$2"

    if [ -d "$dest" ]; then
        dbg "download_proton: dest already exists, skipping"
        echo "Proton already present at $dest, skipping download."
        return
    fi

    local base_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$version"
    local tarball="$version-x86_64.tar.gz"
    local sumfile="$version-x86_64.sha512sum"
    local workdir
    workdir=$(mktemp -d)
    dbg "download_proton: workdir=[$workdir]"

    echo "Downloading $tarball..."
    dbg "download_proton: curl tarball starting"
    if ! curl -fL --progress-bar "${CURL_TIMEOUT_OPTS_LARGE[@]}" -o "$workdir/$tarball" "$base_url/$tarball"; then
        dbg "download_proton: curl tarball FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Failed to download $tarball. Check your internet connection."
        exit 1
    fi
    dbg "download_proton: curl tarball done"

    echo "Downloading checksum..."
    dbg "download_proton: curl sumfile starting"
    if ! curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$workdir/$sumfile" "$base_url/$sumfile"; then
        dbg "download_proton: curl sumfile FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Failed to download the checksum file for $version."
        exit 1
    fi
    dbg "download_proton: curl sumfile done"

    echo "Verifying checksum..."
    dbg "download_proton: sha512sum -c starting"
    if ! (cd "$workdir" && sha512sum -c "$sumfile") >/dev/null; then
        dbg "download_proton: sha512sum -c FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Checksum verification failed for $tarball. The download may be corrupt."
        exit 1
    fi
    dbg "download_proton: sha512sum -c done"

    echo "Extracting..."
    mkdir -p "$(dirname "$dest")"
    dbg "download_proton: tar -xzf starting"
    if ! tar -xzf "$workdir/$tarball" -C "$workdir"; then
        dbg "download_proton: tar -xzf FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Failed to extract $tarball."
        exit 1
    fi
    dbg "download_proton: tar -xzf done"

    mv "$workdir/$version-x86_64" "$dest"
    rm -rf "$workdir"
    dbg "download_proton: exit, moved to dest"
}

# download_umu version
# Downloads and vendors our own private copy of umu-run (the umu-launcher
# zipapp release) into UMU_DEST, so launching never depends on a system
# package or PATH -- only python3, which is effectively universal. No-ops
# if the requested version is already vendored.
download_umu() {
    dbg "download_umu: enter version=[$1]"
    local version="$1"

    if [ -x "$UMU_RUN_BIN" ] && [ "$(cat "$UMU_VERSION_STAMP" 2>/dev/null)" = "$version" ]; then
        dbg "download_umu: version $version already vendored, skipping"
        echo "umu-run $version already present, skipping download."
        return
    fi
    dbg "download_umu: not vendored at version $version, (re)downloading"

    local url="$UMU_RELEASE_BASE_URL/$version/umu-launcher-$version-zipapp.tar"
    local workdir
    workdir=$(mktemp -d)
    dbg "download_umu: workdir=[$workdir] url=[$url]"

    echo "Downloading umu-run $version..."
    if ! curl -fL --progress-bar "${CURL_TIMEOUT_OPTS_LARGE[@]}" -o "$workdir/umu.tar" "$url"; then
        dbg "download_umu: curl FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Failed to download umu-run $version. Check your internet connection."
        exit 1
    fi
    dbg "download_umu: curl done"

    echo "Verifying checksum..."
    dbg "download_umu: sha256 verify starting"
    if ! printf '%s  %s\n' "$UMU_SHA256" "$workdir/umu.tar" | sha256sum -c - >/dev/null 2>&1; then
        dbg "download_umu: sha256 verify FAILED, got [$(sha256sum "$workdir/umu.tar" 2>/dev/null | cut -d' ' -f1)]"
        rm -rf "$workdir"
        ui_msg "Error" "Checksum verification failed for umu-run $version. The download may be corrupt."
        exit 1
    fi
    dbg "download_umu: sha256 verify OK"

    echo "Extracting..."
    if ! tar -xf "$workdir/umu.tar" -C "$workdir"; then
        dbg "download_umu: tar FAILED"
        rm -rf "$workdir"
        ui_msg "Error" "Failed to extract umu-run $version."
        exit 1
    fi
    dbg "download_umu: tar done"

    mkdir -p "$UMU_DEST"
    mv "$workdir/umu/umu-run" "$UMU_RUN_BIN"
    chmod +x "$UMU_RUN_BIN"
    printf '%s\n' "$version" > "$UMU_VERSION_STAMP"
    rm -rf "$workdir"
    dbg "download_umu: exit, vendored to $UMU_RUN_BIN"
}

# install_patched_dlls proton_dir
# Requires DEFAULT_WINE_VERSION to already be set (fetch_supported_versions).
install_patched_dlls() {
    dbg "install_patched_dlls: enter proton_dir=[$1]"
    local proton_dir="$1"
    local release_url="$DLL_RELEASE_BASE_URL/wine-$DEFAULT_WINE_VERSION"
    local dest_unix="$proton_dir/files/lib/wine/x86_64-unix"
    local dest_win="$proton_dir/files/lib/wine/x86_64-windows"
    local all_files=(secur32.so crypt32.so secur32.dll crypt32.dll rsaenh.dll)
    local workdir f dest_dir
    workdir=$(mktemp -d)

    echo "Installing patched DLLs (Wine $DEFAULT_WINE_VERSION build)..."

    for f in "${all_files[@]}"; do
        dbg "install_patched_dlls: downloading $f"
        if ! curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$workdir/$f" "$release_url/$f"; then
            dbg "install_patched_dlls: download of $f FAILED"
            rm -rf "$workdir"
            return 1
        fi
        if [ ! -s "$workdir/$f" ]; then
            dbg "install_patched_dlls: $f downloaded empty"
            rm -rf "$workdir"
            return 1
        fi
    done

    for f in "${all_files[@]}"; do
        case "$f" in
            *.so) dest_dir="$dest_unix" ;;
            *)    dest_dir="$dest_win" ;;
        esac
        if [ ! -f "$dest_dir/$f" ]; then
            dbg "install_patched_dlls: expected $dest_dir/$f is missing"
            rm -rf "$workdir"
            return 1
        fi
        if [ ! -f "$dest_dir/$f.orig" ] && ! cp -a "$dest_dir/$f" "$dest_dir/$f.orig"; then
            dbg "install_patched_dlls: backup of $f FAILED"
            rm -rf "$workdir"
            return 1
        fi
        chmod u+w "$dest_dir/$f"
        mv "$workdir/$f" "$dest_dir/$f"
        chmod 0644 "$dest_dir/$f"
        dbg "install_patched_dlls: installed $f"
    done

    rm -rf "$workdir"
    dbg "install_patched_dlls: exit success"
}

gauge_step() {
    dbg "gauge_step: pct=$1 text=[$2]"
    local pct="$1" text="$2"
    echo "XXX"
    echo "$pct"
    echo "$text"
    echo "XXX"
}

# download_with_progress url dest_file
# Emits raw 0-99 percentage lines to stdout as the download progresses,
# for feeding into a whiptail --gauge. Never reaches 100 itself, since the
# caller decides when the overall pipeline is actually done.
download_with_progress() {
    dbg "download_with_progress: enter url=[$1] dest=[$2]"
    local url="$1" dest="$2" total current pct curl_pid

    curl -fsL "${CURL_TIMEOUT_OPTS_LARGE[@]}" -o "$dest" "$url" &
    curl_pid=$!
    dbg "download_with_progress: backgrounded curl pid=$curl_pid"

    dbg "download_with_progress: HEAD request for content-length starting"
    total=$(curl -fsIL "${CURL_TIMEOUT_OPTS[@]}" "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1) == "content-length:" {v=$2} END {print v}')
    dbg "download_with_progress: HEAD request done, total=[$total]"

    local loop_n=0
    while kill -0 "$curl_pid" 2>/dev/null; do
        loop_n=$((loop_n + 1))
        if [ -f "$dest" ] && [ -n "${total:-}" ] && [ "$total" -gt 0 ] 2>/dev/null; then
            current=$(stat -c%s "$dest" 2>/dev/null || echo 0)
            pct=$(( current * 100 / total ))
            [ "$pct" -gt 99 ] && pct=99
            echo "$pct"
        fi
        if [ $((loop_n % 10)) -eq 0 ]; then
            dbg "download_with_progress: still polling, loop_n=$loop_n current=${current:-?} total=${total:-?}"
        fi
        sleep 0.3
    done
    dbg "download_with_progress: curl process gone after $loop_n polls, calling wait"
    wait "$curl_pid"
    dbg "download_with_progress: exit, wait rc=$?"
}

# run_gauged_pipeline proton_version proton_dir error_file
# whiptail-only: downloads/verifies/extracts Proton and installs the patched
# DLLs, showing progress in a single whiptail --gauge. On failure, writes a
# message to error_file and returns non-zero -- callers must not call
# whiptail from inside this pipeline, only after it's done.
run_gauged_pipeline() {
    dbg "run_gauged_pipeline: enter version=[$1] dest=[$2]"
    local version="$1" dest="$2" error_file="$3"

    dbg "run_gauged_pipeline: about to start piped block into whiptail --gauge"
    {
        dbg "run_gauged_pipeline(subshell): entered piped block, pid=\$\$=$$"
        if [ -d "$dest" ]; then
            dbg "run_gauged_pipeline(subshell): dest exists, skip download"
            gauge_step 60 "Proton already present, skipping download..."
        else
            dbg "run_gauged_pipeline(subshell): dest does not exist, downloading"
            gauge_step 5 "Downloading $version..."
            local base_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$version"
            local tarball="$version-x86_64.tar.gz"
            local sumfile="$version-x86_64.sha512sum"
            local workdir
            workdir=$(mktemp -d)
            dbg "run_gauged_pipeline(subshell): workdir=[$workdir], calling download_with_progress"

            download_with_progress "$base_url/$tarball" "$workdir/$tarball"
            dbg "run_gauged_pipeline(subshell): download_with_progress returned"
            if [ ! -s "$workdir/$tarball" ]; then
                dbg "run_gauged_pipeline(subshell): tarball missing/empty, FAILING"
                rm -rf "$workdir"
                echo "Failed to download $tarball. Check your internet connection." > "$error_file"
                exit 1
            fi

            gauge_step 40 "Verifying checksum..."
            dbg "run_gauged_pipeline(subshell): curl sumfile starting"
            if ! curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$workdir/$sumfile" "$base_url/$sumfile"; then
                dbg "run_gauged_pipeline(subshell): curl sumfile FAILED"
                rm -rf "$workdir"
                echo "Failed to download the checksum file for $version." > "$error_file"
                exit 1
            fi
            dbg "run_gauged_pipeline(subshell): curl sumfile done, verifying"
            if ! (cd "$workdir" && sha512sum -c "$sumfile") >/dev/null 2>&1; then
                dbg "run_gauged_pipeline(subshell): checksum verify FAILED"
                rm -rf "$workdir"
                echo "Checksum verification failed for $tarball. The download may be corrupt." > "$error_file"
                exit 1
            fi
            dbg "run_gauged_pipeline(subshell): checksum verify OK"

            gauge_step 55 "Extracting..."
            mkdir -p "$(dirname "$dest")"
            dbg "run_gauged_pipeline(subshell): tar -xzf starting"
            if ! tar -xzf "$workdir/$tarball" -C "$workdir"; then
                dbg "run_gauged_pipeline(subshell): tar -xzf FAILED"
                rm -rf "$workdir"
                echo "Failed to extract $tarball." > "$error_file"
                exit 1
            fi
            dbg "run_gauged_pipeline(subshell): tar -xzf done, moving into place"
            mv "$workdir/$version-x86_64" "$dest"
            rm -rf "$workdir"
            dbg "run_gauged_pipeline(subshell): move done"
        fi

        gauge_step 75 "Installing patched DLLs..."
        dbg "run_gauged_pipeline(subshell): calling install_patched_dlls"
        if ! install_patched_dlls "$dest" >/dev/null; then
            dbg "run_gauged_pipeline(subshell): install_patched_dlls FAILED"
            echo "Failed to install patched DLLs from the somnilux release." > "$error_file"
            exit 1
        fi
        dbg "run_gauged_pipeline(subshell): install_patched_dlls done"

        gauge_step 100 "Done."
        dbg "run_gauged_pipeline(subshell): reached end of piped block"
    } | whiptail --backtitle "$BACKTITLE" --title "Setting up Somnium Space" --gauge "Starting..." 10 78 0
    local pipe_status=("${PIPESTATUS[@]}")

    dbg "run_gauged_pipeline: whiptail --gauge pipeline returned, PIPESTATUS=${pipe_status[*]}"
    return "${pipe_status[0]}"
}

# setup_proton_and_dlls proton_version proton_dir
# Downloads/extracts Proton (if needed) and installs the patched DLLs,
# via the gauge pipeline when whiptail is available, plain functions
# otherwise. Shows an error and exits on failure either way.
setup_proton_and_dlls() {
    dbg "setup_proton_and_dlls: enter version=[$1] dest=[$2] HAVE_WHIPTAIL=$HAVE_WHIPTAIL"
    local version="$1" dest="$2"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        local error_file
        error_file=$(mktemp)
        dbg "setup_proton_and_dlls: calling run_gauged_pipeline, error_file=[$error_file]"
        if ! run_gauged_pipeline "$version" "$dest" "$error_file"; then
            dbg "setup_proton_and_dlls: run_gauged_pipeline FAILED, showing error"
            local error_text
            error_text=$(cat "$error_file")
            if [ -z "$error_text" ]; then
                error_text="Setting up Proton failed. See $DEBUG_LOG for details."
            fi
            ui_msg "Error" "$error_text"
            rm -f "$error_file"
            exit 1
        fi
        dbg "setup_proton_and_dlls: run_gauged_pipeline succeeded"
        rm -f "$error_file"
        return
    fi

    dbg "setup_proton_and_dlls: plain path, calling download_proton"
    download_proton "$version" "$dest"
    dbg "setup_proton_and_dlls: plain path, calling install_patched_dlls"
    if ! install_patched_dlls "$dest"; then
        dbg "setup_proton_and_dlls: plain path install_patched_dlls FAILED"
        ui_msg "Error" "Failed to install patched DLLs from the somnilux release."
        exit 1
    fi
    dbg "setup_proton_and_dlls: exit"
}

# run_in_prefix proton_dir prefix_path executable [args...]
run_in_prefix() {
    dbg "run_in_prefix: enter proton_dir=[$1] prefix_path=[$2]"
    local proton_dir="$1" prefix_path="$2" rc=0
    shift 2
    dbg "run_in_prefix: calling $UMU_RUN_BIN with args: $*"
    PROTONPATH="$proton_dir" WINEPREFIX="$prefix_path" GAMEID="umu-somnium" "$UMU_RUN_BIN" "$@" || rc=$?
    dbg "run_in_prefix: umu-run returned rc=$rc"
    return "$rc"
}

show_installer_tips() {
    dbg "show_installer_tips: enter"
    ui_msg "Continue in the Somnium Space Installer" "The Somnium Space Installer window is about to open. Please continue there.

A few tips:

- Once the installer has finished, a shortcut will be added to your applications menu (this works on GNOME, KDE Plasma, XFCE, and most other Linux desktops).

- In the Launcher's settings, turn off \"minimize to taskbar\". Wine has no system tray for it to minimize into, so the window can vanish entirely and need to be killed manually to close.

- Windows-style notifications will not work under Wine." 20 78
    dbg "show_installer_tips: exit"
}

# create_prefix_and_run_installer installer_path prefix_path proton_dir
create_prefix_and_run_installer() {
    dbg "create_prefix_and_run_installer: enter"
    local installer_path="$1" prefix_path="$2" proton_dir="$3"

    mkdir -p "$prefix_path"
    show_installer_tips
    echo "Creating the prefix and launching the Somnium installer..."
    run_in_prefix "$proton_dir" "$prefix_path" "$installer_path"
    dbg "create_prefix_and_run_installer: exit"
}

# create_desktop_entry prefix_path proton_dir
create_desktop_entry() {
    dbg "create_desktop_entry: enter"
    local prefix_path="$1" proton_dir="$2"
    local apps_dir="$HOME/.local/share/applications"
    local desktop_file="$apps_dir/somnium-space.desktop"
    local launcher_path="$prefix_path/$LAUNCHER_REL_PATH"
    local source_icon="$prefix_path/$ICON_REL_PATH"
    local icon_line=""
    local launch_log="$HOME/.local/share/somnilux/launch.log"

    mkdir -p "$apps_dir"

    local convert_cmd=""
    if command -v magick >/dev/null 2>&1; then
        convert_cmd="magick"
    elif command -v convert >/dev/null 2>&1; then
        convert_cmd="convert"
    fi

    if [ -f "$source_icon" ] && [ -n "$convert_cmd" ]; then
        mkdir -p "$ICON_DEST_DIR"
        dbg "create_desktop_entry: converting icon $source_icon with $convert_cmd"
        if "$convert_cmd" "$source_icon[0]" "$ICON_DEST_DIR/somnium-space.png" 2>>"$DEBUG_LOG"; then
            icon_line="Icon=$ICON_DEST_DIR/somnium-space.png"
            dbg "create_desktop_entry: icon converted OK"
        else
            dbg "create_desktop_entry: icon conversion FAILED, continuing without one"
        fi
    else
        dbg "create_desktop_entry: no source icon or no ImageMagick, continuing without one"
    fi

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Somnium Space
Comment=Somnium Space VR, via somnilux
Exec=sh -c 'mkdir -p "\$(dirname "\$1")" && env PROTONPATH="\$2" WINEPREFIX="\$3" GAMEID=umu-somnium "\$4" "\$5" >"\$1" 2>&1' sh "$launch_log" "$proton_dir" "$prefix_path" "$UMU_RUN_BIN" "$launcher_path"
Terminal=false
Categories=Game;
$icon_line
EOF

    chmod +x "$desktop_file"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    fi

    echo "Created desktop entry: $desktop_file"
    dbg "create_desktop_entry: exit"
}

main() {
    dbg "main: enter"
    local mode
    check_dependencies
    main_menu mode
    dbg "main: mode=[$mode]"

    case "$mode" in
        install)
            dbg "main: install branch start"
            local installer_path prefix_path proton_version proton_dir
            fetch_supported_versions
            dbg "main: calling install_flow"
            install_flow installer_path prefix_path proton_version proton_dir
            dbg "main: install_flow returned installer_path=[$installer_path] prefix_path=[$prefix_path] proton_version=[$proton_version] proton_dir=[$proton_dir]"

            dbg "main: calling download_umu"
            download_umu "$UMU_VERSION"
            dbg "main: calling setup_proton_and_dlls"
            setup_proton_and_dlls "$proton_version" "$proton_dir"
            dbg "main: calling create_prefix_and_run_installer"
            create_prefix_and_run_installer "$installer_path" "$prefix_path" "$proton_dir"
            dbg "main: calling create_desktop_entry"
            create_desktop_entry "$prefix_path" "$proton_dir"

            ui_msg "Done" "Somnium Space is installed. Look for it in your application menu, or run it again via the desktop entry. If launching from the menu doesn't seem to do anything, check ~/.local/share/somnilux/launch.log for what happened."
            dbg "main: install branch done"
            ;;
        repair)
            dbg "main: repair branch start"
            local prefix proton_dir proton_version
            repair_flow prefix
            dbg "main: repair_flow returned prefix=[$prefix]"
            fetch_supported_versions
            dbg "main: calling find_proton_dir_for_prefix"
            find_proton_dir_for_prefix proton_dir "$prefix"
            dbg "main: find_proton_dir_for_prefix returned proton_dir=[$proton_dir]"
            proton_version="${proton_dir##*/}"
            proton_version="${proton_version%-somnilux}"
            dbg "main: derived proton_version=[$proton_version]"

            dbg "main: calling download_umu"
            download_umu "$UMU_VERSION"
            dbg "main: calling setup_proton_and_dlls"
            setup_proton_and_dlls "$proton_version" "$proton_dir"
            dbg "main: calling create_desktop_entry"
            create_desktop_entry "$prefix" "$proton_dir"

            ui_msg "Done" "Repair complete. Patches re-applied and the desktop entry refreshed. If launching from the menu doesn't seem to do anything, check ~/.local/share/somnilux/launch.log for what happened."
            dbg "main: repair branch done"
            ;;
        *)
            dbg "main: unexpected mode=[$mode], aborting"
            ui_msg "Error" "Unexpected choice: '$mode'. Nothing has been changed."
            exit 1
            ;;
    esac
    dbg "main: exit"
}

dbg "top-level: about to call main"
main
dbg "top-level: main returned, script ending normally"
