#!/usr/bin/env bash
# Somnilux is retired in favour of Unilux. This is the last Somnilux
# installer: it installs Unilux, offers to remove the Somnilux setup it
# replaces, and hands over to Unilux.
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

SCRIPT_VERSION="4.0"
# Still answered for scripts/build-artifacts.sh and the release workflows,
# though this script no longer installs binary archives itself.
ARCHIVE_FORMAT=2
BACKTITLE="somnilux — retired in favour of Unilux"
CURL_TIMEOUT_OPTS=(--connect-timeout 10 --max-time 30)
CURL_TIMEOUT_OPTS_LARGE=(--connect-timeout 10 --max-time 600)

UNILUX_URL="https://github.com/Zutyosh/unilux"
# Overridable so the migration can be tested against a local release.
UNILUX_RELEASE_API="${UNILUX_RELEASE_API:-https://api.github.com/repos/Zutyosh/unilux/releases/latest}"
UNILUX_ICON_BASE="https://raw.githubusercontent.com/Zutyosh/unilux/main/assets"
UNILUX_DIR="$HOME/.local/opt/unilux"
LOCAL_BIN="$HOME/.local/bin"
UNILUX_CLI_LINK="$LOCAL_BIN/unilux"
UNILUX_GUI_LINK="$LOCAL_BIN/unilux-gui"
UNILUX_CLI_SHELL="$UNILUX_DIR/cli-shell.sh"
APPS_DIR="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"

SOMNILUX_DIR="$HOME/.local/share/somnilux"
SOMNILUX_DESKTOP="$APPS_DIR/somnium-space.desktop"
DEFAULT_PREFIX="$HOME/Games/umu/umu-somnium"
PATHS_CACHE="$SOMNILUX_DIR/paths.conf"
CACHED_PREFIX=""
CACHED_PROTON=""

UNILUX_CLI=""
UNILUX_GUI=""
UNILUX_TAG=""
WORK_DIR=""

usage() {
    cat <<'EOF'
somnilux installer (final release)

Somnilux is retired in favour of Unilux (https://github.com/Zutyosh/unilux).
Running this installs Unilux, offers to remove the old Somnilux setup, and
then starts Unilux.

  install.sh

  -v, --version
        Print this installer's version as major.minor, and exit. The release
        workflow reads it from the published script so supported/script.txt
        cannot disagree with what shipped.

  --supported-format
        Print the archive format number, and exit. Used by
        scripts/build-artifacts.sh so the number lives in one place.
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --supported-format)
                # The EXIT trap restores the terminal by writing escapes to
                # stdout, which would corrupt this for a caller parsing it.
                trap - EXIT
                printf '%s\n' "$ARCHIVE_FORMAT"
                exit 0
                ;;
            -v|--version)
                trap - EXIT
                printf '%s\n' "$SCRIPT_VERSION"
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
}

HAVE_WHIPTAIL=0
if command -v whiptail >/dev/null 2>&1; then
    HAVE_WHIPTAIL=1
fi
dbg "top-level: HAVE_WHIPTAIL=$HAVE_WHIPTAIL"

# ui_menu outvar title prompt tag1 text1 [tag2 text2 ...]
ui_menu() {
    local -n __um_out="$1"
    shift
    local __um_title="$1" __um_prompt="$2"
    shift 2
    dbg "ui_menu: enter title=[$__um_title]"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        local __um_rc=0
        __um_out=$(whiptail --backtitle "$BACKTITLE" --title "$__um_title" \
            --notags --menu "$__um_prompt" 16 78 6 "$@" 3>&1 1>&2 2>&3) || __um_rc=$?
        dbg "ui_menu: rc=$__um_rc out=[$__um_out]"
        return "$__um_rc"
    fi

    echo "== $__um_title ==" >&2
    echo "$__um_prompt" >&2
    local __um_i=0 __um_tags=() __um_choice
    while [ $# -gt 0 ]; do
        __um_i=$((__um_i + 1))
        __um_tags+=("$1")
        echo "  $__um_i) $2" >&2
        shift 2
    done
    while true; do
        read -r -p "Enter choice [1-$__um_i]: " __um_choice || return 1
        if [ "$__um_choice" -ge 1 ] 2>/dev/null && [ "$__um_choice" -le "$__um_i" ] 2>/dev/null; then
            __um_out="${__um_tags[$((__um_choice - 1))]}"
            return 0
        fi
        echo "Invalid choice." >&2
    done
}

# ui_yesno title prompt yes_label no_label
# Returns 0 for yes, 1 for no or cancel. Enter picks yes.
ui_yesno() {
    local title="$1" prompt="$2" yes="$3" no="$4" ans
    dbg "ui_yesno: enter title=[$title]"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        local rc=0
        whiptail --backtitle "$BACKTITLE" --title "$title" --yes-button "$yes" \
            --no-button "$no" --yesno "$prompt" 16 78 1>&2 || rc=$?
        dbg "ui_yesno: rc=$rc"
        return "$rc"
    fi

    echo "== $title ==" >&2
    echo "$prompt" >&2
    echo "  1) $yes" >&2
    echo "  2) $no" >&2
    while true; do
        read -r -p "Enter choice [1-2, Enter for 1]: " ans || ans=2
        case "${ans:-1}" in
            1) return 0 ;;
            2) return 1 ;;
        esac
        echo "Invalid choice." >&2
    done
}

# ui_msg title message [height] [width]
# Always succeeds: dismissing an informational box isn't a choice, and under
# set -e a non-zero return would abort the whole script.
ui_msg() {
    dbg "ui_msg: enter title=[$1]"
    local title="$1" message="$2" height="${3:-16}" width="${4:-78}"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        whiptail --backtitle "$BACKTITLE" --title "$title" --msgbox "$message" "$height" "$width" 1>&2 || true
        return 0
    fi

    echo "== $title ==" >&2
    echo "$message" >&2
    read -r -p "Press Enter to continue..." _ || true
    return 0
}

fail() {
    dbg "fail: $1"
    ui_msg "Could not install Unilux" "$1

Nothing has been removed: your Somnilux install still works as before.

Debug log: $DEBUG_LOG"
    exit 1
}

check_dependencies() {
    local missing=() cmd
    for cmd in curl tar sha256sum; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        dbg "check_dependencies: missing=[${missing[*]}]"
        ui_msg "Missing dependencies" "This script needs the following, which aren't installed:

  ${missing[*]}

Install them with your distribution's package manager and run this again."
        exit 1
    fi
}

# Parsed by hand rather than sourced -- this file records paths, and a stray
# line in it should not become something this script executes.
cache_load() {
    local key value
    [ -r "$PATHS_CACHE" ] || { dbg "cache_load: no cache at $PATHS_CACHE"; return 1; }
    while IFS='=' read -r key value; do
        case "$key" in
            prefix) CACHED_PREFIX="$value" ;;
            proton) CACHED_PROTON="$value" ;;
        esac
    done < "$PATHS_CACHE"
    dbg "cache_load: prefix=[$CACHED_PREFIX] proton=[$CACHED_PROTON]"
}

# Our own process tree, so a pattern match does not find this script.
installer_pids() {
    local pid=$$ depth=0 rest
    while [ "$pid" -gt 1 ] && [ "$depth" -lt 64 ]; do
        printf '%s\n' "$pid"
        read -r _ rest < "/proc/$pid/stat" 2>/dev/null || break
        rest=${rest#*) }
        pid=$(printf '%s' "$rest" | cut -d' ' -f2)
        [ -n "$pid" ] || break
        depth=$((depth + 1))
    done
}

# Anything holding the Somnilux prefix or Proton open.
running_somnium_pids() {
    local pid cmd mine
    mine=" $(installer_pids | tr '\n' ' ') "
    for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        case "$mine" in *" $pid "*) continue ;; esac
        cmd=$({ tr '\0' ' ' < "/proc/$pid/cmdline"; } 2>/dev/null) || continue
        [ -n "$cmd" ] || continue
        case "$cmd" in
            *umu-somnium*|*-somnilux/files/*|*"$SOMNILUX_DIR"*)
                dbg "running_somnium_pids: $pid [$cmd]"
                printf '%s\n' "$pid" ;;
        esac
    done
}

# Deleting a prefix or Proton under a running Wine corrupts the session.
stop_running_somnium() {
    local pids waited=0
    pids=$(running_somnium_pids | tr '\n' ' ')
    pids="${pids% }"
    [ -n "$pids" ] || return 0
    dbg "stop_running_somnium: found [$pids]"

    ui_msg "Somnium Space is running" "Somnium Space is running from the Somnilux install, so its files can't be removed yet.

Press Enter to close it and continue.

Processes: $pids"

    echo "Closing Somnium Space..."
    kill -TERM $pids 2>/dev/null || true
    while [ "$waited" -lt 20 ]; do
        sleep 0.5
        pids=$(running_somnium_pids | tr '\n' ' ')
        pids="${pids% }"
        [ -n "$pids" ] || return 0
        waited=$((waited + 1))
    done
    kill -KILL $pids 2>/dev/null || true
    sleep 1
    pids=$(running_somnium_pids | tr '\n' ' ')
    if [ -n "${pids// /}" ]; then
        ui_msg "Could not close Somnium Space" "These processes did not stop: $pids

Unilux is installed. Close them yourself, or log out and back in, then run this again to remove the old Somnilux files."
        exit 1
    fi
}

retirement_notice() {
    ui_msg "Somnilux is being retired" "Somnilux is being retired in favour of Unilux:

  $UNILUX_URL

Unilux builds on the work I did with Somnilux to provide a greatly improved user experience, better access to debugging and performance tools, and fixes a number of issues users have reported since the launch of Somnilux.

Press Enter to install Unilux." 18
}

# Sets UNILUX_TAG and leaves the verified tarball at $WORK_DIR/unilux.tar.gz.
unilux_fetch_release() {
    local json tarball_url sum_url want got
    echo "Looking up the latest Unilux release..."
    json=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$UNILUX_RELEASE_API" 2>>"$DEBUG_LOG") ||
        fail "Couldn't reach GitHub to find the latest Unilux release. Check your connection and run this again."

    UNILUX_TAG=$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    tarball_url=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*x86_64-linux\.tar\.gz"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    sum_url=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*x86_64-linux\.tar\.gz\.sha256"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    dbg "unilux_fetch_release: tag=[$UNILUX_TAG] tarball=[$tarball_url] sum=[$sum_url]"
    [ -n "$tarball_url" ] && [ -n "$sum_url" ] ||
        fail "The latest Unilux release ($UNILUX_TAG) has no x86_64 Linux tarball with a checksum."

    echo "Downloading Unilux $UNILUX_TAG..."
    curl -fL# "${CURL_TIMEOUT_OPTS_LARGE[@]}" -o "$WORK_DIR/unilux.tar.gz" "$tarball_url" ||
        fail "Downloading Unilux failed."
    want=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "$sum_url" 2>>"$DEBUG_LOG" | awk '{print $1; exit}') ||
        fail "Downloading Unilux's checksum failed."
    got=$(sha256sum "$WORK_DIR/unilux.tar.gz" | awk '{print $1}')
    dbg "unilux_fetch_release: sha256 want=[$want] got=[$got]"
    [ -n "$want" ] && [ "$want" = "$got" ] ||
        fail "The Unilux download doesn't match its published checksum, so it wasn't installed."
}

# Extracts into UNILUX_DIR, sets UNILUX_CLI and UNILUX_GUI, links them into
# ~/.local/bin. The folder stays writable so Unilux can update itself.
unilux_install_files() {
    local stage="$WORK_DIR/stage" f old=""
    mkdir -p "$stage"
    tar -xzf "$WORK_DIR/unilux.tar.gz" -C "$stage" || fail "Unpacking Unilux failed."

    for f in "$stage"/*; do
        [ -f "$f" ] && [ -x "$f" ] || continue
        case "${f##*/}" in
            *-gui) UNILUX_GUI="${f##*/}" ;;
            *.*) ;;
            *) UNILUX_CLI="${f##*/}" ;;
        esac
    done
    dbg "unilux_install_files: cli=[$UNILUX_CLI] gui=[$UNILUX_GUI]"
    [ -n "$UNILUX_CLI" ] || fail "The Unilux download doesn't contain the command-line program."

    mkdir -p "$(dirname "$UNILUX_DIR")"
    if [ -e "$UNILUX_DIR" ]; then
        old="$UNILUX_DIR.old.$$"
        mv "$UNILUX_DIR" "$old"
    fi
    mv "$stage" "$UNILUX_DIR"
    [ -n "$old" ] && rm -rf "$old"

    UNILUX_CLI="$UNILUX_DIR/$UNILUX_CLI"
    [ -n "$UNILUX_GUI" ] && UNILUX_GUI="$UNILUX_DIR/$UNILUX_GUI"

    mkdir -p "$LOCAL_BIN"
    ln -sfn "$UNILUX_CLI" "$UNILUX_CLI_LINK"
    [ -n "$UNILUX_GUI" ] && ln -sfn "$UNILUX_GUI" "$UNILUX_GUI_LINK"

    cat > "$UNILUX_CLI_SHELL" <<EOF
#!/usr/bin/env bash
# Opens a shell ready for the Unilux command line. Written by the somnilux
# migration script.
export PATH="$LOCAL_BIN:\$PATH"
"$UNILUX_CLI_LINK" --help
echo
echo "Unilux command line ready. Start with: unilux install   (or: unilux doctor)"
echo "Type 'exit' to close."
exec "\${SHELL:-bash}" -i
EOF
    chmod +x "$UNILUX_CLI_SHELL"
    echo "Installed Unilux $UNILUX_TAG to $UNILUX_DIR"
}

# Refuses anything that is not a plain directory well inside the home tree.
safe_to_delete() {
    local p="$1"
    case "$p" in
        ""|/|"$HOME"|"$HOME/") return 1 ;;
        /*) ;;
        *) return 1 ;;
    esac
    [ -d "$p" ] && [ ! -L "$p" ]
}

# Offers to remove what Somnilux installed. Everything is preselected:
# Unilux installs its own Proton, prefix and Somnium.
remove_somnilux() {
    cache_load || true
    local prefix="${CACHED_PREFIX:-$DEFAULT_PREFIX}" protons=() p items=()

    if [ -n "$CACHED_PROTON" ]; then
        protons+=("$CACHED_PROTON")
    else
        for p in "$(dirname "$prefix")"/*-somnilux; do
            [ -d "$p" ] && protons+=("$p")
        done
    fi
    dbg "remove_somnilux: prefix=[$prefix] protons=[${protons[*]:-}]"

    if [ -d "$SOMNILUX_DIR" ] || [ -f "$SOMNILUX_DESKTOP" ]; then
        items+=(somnilux)
    fi
    local have_proton=0
    for p in ${protons[@]+"${protons[@]}"}; do
        case "${p##*/}" in *-somnilux) ;; *) continue ;; esac
        case "$p" in */compatibilitytools.d/*) continue ;; esac
        safe_to_delete "$p" && have_proton=1
    done
    [ "$have_proton" -eq 1 ] && items+=(proton)
    if safe_to_delete "$prefix" && [ -d "$prefix/drive_c" ]; then
        items+=(prefix)
    fi

    if [ "${#items[@]}" -eq 0 ]; then
        dbg "remove_somnilux: nothing to remove"
        return 0
    fi

    if ! ui_yesno "Remove Somnilux?" "It is recommended to uninstall Somnilux, Somnium Space, and all supporting files, before launching Unilux. Unilux uses its own Somnium Space installation. This step is optional." "Yes (Recommended)" "No"; then
        echo "Keeping the Somnilux setup."
        return 0
    fi
    local chosen=" ${items[*]} "
    dbg "remove_somnilux: removing [$chosen]"

    stop_running_somnium

    # Proton and prefix first: their paths come from paths.conf, which the
    # Somnilux item deletes.
    case " $chosen " in *" proton "*)
        for p in ${protons[@]+"${protons[@]}"}; do
            case "${p##*/}" in *-somnilux) ;; *) continue ;; esac
            case "$p" in */compatibilitytools.d/*) continue ;; esac
            safe_to_delete "$p" || continue
            echo "Removing $p"
            rm -rf "$p"
        done
        ;;
    esac
    case " $chosen " in *" prefix "*)
        echo "Removing $prefix"
        rm -rf "$prefix"
        ;;
    esac
    case " $chosen " in *" somnilux "*)
        echo "Removing $SOMNILUX_DIR and $SOMNILUX_DESKTOP"
        safe_to_delete "$SOMNILUX_DIR" && rm -rf "$SOMNILUX_DIR"
        rm -f "$SOMNILUX_DESKTOP"
        ;;
    esac
}

gui_capable() {
    [ -n "$UNILUX_GUI" ] && [ -x "$UNILUX_GUI" ] || return 1
    [ "$(uname -m)" = "x86_64" ] || return 1
    [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]
}

create_unilux_menu_entries() {
    local icon_line="" size
    mkdir -p "$APPS_DIR"
    for size in 256 512; do
        mkdir -p "$ICON_ROOT/${size}x${size}/apps"
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$ICON_ROOT/${size}x${size}/apps/unilux.png.tmp" \
                "$UNILUX_ICON_BASE/unilux-$size.png" 2>>"$DEBUG_LOG"; then
            mv "$ICON_ROOT/${size}x${size}/apps/unilux.png.tmp" "$ICON_ROOT/${size}x${size}/apps/unilux.png"
            icon_line="Icon=unilux"
        else
            rm -f "$ICON_ROOT/${size}x${size}/apps/unilux.png.tmp"
            dbg "create_unilux_menu_entries: ${size}px icon download failed"
        fi
    done
    mkdir -p "$ICON_ROOT/scalable/apps"
    if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$ICON_ROOT/scalable/apps/unilux.svg.tmp" \
            "$UNILUX_ICON_BASE/unilux-logo.svg" 2>>"$DEBUG_LOG"; then
        mv "$ICON_ROOT/scalable/apps/unilux.svg.tmp" "$ICON_ROOT/scalable/apps/unilux.svg"
        icon_line="Icon=unilux"
    else
        rm -f "$ICON_ROOT/scalable/apps/unilux.svg.tmp"
        dbg "create_unilux_menu_entries: svg icon download failed"
    fi
    touch "$ICON_ROOT" 2>/dev/null || true
    if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -f "$ICON_ROOT/index.theme" ]; then
        gtk-update-icon-cache -q -t "$ICON_ROOT" >/dev/null 2>&1 || true
    fi

    cat > "$APPS_DIR/unilux.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Unilux
GenericName=Somnium Space launcher
Comment=Install, launch and troubleshoot Somnium Space on Linux
Exec="$UNILUX_GUI_LINK"
Terminal=false
Categories=Game;
Keywords=Somnium;VR;OpenXR;Proton;
$icon_line
EOF
    cat > "$APPS_DIR/unilux-cli.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Unilux-CLI
GenericName=Somnium Space launcher (command line)
Comment=Open a terminal ready for the Unilux command line
Exec="$UNILUX_CLI_SHELL"
Terminal=true
Categories=Game;
Keywords=Somnium;VR;OpenXR;Proton;
$icon_line
EOF
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
    fi
    for tool in kbuildsycoca6 kbuildsycoca5; do
        if command -v "$tool" >/dev/null 2>&1; then
            "$tool" >/dev/null 2>&1 || true
            break
        fi
    done
    echo "Created menu entries: Unilux, Unilux-CLI"
}

launch_unilux() {
    local choice="cli" path_note=""
    case ":$PATH:" in
        *":$LOCAL_BIN:"*) ;;
        *) path_note="

Note: $LOCAL_BIN is not on your PATH, so in a new terminal run Unilux as $UNILUX_CLI_LINK, or add $LOCAL_BIN to your PATH." ;;
    esac

    if gui_capable; then
        ui_menu choice "Unilux is ready" "Unilux is installed, with Unilux and Unilux-CLI in your application menu.$path_note

Which would you like to start?" \
            gui "Unilux (desktop app)" \
            cli "Unilux CLI (command line)" || choice="cli"
    else
        ui_msg "Unilux is ready" "Unilux is installed. No graphical session was found, so the command line will open now.$path_note" 16
    fi
    dbg "launch_unilux: choice=[$choice]"

    trap - EXIT
    stty sane 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    if [ "$choice" = "gui" ]; then
        echo "Starting Unilux..."
        if command -v setsid >/dev/null 2>&1; then
            setsid -f "$UNILUX_GUI_LINK" >/dev/null 2>&1 < /dev/null
        else
            nohup "$UNILUX_GUI_LINK" >/dev/null 2>&1 < /dev/null &
            disown || true
        fi
        exit 0
    fi
    exec "$UNILUX_CLI_SHELL"
}

main() {
    dbg "main: enter"
    check_dependencies
    retirement_notice
    WORK_DIR=$(mktemp -d -t somnilux-unilux.XXXXXX)
    trap 'rm -rf "$WORK_DIR"; stty sane 2>/dev/null || true; tput rmcup 2>/dev/null || true' EXIT
    unilux_fetch_release
    unilux_install_files
    rm -rf "$WORK_DIR"
    trap 'stty sane 2>/dev/null || true; tput rmcup 2>/dev/null || true' EXIT
    remove_somnilux
    if gui_capable; then
        create_unilux_menu_entries
    fi
    launch_unilux
}

parse_args "$@"
main
