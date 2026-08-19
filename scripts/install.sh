#!/usr/bin/env bash
set -euo pipefail

BACKTITLE="somnilux — github.com/Vulps22/somnilux"
SUPPORTED_BASE_URL="https://raw.githubusercontent.com/Vulps22/somnilux/main/supported"
DEFAULT_PREFIX="$HOME/Games/umu/umu-somnium"
LAUNCHER_REL_PATH="drive_c/Program Files/Somnium Space/Somnium Space Launcher.exe"
DLL_RELEASE_BASE_URL="https://github.com/Vulps22/somnilux/releases/download"

HAVE_WHIPTAIL=0
if command -v whiptail >/dev/null 2>&1; then
    HAVE_WHIPTAIL=1
fi

# ui_menu title prompt tag1 text1 [tag2 text2 ...]
# Echoes the chosen tag to stdout.
ui_menu() {
    local title="$1" prompt="$2"
    shift 2

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        whiptail --backtitle "$BACKTITLE" --title "$title" --menu "$prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3
        return
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
            return
        fi
        echo "Invalid choice." >&2
    done
}

# ui_input title prompt default
# Echoes the entered value to stdout.
ui_input() {
    local title="$1" prompt="$2" default="${3:-}"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        whiptail --backtitle "$BACKTITLE" --title "$title" --inputbox "$prompt" 12 78 "$default" 3>&1 1>&2 2>&3
        return
    fi

    echo "== $title ==" >&2
    [ -n "$default" ] && echo "(default: $default)" >&2
    local value
    read -r -e -i "$default" -p "$prompt: " value
    echo "${value:-$default}"
}

# ui_yesno title prompt
# Returns 0 for yes, 1 for no.
ui_yesno() {
    local title="$1" prompt="$2"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        whiptail --backtitle "$BACKTITLE" --title "$title" --yesno "$prompt" 12 78
        return
    fi

    echo "== $title ==" >&2
    local value
    read -r -p "$prompt [y/N]: " value
    case "$value" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# ui_msg title message
ui_msg() {
    local title="$1" message="$2"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        whiptail --backtitle "$BACKTITLE" --title "$title" --msgbox "$message" 14 78
        return
    fi

    echo "== $title ==" >&2
    echo "$message" >&2
    read -r -p "Press Enter to continue..." _
}

# Sets SUPPORTED_PROTON_VERSIONS (array), DEFAULT_PROTON_VERSION, DEFAULT_WINE_VERSION.
fetch_supported_versions() {
    local proton_txt default_txt

    if ! proton_txt=$(curl -fsSL "$SUPPORTED_BASE_URL/proton.txt"); then
        ui_msg "Error" "Could not fetch the list of supported Proton versions from GitHub. Check your internet connection."
        exit 1
    fi
    if ! default_txt=$(curl -fsSL "$SUPPORTED_BASE_URL/default.txt"); then
        ui_msg "Error" "Could not fetch the default Proton/Wine version from GitHub. Check your internet connection."
        exit 1
    fi

    mapfile -t SUPPORTED_PROTON_VERSIONS <<< "$proton_txt"
    DEFAULT_PROTON_VERSION=$(sed -n '1p' <<< "$default_txt")
    DEFAULT_WINE_VERSION=$(sed -n '2p' <<< "$default_txt")
}

# Echoes the chosen Proton version to stdout.
pick_proton_version() {
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
        choice=$(whiptail --backtitle "$BACKTITLE" --title "Choose a Proton version" \
            --default-item "$DEFAULT_PROTON_VERSION" \
            --menu "Recommended: $DEFAULT_PROTON_VERSION" 20 78 10 \
            "${menu_args[@]}" 3>&1 1>&2 2>&3)
    else
        choice=$(ui_menu "Choose a Proton version" "Recommended: $DEFAULT_PROTON_VERSION" "${menu_args[@]}")
    fi

    if [ "$choice" != "$DEFAULT_PROTON_VERSION" ]; then
        ui_msg "Warning" "This version of Proton is untested and may break the launcher. $DEFAULT_PROTON_VERSION and Wine $DEFAULT_WINE_VERSION is recommended."
    fi

    echo "$choice"
}

# Echoes "install" or "repair" to stdout.
main_menu() {
    ui_menu "somnilux" "Set up Somnium Space on Linux" \
        "install" "Install Somnium Space" \
        "repair" "Repair an existing install"
}

# 0 if the default prefix exists and has Somnium installed in it, 1 otherwise.
default_prefix_has_somnium() {
    [ -f "$DEFAULT_PREFIX/$LAUNCHER_REL_PATH" ]
}

# Echoes the resolved prefix path to stdout.
repair_flow() {
    local prefix

    if default_prefix_has_somnium; then
        echo "$DEFAULT_PREFIX"
        return
    fi

    ui_msg "Not found" "No Somnium install found at the default location ($DEFAULT_PREFIX)."
    prefix=$(ui_input "Existing prefix" "Enter the path to your existing Somnium prefix" "")
    echo "$prefix"
}

# Expands a leading ~ to $HOME. Echoes the result to stdout.
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# Echoes "installer_path|prefix_path|proton_version|proton_dir" to stdout.
install_flow() {
    local installer_path prefix_path proton_version proton_dir

    installer_path=$(ui_input "Somnium installer" "Enter the path to the Somnium Space installer (.exe)" "")
    installer_path=$(expand_path "$installer_path")
    if [ ! -f "$installer_path" ]; then
        ui_msg "Error" "No file found at: $installer_path"
        exit 1
    fi

    prefix_path=$(ui_input "Prefix location" "Where should Somnium be installed?" "$DEFAULT_PREFIX")
    prefix_path=$(expand_path "$prefix_path")

    fetch_supported_versions
    proton_version=$(pick_proton_version)

    proton_dir="$(dirname "$prefix_path")/${proton_version}-somnilux"

    echo "$installer_path|$prefix_path|$proton_version|$proton_dir"
}

# download_proton proton_version proton_dir
# Downloads, checksum-verifies, and extracts the given GE-Proton release
# into proton_dir. No-ops if proton_dir already exists.
download_proton() {
    local version="$1" dest="$2"

    if [ -d "$dest" ]; then
        echo "Proton already present at $dest, skipping download."
        return
    fi

    local base_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$version"
    local tarball="$version-x86_64.tar.gz"
    local sumfile="$version-x86_64.sha512sum"
    local workdir
    workdir=$(mktemp -d)

    echo "Downloading $tarball..."
    if ! curl -fL --progress-bar -o "$workdir/$tarball" "$base_url/$tarball"; then
        rm -rf "$workdir"
        ui_msg "Error" "Failed to download $tarball. Check your internet connection."
        exit 1
    fi

    echo "Downloading checksum..."
    if ! curl -fsSL -o "$workdir/$sumfile" "$base_url/$sumfile"; then
        rm -rf "$workdir"
        ui_msg "Error" "Failed to download the checksum file for $version."
        exit 1
    fi

    echo "Verifying checksum..."
    if ! (cd "$workdir" && sha512sum -c "$sumfile") >/dev/null; then
        rm -rf "$workdir"
        ui_msg "Error" "Checksum verification failed for $tarball. The download may be corrupt."
        exit 1
    fi

    echo "Extracting..."
    mkdir -p "$(dirname "$dest")"
    if ! tar -xzf "$workdir/$tarball" -C "$workdir"; then
        rm -rf "$workdir"
        ui_msg "Error" "Failed to extract $tarball."
        exit 1
    fi

    mv "$workdir/$version-x86_64" "$dest"
    rm -rf "$workdir"
}

# install_patched_dlls proton_dir
# Requires DEFAULT_WINE_VERSION to already be set (fetch_supported_versions).
install_patched_dlls() {
    local proton_dir="$1"
    local release_url="$DLL_RELEASE_BASE_URL/wine-$DEFAULT_WINE_VERSION"
    local dest_unix="$proton_dir/files/lib/wine/x86_64-unix"
    local dest_win="$proton_dir/files/lib/wine/x86_64-windows"
    local f

    echo "Installing patched DLLs (Wine $DEFAULT_WINE_VERSION build)..."

    for f in secur32.so crypt32.so; do
        [ -f "$dest_unix/$f.orig" ] || cp -a "$dest_unix/$f" "$dest_unix/$f.orig"
        chmod u+w "$dest_unix/$f"
        if ! curl -fsSL -o "$dest_unix/$f" "$release_url/$f"; then
            ui_msg "Error" "Failed to download $f from the somnilux release."
            exit 1
        fi
    done

    for f in secur32.dll crypt32.dll rsaenh.dll; do
        [ -f "$dest_win/$f.orig" ] || cp -a "$dest_win/$f" "$dest_win/$f.orig"
        chmod u+w "$dest_win/$f"
        if ! curl -fsSL -o "$dest_win/$f" "$release_url/$f"; then
            ui_msg "Error" "Failed to download $f from the somnilux release."
            exit 1
        fi
    done
}

# run_in_prefix proton_dir prefix_path -- executable [args...]
run_in_prefix() {
    local proton_dir="$1" prefix_path="$2"
    shift 2
    PROTONPATH="$proton_dir" WINEPREFIX="$prefix_path" GAMEID="umu-somnium" umu-run "$@"
}

# create_prefix_and_run_installer installer_path prefix_path proton_dir
create_prefix_and_run_installer() {
    local installer_path="$1" prefix_path="$2" proton_dir="$3"

    mkdir -p "$prefix_path"
    echo "Creating the prefix and launching the Somnium installer..."
    run_in_prefix "$proton_dir" "$prefix_path" "$installer_path"
}

main() {
    local mode
    mode=$(main_menu)

    case "$mode" in
        install)
            local result installer_path prefix_path proton_version proton_dir
            result=$(install_flow)
            IFS='|' read -r installer_path prefix_path proton_version proton_dir <<< "$result"
            ui_msg "Result" "Install flow not fully implemented yet.

Installer: $installer_path
Prefix: $prefix_path
Proton version: $proton_version
Proton dir: $proton_dir"
            ;;
        repair)
            local prefix
            prefix=$(repair_flow)
            ui_msg "Result" "Repair flow not yet implemented. Would repair: $prefix"
            ;;
    esac
}

main
