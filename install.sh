#!/usr/bin/env bash
#
# TapirLinux — dotfiles & packages installer
#
# Quick install (curl one-liner):
#   curl -fsSL https://raw.githubusercontent.com/Tapir946/TapirLinux/main/install.sh | bash
#
# Manual:
#   git clone https://github.com/Tapir946/TapirLinux.git ~/TapirLinux
#   cd ~/TapirLinux && ./install.sh
#
# Options:
#   --dry-run         Show what would happen, change nothing.
#   --dotfiles-only   Only link configs (skip package installation).
#   --packages-only   Only install packages (skip dotfile linking).
#   --no-pull         Don't git pull an existing clone.
#   -h, --help        Show this help.
#
# Idempotent: safe to re-run anytime.
#
set -euo pipefail

REPO_URL="https://github.com/Tapir946/TapirLinux.git"
REPO_DIR="${REPO_DIR:-$HOME/TapirLinux}"
BACKUP_DIR="$HOME/.config.bak.$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
DO_PACKAGES=1
DO_DOTFILES=1
DO_PULL=1

log()  { printf '\033[1;36m[tapirlinux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tapirlinux][warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[tapirlinux][error]\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if (( DRY_RUN )); then printf '\033[1;35m[dry-run]\033[0m %s\n' "$*"; else "$@"; fi; }

usage() {
    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ------------------------------------------------------------ arguments ----
while (( $# )); do
    case "$1" in
        --dry-run)       DRY_RUN=1 ;;
        --dotfiles-only) DO_PACKAGES=0 ;;
        --packages-only) DO_DOTFILES=0 ;;
        --no-pull)       DO_PULL=0 ;;
        -h|--help)       usage ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
done

(( DRY_RUN )) && warn "DRY RUN — no packages installed, no files changed."

# ---------------------------------------------------------------- repo ----
if [[ ! -d "$REPO_DIR/.git" ]]; then
    log "Cloning TapirLinux into $REPO_DIR"
    run mkdir -p "$REPO_DIR"
    run git clone --depth 1 "$REPO_URL" "$REPO_DIR"
elif (( DO_PULL )); then
    log "TapirLinux already cloned at $REPO_DIR — pulling latest"
    run git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; continuing with local copy"
else
    log "Using existing clone at $REPO_DIR (--no-pull)"
fi

[[ -d "$REPO_DIR" ]] && cd "$REPO_DIR" || { (( DRY_RUN )) || die "repo missing: $REPO_DIR"; }

# ------------------------------------------------------------ packages ----
install_packages() {
    command -v pacman >/dev/null 2>&1 || { warn "pacman not found — skipping package install (dotfiles only)."; return; }

    if ! command -v sudo >/dev/null 2>&1; then
        warn "sudo missing — skipping package installation. Install packages manually."
        return
    fi
    [[ "$(id -u)" -eq 0 ]] && SUDO="" || SUDO="sudo"

    # --- pacman packages (re-runs are safe: --needed skips installed) ---
    local avail=() p
    log "Checking pacman packages…"
    while read -r p; do
        [[ -z "$p" || "$p" == \#* ]] && continue
        if (( DRY_RUN )); then
            avail+=("$p")
        elif pacman -Si "$p" >/dev/null 2>&1; then
            avail+=("$p")
        else
            warn "not in repos, skipping: $p"
        fi
    done < packages/pacman.txt
    if (( ${#avail[@]} )); then
        log "Installing ${#avail[@]} pacman packages (sudo may prompt)…"
        run $SUDO pacman -S --needed --noconfirm "${avail[@]}"
    fi

    # --- AUR helper ---
    if ! command -v yay >/dev/null 2>&1; then
        log "Installing yay (AUR helper)…"
        run $SUDO pacman -S --needed --noconfirm base-devel git
        run git clone https://aur.archlinux.org/yay-bin.git /tmp/tapirlinux-yay-bin
        run bash -c 'cd /tmp/tapirlinux-yay-bin && makepkg -si --noconfirm'
    fi

    # --- AUR packages ---
    local aur=()
    while read -r p; do
        [[ -z "$p" || "$p" == \#* ]] && continue
        aur+=("$p")
    done < packages/aur.txt
    if (( ${#aur[@]} )); then
        log "Installing AUR packages: ${aur[*]}"
        run yay -S --needed --noconfirm "${aur[@]}"
    fi
}

# -------------------------------------------------------------- dotfiles ----
symlink_dir() {
    local src_dir="$1" dst_dir="$2"
    run mkdir -p "$dst_dir"
    for entry in "$src_dir"/* "$src_dir"/.[!.]*; do
        [[ -e "$entry" ]] || continue
        local name dst
        name="$(basename "$entry")"
        dst="$dst_dir/$name"

        # already a symlink pointing at our repo -> nothing to do
        if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$entry")" ]]; then
            continue
        fi
        if [[ -e "$dst" || -L "$dst" ]]; then
            run mkdir -p "$BACKUP_DIR"
            run mv "$dst" "$BACKUP_DIR/"
            log "Backed up existing $dst -> $BACKUP_DIR/"
        fi
        run ln -s "$entry" "$dst"
        log "Linked $dst"
    done
}

install_dotfiles() {
    log "Linking configs into ~/.config …"
    symlink_dir "$REPO_DIR/config"           "$HOME/.config"
    log "Linking home dotfiles …"
    symlink_dir "$REPO_DIR/home"             "$HOME"
}

# ----------------------------------------------------------------- main ----
(( DO_PACKAGES )) && install_packages
(( DO_DOTFILES )) && install_dotfiles

log "Done! Re-login or restart Hyprland to apply changes."
log "  hyprctl reload      — applies Hyprland config"
log "  waybar restart      — applies waybar changes"
[[ -d "$BACKUP_DIR" ]] && warn "Previous configs preserved in $BACKUP_DIR"
exit 0