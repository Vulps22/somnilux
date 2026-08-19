#!/usr/bin/env bash
set -euo pipefail
trap 'stty sane 2>/dev/null || true; tput rmcup 2>/dev/null || true' EXIT

DEBUG_LOG="/tmp/somnilux-debug.log"
: > "$DEBUG_LOG"
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
DLL_RELEASE_BASE_URL="https://github.com/Vulps22/somnilux/releases/download"

dbg "top-level: checking for whiptail"
HAVE_WHIPTAIL=0
if command -v whiptail >/dev/null 2>&1; then
    HAVE_WHIPTAIL=1
fi
dbg "top-level: HAVE_WHIPTAIL=$HAVE_WHIPTAIL"

# ui_menu title prompt tag1 text1 [tag2 text2 ...]
# Echoes the chosen tag to stdout.
ui_menu() {
    dbg "ui_menu: enter title=[$1]"
    local title="$1" prompt="$2"
    shift 2

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        dbg "ui_menu: calling whiptail --menu"
        local rc=0 out
        out=$(whiptail --backtitle "$BACKTITLE" --title "$title" --menu "$prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3) || rc=$?
        dbg "ui_menu: whiptail --menu returned rc=$rc out=[$out]"
        echo "$out"
        return "$rc"
    fi

    echo "== $title ==" >&2
    echo "$prompt" >&2
    local i=0 tags=() tag text
    while [ $# -gt 0 ]; do
        i=$((i + 1))
        tag="$1"
        text="$2"
        tags+=("$tag")
        if [ -n "$text" ]; then
            echo "  $i) $tag $text" >&2
        else
            echo "  $i) $tag" >&2
        fi
        shift 2
    done
    local choice
    while true; do
        read -r -p "Enter choice [1-$i]: " choice
        if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$i" ] 2>/dev/null; then
            echo "${tags[$((choice - 1))]}"
            dbg "ui_menu: fallback chose ${tags[$((choice - 1))]}"
            return
        fi
        echo "Invalid choice." >&2
    done
}

# ui_input title prompt default
# Echoes the entered value to stdout.
ui_input() {
    dbg "ui_input: enter title=[$1]"
    local title="$1" prompt="$2" default="${3:-}"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        dbg "ui_input: calling whiptail --inputbox"
        local rc=0 out
        out=$(whiptail --backtitle "$BACKTITLE" --title "$title" --inputbox "$prompt" 12 78 "$default" 3>&1 1>&2 2>&3) || rc=$?
        dbg "ui_input: whiptail --inputbox returned rc=$rc out=[$out]"
        echo "$out"
        return "$rc"
    fi

    echo "== $title ==" >&2
    [ -n "$default" ] && echo "(default: $default)" >&2
    local value
    read -r -e -i "$default" -p "$prompt: " value
    dbg "ui_input: fallback got value=[${value:-$default}]"
    echo "${value:-$default}"
}

# ui_yesno title prompt
# Returns 0 for yes, 1 for no.
ui_yesno() {
    dbg "ui_yesno: enter title=[$1]"
    local title="$1" prompt="$2"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        local rc=0
        whiptail --backtitle "$BACKTITLE" --title "$title" --yesno "$prompt" 12 78 || rc=$?
        dbg "ui_yesno: whiptail --yesno returned rc=$rc"
        return "$rc"
    fi

    echo "== $title ==" >&2
    local value
    read -r -p "$prompt [y/N]: " value
    case "$value" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# ui_msg title message [height] [width]
ui_msg() {
    dbg "ui_msg: enter title=[$1]"
    local title="$1" message="$2" height="${3:-14}" width="${4:-78}"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        dbg "ui_msg: calling whiptail --msgbox height=$height width=$width message_len=${#message}"
        local rc=0
        whiptail --backtitle "$BACKTITLE" --title "$title" --msgbox "$message" "$height" "$width" || rc=$?
        dbg "ui_msg: whiptail --msgbox returned rc=$rc"
        return "$rc"
    fi

    echo "== $title ==" >&2
    echo "$message" >&2
    read -r -p "Press Enter to continue..." _
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

# Echoes the chosen Proton version to stdout.
pick_proton_version() {
    dbg "pick_proton_version: enter"
    local menu_args=() version
    for version in "${SUPPORTED_PROTON_VERSIONS[@]}"; do
        if [ "$version" = "$DEFAULT_PROTON_VERSION" ]; then
            menu_args+=("$version" "(recommended)")
        else
            menu_args+=("$version" "")
        fi
    done

    local choice
    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        dbg "pick_proton_version: calling whiptail --menu"
        local rc=0
        choice=$(whiptail --backtitle "$BACKTITLE" --title "Choose a Proton version" \
            --default-item "$DEFAULT_PROTON_VERSION" \
            --menu "Recommended: $DEFAULT_PROTON_VERSION" 20 78 10 \
            "${menu_args[@]}" 3>&1 1>&2 2>&3) || rc=$?
        dbg "pick_proton_version: whiptail --menu returned rc=$rc choice=[$choice]"
    else
        choice=$(ui_menu "Choose a Proton version" "Recommended: $DEFAULT_PROTON_VERSION" "${menu_args[@]}")
    fi

    if [ "$choice" != "$DEFAULT_PROTON_VERSION" ]; then
        dbg "pick_proton_version: non-default chosen, showing warning"
        ui_msg "Warning" "This version of Proton is untested and may break the launcher. $DEFAULT_PROTON_VERSION and Wine $DEFAULT_WINE_VERSION is recommended."
    fi

    dbg "pick_proton_version: exit choice=[$choice]"
    echo "$choice"
}

# Echoes "install" or "repair" to stdout.
main_menu() {
    dbg "main_menu: enter"
    ui_menu "somnilux" "Set up Somnium Space on Linux" \
        "install" "Install Somnium Space" \
        "repair" "Repair an existing install"
    dbg "main_menu: exit"
}

# 0 if the default prefix exists and has Somnium installed in it, 1 otherwise.
default_prefix_has_somnium() {
    dbg "default_prefix_has_somnium: checking $DEFAULT_PREFIX/$LAUNCHER_REL_PATH"
    [ -f "$DEFAULT_PREFIX/$LAUNCHER_REL_PATH" ]
}

# Echoes the resolved prefix path to stdout.
repair_flow() {
    dbg "repair_flow: enter"
    local prefix

    if default_prefix_has_somnium; then
        dbg "repair_flow: found at default location"
        echo "$DEFAULT_PREFIX"
        return
    fi

    dbg "repair_flow: not found at default, showing msg"
    ui_msg "Not found" "No Somnium install found at the default location ($DEFAULT_PREFIX)."
    dbg "repair_flow: asking for manual path"
    prefix=$(ui_input "Existing prefix" "Enter the path to your existing Somnium prefix" "")
    dbg "repair_flow: exit prefix=[$prefix]"
    echo "$prefix"
}

# find_proton_dir_for_prefix prefix_path
# Looks for a single *-somnilux sibling directory next to the prefix. If
# there isn't exactly one, asks the user which Proton version it is via
# the normal version picker. Echoes the resolved Proton directory -- which
# may not exist yet, same as a fresh install; the caller (setup_proton_and_dlls)
# downloads it if needed.
find_proton_dir_for_prefix() {
    dbg "find_proton_dir_for_prefix: enter prefix_path=[$1]"
    local prefix_path="$1"
    local parent candidates=() proton_version

    parent=$(dirname "$prefix_path")
    dbg "find_proton_dir_for_prefix: searching in parent=[$parent]"
    while IFS= read -r -d '' candidate; do
        candidates+=("$candidate")
    done < <(find "$parent" -maxdepth 1 -type d -name '*-somnilux' -print0 2>/dev/null)
    dbg "find_proton_dir_for_prefix: found ${#candidates[@]} candidate(s): ${candidates[*]:-none}"

    if [ "${#candidates[@]}" -eq 1 ]; then
        dbg "find_proton_dir_for_prefix: exit single candidate=[${candidates[0]}]"
        echo "${candidates[0]}"
        return
    fi

    dbg "find_proton_dir_for_prefix: calling pick_proton_version"
    proton_version=$(pick_proton_version)
    dbg "find_proton_dir_for_prefix: exit computed=[$parent/${proton_version}-somnilux]"
    echo "$parent/${proton_version}-somnilux"
}

# Expands a leading ~ to $HOME. Echoes the result to stdout.
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# Echoes "installer_path|prefix_path|proton_version|proton_dir" to stdout.
install_flow() {
    dbg "install_flow: enter"
    local installer_path prefix_path proton_version proton_dir

    installer_path=$(ui_input "Somnium installer" "Enter the path to the Somnium Space installer (.exe)" "")
    installer_path=$(expand_path "$installer_path")
    dbg "install_flow: installer_path=[$installer_path]"
    if [ ! -f "$installer_path" ]; then
        dbg "install_flow: installer_path NOT FOUND, exiting"
        ui_msg "Error" "No file found at: $installer_path"
        exit 1
    fi

    prefix_path=$(ui_input "Prefix location" "Where should Somnium be installed?" "$DEFAULT_PREFIX")
    prefix_path=$(expand_path "$prefix_path")
    dbg "install_flow: prefix_path=[$prefix_path]"

    dbg "install_flow: calling pick_proton_version"
    proton_version=$(pick_proton_version)
    dbg "install_flow: proton_version=[$proton_version]"

    proton_dir="$(dirname "$prefix_path")/${proton_version}-somnilux"
    dbg "install_flow: exit proton_dir=[$proton_dir]"

    echo "$installer_path|$prefix_path|$proton_version|$proton_dir"
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

# install_patched_dlls proton_dir
# Requires DEFAULT_WINE_VERSION to already be set (fetch_supported_versions).
install_patched_dlls() {
    dbg "install_patched_dlls: enter proton_dir=[$1]"
    local proton_dir="$1"
    local release_url="$DLL_RELEASE_BASE_URL/wine-$DEFAULT_WINE_VERSION"
    local dest_unix="$proton_dir/files/lib/wine/x86_64-unix"
    local dest_win="$proton_dir/files/lib/wine/x86_64-windows"
    local f

    echo "Installing patched DLLs (Wine $DEFAULT_WINE_VERSION build)..."

    for f in secur32.so crypt32.so; do
        dbg "install_patched_dlls: unix file $f starting"
        [ -f "$dest_unix/$f.orig" ] || cp -a "$dest_unix/$f" "$dest_unix/$f.orig"
        chmod u+w "$dest_unix/$f"
        curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$dest_unix/$f" "$release_url/$f" || { dbg "install_patched_dlls: $f FAILED"; return 1; }
        dbg "install_patched_dlls: unix file $f done"
    done

    for f in secur32.dll crypt32.dll rsaenh.dll; do
        dbg "install_patched_dlls: windows file $f starting"
        [ -f "$dest_win/$f.orig" ] || cp -a "$dest_win/$f" "$dest_win/$f.orig"
        chmod u+w "$dest_win/$f"
        curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$dest_win/$f" "$release_url/$f" || { dbg "install_patched_dlls: $f FAILED"; return 1; }
        dbg "install_patched_dlls: windows file $f done"
    done
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

    dbg "run_gauged_pipeline: whiptail --gauge pipeline returned, PIPESTATUS=${PIPESTATUS[*]}"
    return "${PIPESTATUS[0]}"
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
            ui_msg "Error" "$(cat "$error_file")"
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

# run_in_prefix proton_dir prefix_path -- executable [args...]
run_in_prefix() {
    dbg "run_in_prefix: enter proton_dir=[$1] prefix_path=[$2]"
    local proton_dir="$1" prefix_path="$2"
    shift 2
    dbg "run_in_prefix: calling umu-run with args: $*"
    PROTONPATH="$proton_dir" WINEPREFIX="$prefix_path" GAMEID="umu-somnium" umu-run "$@"
    dbg "run_in_prefix: umu-run returned rc=$?"
}

show_installer_tips() {
    dbg "show_installer_tips: enter"
    ui_msg "Continue in the Somnium Space Installer" "The Somnium Space Installer window is about to open. Please continue there.

A few tips:

- A shortcut has already been added to your applications menu (this works on GNOME, KDE Plasma, XFCE, and most other Linux desktops).

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

    mkdir -p "$apps_dir"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Somnium Space
Comment=Somnium Space VR, via somnilux
Exec=env PROTONPATH="$proton_dir" WINEPREFIX="$prefix_path" GAMEID=umu-somnium umu-run "$launcher_path"
Terminal=false
Categories=Game;
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
    mode=$(main_menu)
    dbg "main: mode=[$mode]"

    case "$mode" in
        install)
            dbg "main: install branch start"
            local result installer_path prefix_path proton_version proton_dir
            fetch_supported_versions
            dbg "main: calling install_flow"
            result=$(install_flow)
            dbg "main: install_flow returned result=[$result]"
            IFS='|' read -r installer_path prefix_path proton_version proton_dir <<< "$result"

            dbg "main: calling setup_proton_and_dlls"
            setup_proton_and_dlls "$proton_version" "$proton_dir"
            dbg "main: calling create_prefix_and_run_installer"
            create_prefix_and_run_installer "$installer_path" "$prefix_path" "$proton_dir"
            dbg "main: calling create_desktop_entry"
            create_desktop_entry "$prefix_path" "$proton_dir"

            ui_msg "Done" "Somnium Space is installed. Look for it in your application menu, or run it again via the desktop entry."
            dbg "main: install branch done"
            ;;
        repair)
            dbg "main: repair branch start"
            local prefix proton_dir proton_version
            prefix=$(repair_flow)
            dbg "main: repair_flow returned prefix=[$prefix]"
            fetch_supported_versions
            dbg "main: calling find_proton_dir_for_prefix"
            proton_dir=$(find_proton_dir_for_prefix "$prefix")
            dbg "main: find_proton_dir_for_prefix returned proton_dir=[$proton_dir]"
            proton_version="${proton_dir##*/}"
            proton_version="${proton_version%-somnilux}"
            dbg "main: derived proton_version=[$proton_version]"

            dbg "main: calling setup_proton_and_dlls"
            setup_proton_and_dlls "$proton_version" "$proton_dir"
            dbg "main: calling create_desktop_entry"
            create_desktop_entry "$prefix" "$proton_dir"

            ui_msg "Done" "Repair complete. Patches re-applied and the desktop entry refreshed."
            dbg "main: repair branch done"
            ;;
    esac
    dbg "main: exit"
}

dbg "top-level: about to call main"
main
dbg "top-level: main returned, script ending normally"
