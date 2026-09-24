#!/usr/bin/env bash
#
# rice.sh — snapshot, restore and relink your TapirLinux rice
#
# Your Hyprland config lives in this repo. Before you try something that
# rewrites your setup (e.g. DankMaterialShell), take a snapshot. If you don't
# like it, restore and you're back exactly where you were.
#
# Usage:
#   ./rice.sh snapshot [message]   Save the CURRENT live configs into the repo + push
#   ./rice.sh restore [ref]        Bring back a saved rice (default: rice-baseline)
#   ./rice.sh link                 Symlink repo configs into ~/.config and ~/
#   ./rice.sh status               Show live-vs-repo link state and git diff
#   ./rice.sh list                 List snapshots (tags) and recent commits
#   ./rice.sh -h | --help
#
# Works whether or not the live configs are symlinked into the repo.
#
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$SELF")" && pwd)}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.rice-backups}"
DEFAULT_REF="${DEFAULT_REF:-rice-baseline}"

log()  { printf '\033[1;36m[rice]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[rice][warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[rice][error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -d "$REPO_DIR/.git" ]] || die "not a git clone: $REPO_DIR"

# Print "kind|source|destination" for every tracked item under a tree.
# kind is config or home.
iter_tree() {
    local base="$1" e name
    for e in "$base"/config/* "$base"/config/.[!.]*; do
        [[ -e "$e" ]] || continue
        name="$(basename "$e")"
        printf 'config|%s|%s\n' "$e" "$HOME/.config/$name"
    done
    for e in "$base"/home/* "$base"/home/.[!.]*; do
        [[ -e "$e" ]] || continue
        name="$(basename "$e")"
        printf 'home|%s|%s\n' "$e" "$HOME/$name"
    done
}

is_linked() {  # src dst -> 0 if dst is a symlink resolving to src
    [[ -L "$2" ]] && [[ "$(readlink -f "$2")" == "$(readlink -f "$1")" ]]
}

# ------------------------------------------------------------- snapshot ----
cmd_snapshot() {
    local msg="${1:-manual snapshot}"
    log "Copying live configs into $REPO_DIR …"
    local kind src dst changed=0
    while IFS='|' read -r kind src dst; do
        [[ -e "$dst" ]] || continue
        is_linked "$src" "$dst" && continue     # already the repo file
        rm -rf "$src"
        cp -a "$dst" "$src"
        changed=1
    done < <(iter_tree "$REPO_DIR")

    git -C "$REPO_DIR" add -A
    if git -C "$REPO_DIR" diff --cached --quiet; then
        log "Nothing changed — snapshot is already up to date."
        return
    fi
    git -C "$REPO_DIR" commit -q -m "rice snapshot: $msg"
    git -C "$REPO_DIR" push >/dev/null 2>&1 && log "Snapshot committed and pushed." \
        || warn "Committed locally, but push failed (offline?)."
}

# -------------------------------------------------------------- restore ----
cmd_restore() {
    local ref="${1:-$DEFAULT_REF}"
    git -C "$REPO_DIR" rev-parse --verify --quiet "$ref^{commit}" >/dev/null \
        || die "unknown ref: $ref (see './rice.sh list')"

    local ts snap tmp
    ts="$(date +%Y%m%d-%H%M%S)"
    snap="$BACKUP_ROOT/$ts"
    tmp="$(mktemp -d)"
    mkdir -p "$snap"
    git -C "$REPO_DIR" archive "$ref" config home | tar -x -C "$tmp"

    log "Restoring rice from '$ref'  (current state -> $snap)"
    local kind src dst name
    while IFS='|' read -r kind src dst; do
        [[ -e "$src" ]] || continue
        name="$(basename "$src")"
        if [[ -L "$dst" ]]; then
            rm -f "$dst"
        elif [[ -e "$dst" ]]; then
            mv "$dst" "$snap/"
        fi
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
    done < <(iter_tree "$tmp")

    rm -rf "$tmp"
    log "Done. Your rice is back. (Pre-restore state kept in $snap)"
}

# ----------------------------------------------------------------- link ----
cmd_link() {
    log "Linking repo configs into ~/.config and ~/ …"
    REPO_DIR="$REPO_DIR" "$REPO_DIR/install.sh" --dotfiles-only --no-pull
}

# --------------------------------------------------------------- status ----
cmd_status() {
    log "Git status of $REPO_DIR:"
    if git -C "$REPO_DIR" status --porcelain | grep -q .; then
        git -C "$REPO_DIR" status --short
    else
        printf '  clean\n'
    fi
    log "Live link state:"
    local kind src dst
    while IFS='|' read -r kind src dst; do
        if is_linked "$src" "$dst"; then
            printf '  \033[1;32mlinked\033[0m   %s\n' "$dst"
        elif [[ -e "$dst" ]]; then
            printf '  \033[1;33mcopy\033[0m     %s (not symlinked)\n' "$dst"
        else
            printf '  \033[1;31mmissing\033[0m  %s\n' "$dst"
        fi
    done < <(iter_tree "$REPO_DIR")
}

# ----------------------------------------------------------------- list ----
cmd_list() {
    log "Snapshots (tags):"
    git -C "$REPO_DIR" tag -n1 --sort=-creatordate || true
    log "Recent commits:"
    git -C "$REPO_DIR" log --oneline -10
}

# ----------------------------------------------------------------- main ----
case "${1:-}" in
    snapshot) shift; cmd_snapshot "${1:-manual snapshot}" ;;
    restore)  shift; cmd_restore "${1:-}" ;;
    link)     cmd_link ;;
    status)   cmd_status ;;
    list)     cmd_list ;;
    -h|--help|help|"")
        sed -n '3,18p' "$SELF" | sed 's/^# \{0,1\}//'
        ;;
    *) die "unknown command: $1 (try --help)" ;;
esac