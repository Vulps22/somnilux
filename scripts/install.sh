#!/usr/bin/env bash
set -euo pipefail

BACKTITLE="somnilux — github.com/Vulps22/somnilux"
SUPPORTED_BASE_URL="https://raw.githubusercontent.com/Vulps22/somnilux/main/supported"

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

main() {
    fetch_supported_versions
    local chosen
    chosen=$(pick_proton_version)
    ui_msg "Result" "You picked: $chosen"
}

main
