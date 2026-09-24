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
# Idempotent: safe to re-run anytime.
#
set -euo pipefail

REPO_URL="https://github.com/Tapir946/TapirLinux.git"
REPO_DIR="${REPO_DIR:-$HOME/TapirLinux}"
BACKUP_DIR="$HOME/.config.bak.$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;36m[tapirlinux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tapirlinux][warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[tapirlinux][error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- repo ----
if [[ ! -d "$REPO_DIR/.git" ]]; then
    log "Cloning TapirLinux into $REPO_DIR"
    mkdir -p "$REPO_DIR"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
else
    log "TapirLinux already cloned at $REPO_DIR — pulling latest"
    git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; continuing with local copy"
fi

cd "$REPO_DIR"

# ------------------------------------------------------------ packages ----
install_packages() {
    command -v pacman >/dev/null 2>&1 || { warn "pacman not found — skipping package install (dotfiles only)."; return; }

    if ! command -v sudo >/dev/null 2>&1; then
        warn "sudo missing — skipping package installation. Install packages manually."
        return
    fi
    [[ "$(id -u)" -eq 0 ]] && SUDO="" || SUDO="sudo"

    # --- pacman packages (allows re-runs: --needed skips installed) ---
    local avail=() p
    log "Checking pacman packages…"
    while read -r p; do
        [[ -z "$p" || "$p" == \#* ]] && continue
        pacman -Si "$p" >/dev/null 2>&1 && avail+=("$p")
    done < packages/pacman.txt
    if (( ${#avail[@]} )); then
        log "Installing ${#avail[@]} pacman packages (sudo may prompt)…"
        $SUDO pacman -S --needed --noconfirm "${avail[@]}"
    fi

    # --- AUR helper ---
    if ! command -v yay >/dev/null 2>&1; then
        log "Installing yay (AUR helper)…"
        $SUDO pacman -S --needed --noconfirm base-devel git
        git clone https://aur.archlinux.org/yay-bin.git /tmp/tapirlinux-yay-bin
        (cd /tmp/tapirlinux-yay-bin && makepkg -si --noconfirm)
    fi

    # --- AUR packages ---
    local aur=()
    while read -r p; do
        [[ -z "$p" || "$p" == \#* ]] && continue
        aur+=("$p")
    done < packages/aur.txt
    if (( ${#aur[@]} )); then
        log "Installing AUR packages: ${aur[*]}"
        yay -S --needed --noconfirm "${aur[@]}"
    fi
}

# -------------------------------------------------------------- dotfiles ----
symlink_dir() {
    local src_dir="$1" dst_dir="$2"
    mkdir -p "$dst_dir"
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
            mkdir -p "$BACKUP_DIR"
            mv "$dst" "$BACKUP_DIR/"
            log "Backed up existing $dst -> $BACKUP_DIR/"
        fi
        ln -s "$entry" "$dst"
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
install_packages
install_dotfiles

log "Done! Re-login or restart Hyprland to apply changes."
log "  hyprctl reload      — applies Hyprland config"
log "  waybar restart      — applies waybar changes"
[[ -d "$BACKUP_DIR" ]] && warn "Previous configs preserved in $BACKUP_DIR"