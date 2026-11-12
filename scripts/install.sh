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
UNILUX_ICON_URL="https://raw.githubusercontent.com/Zutyosh/unilux/main/assets/unilux-256.png"
UNILUX_DIR="$HOME/.local/opt/unilux"
LOCAL_BIN="$HOME/.local/bin"
UNILUX_CLI_LINK="$LOCAL_BIN/unilux"
UNILUX_GUI_LINK="$LOCAL_BIN/unilux-gui"
UNILUX_CLI_SHELL="$UNILUX_DIR/cli-shell.sh"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

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
        read -r -p "Enter choice [1-$__um_i]: " __um_choice
        if [ "$__um_choice" -ge 1 ] 2>/dev/null && [ "$__um_choice" -le "$__um_i" ] 2>/dev/null; then
            __um_out="${__um_tags[$((__um_choice - 1))]}"
            return 0
        fi
        echo "Invalid choice." >&2
    done
}

# ui_checklist outvar title prompt tag1 text1 on|off [tag2 text2 on|off ...]
# Writes the chosen tags, space-separated, into outvar. Cancel selects none.
ui_checklist() {
    local -n __uc_out="$1"
    shift
    local __uc_title="$1" __uc_prompt="$2"
    shift 2
    __uc_out=""
    dbg "ui_checklist: enter title=[$__uc_title]"

    if [ "$HAVE_WHIPTAIL" -eq 1 ]; then
        sleep 0.2
        local __uc_args=() __uc_res __uc_rc=0
        while [ $# -gt 0 ]; do
            __uc_args+=("$1" "$2" "$( [ "$3" = on ] && echo ON || echo OFF )")
            shift 3
        done
        __uc_res=$(whiptail --backtitle "$BACKTITLE" --title "$__uc_title" --notags \
            --checklist "$__uc_prompt" 20 78 4 "${__uc_args[@]}" 3>&1 1>&2 2>&3) || __uc_rc=$?
        dbg "ui_checklist: rc=$__uc_rc out=[$__uc_res]"
        [ "$__uc_rc" -eq 0 ] && __uc_out=$(printf '%s' "$__uc_res" | tr -d '"')
        return 0
    fi

    echo "== $__uc_title ==" >&2
    echo "$__uc_prompt" >&2
    local __uc_ans __uc_def
    while [ $# -gt 0 ]; do
        if [ "$3" = on ]; then __uc_def="Y/n"; else __uc_def="y/N"; fi
        read -r -p "  $2? [$__uc_def] " __uc_ans || __uc_ans=""
        case "${__uc_ans:-$([ "$3" = on ] && echo y || echo n)}" in
            [Yy]*) __uc_out="$__uc_out $1" ;;
        esac
        shift 3
    done
    __uc_out="${__uc_out# }"
    dbg "ui_checklist: fallback chose [$__uc_out]"
    return 0
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

Unilux installs, launches and troubleshoots Somnium Space on Linux, with a desktop app and a command line. It builds on Somnilux's patches.

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
    local prefix="${CACHED_PREFIX:-$DEFAULT_PREFIX}" protons=() p items=() chosen

    if [ -n "$CACHED_PROTON" ]; then
        protons+=("$CACHED_PROTON")
    else
        for p in "$(dirname "$prefix")"/*-somnilux; do
            [ -d "$p" ] && protons+=("$p")
        done
    fi
    dbg "remove_somnilux: prefix=[$prefix] protons=[${protons[*]:-}]"

    if [ -d "$SOMNILUX_DIR" ] || [ -f "$SOMNILUX_DESKTOP" ]; then
        items+=(somnilux "Somnilux itself and its Somnium Space menu entry" on)
    fi
    local have_proton=0
    for p in ${protons[@]+"${protons[@]}"}; do
        case "${p##*/}" in *-somnilux) ;; *) continue ;; esac
        case "$p" in */compatibilitytools.d/*) continue ;; esac
        safe_to_delete "$p" && have_proton=1
    done
    [ "$have_proton" -eq 1 ] && items+=(proton "Somnilux's patched Proton copy (a few GB)" on)
    if safe_to_delete "$prefix" && [ -d "$prefix/drive_c" ]; then
        items+=(prefix "The Wine prefix and Somnium Space in it ($prefix)" on)
    fi

    if [ "${#items[@]}" -eq 0 ]; then
        dbg "remove_somnilux: nothing to remove"
        return 0
    fi

    ui_checklist chosen "Remove Somnilux?" "Unilux is installed. Remove the old Somnilux setup?

Recommended: Unilux installs its own Proton, Wine prefix and copy of Somnium Space, so these are no longer used. Removing the prefix also removes Somnium's settings and cached data stored in it." \
        "${items[@]}"
    dbg "remove_somnilux: chosen=[$chosen]"
    [ -n "$chosen" ] || { echo "Keeping the Somnilux setup."; return 0; }

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
    local icon_line=""
    mkdir -p "$APPS_DIR" "$ICON_DIR"
    if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" -o "$ICON_DIR/unilux.png.tmp" "$UNILUX_ICON_URL" 2>>"$DEBUG_LOG"; then
        mv "$ICON_DIR/unilux.png.tmp" "$ICON_DIR/unilux.png"
        icon_line="Icon=$ICON_DIR/unilux.png"
    else
        rm -f "$ICON_DIR/unilux.png.tmp"
        dbg "create_unilux_menu_entries: icon download failed, continuing without"
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
