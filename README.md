# 🐆 TapirLinux — dotfiles

All my Hyprland (CachyOS/Arch) configuration and package list, versioned and installable with one command.

## ⚡ One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/Tapir946/TapirLinux/main/install.sh | bash
```

What it does:

1. Clones this repo to `~/TapirLinux` (or pulls latest if already cloned).
2. Installs all pacman packages from `packages/pacman.txt`.
3. Installs `yay` if missing, then AUR packages from `packages/aur.txt` (incl. `hyprmod`).
4. Symlinks every config into `~/.config/` and the home dotfiles into `~/`.
   Existing configs are backed up to `~/.config.bak.<timestamp>`.
5. Idempotent — safe to re-run anytime; installed packages are skipped via `--needed`.

## 🌾 Save & restore your rice (`rice.sh`)

Trying a new setup (e.g. **DankMaterialShell**)? Use `rice.sh` to snapshot first and restore instantly if you don't like it:

```bash
cd ~/GitHub/TapirLinux

./rice.sh snapshot "before dank shell"   # save the current live config into the repo
./rice.sh restore                         # bring the rice back (default: rice-baseline tag)
./rice.sh status                          # show linked/copy/missing + git diff
./rice.sh list                            # list snapshots (tags) and commits
./rice.sh link                            # re-symlink configs into ~/.config and ~/
```

- `restore` backs up whatever is currently there to `~/.rice-backups/<timestamp>/` before overwriting, so nothing is ever lost.
- Works whether or not the configs are symlinked.
- The tag **`rice-baseline`** marks the known-good rice before any experiments.

## 📁 Structure

```
TapirLinux/
├── install.sh            # the installer
├── rice.sh               # snapshot / restore / relink your rice
├── packages/
│   ├── pacman.txt        # explicitly installed repo packages
│   └── aur.txt           # AUR packages (hyprmod + its Python deps)
├── config/               # mirrors ~/.config  → symlinked there
│   ├── hypr/             # hyprland.lua, hyprland-gui.lua, hyprlock.conf, hyprpaper.conf, hyprmod/
│   ├── waybar/           # config.jsonc, style.css, power_menu.xml
│   ├── fish/ kitty/ mako/ rofi/ wlogout/ cava/ btop/
│   ├── nwg-dock-hyprland/ nwg-drawer/
│   ├── micro/ autostart/ gtk-2.0/ gtk-3.0/ gtk-4.0/ qt5ct/ qt6ct/
│   └── spicetify/ mimeapps.list pavucontrol.ini
└── home/                 # → $HOME  (.bashrc, .bash_profile, .profile, .zshrc, .gtkrc-2.0)
```

## 🔒 Privacy

Nothing sensitive is committed:

- **excluded:** `opencode/service.json` (API service password), Firefox/Helium browser profiles, `pulse/` cookies, `dconf/`, GitHub Desktop app storage, Spotify user data.
- If you add new configs, scan for secrets before pushing:
  `grep -rInE "ghp_|token|password|secret|PRIVATE KEY" config home packages`

## 📦 Included apps (highlights)

Hyprland (Lua config + HyprMod), Waybar, kitty, fish, mako, rofi, wlogout, cava, btop, nwg-dock-hyprland, nwg-drawer, micro, hyprlock, hyprpaper, spicetify, Thunar + the full CachyOS tooling set.

## 🧰 Manual usage

```bash
git clone https://github.com/Tapir946/TapirLinux.git ~/TapirLinux
cd ~/TapirLinux
./install.sh              # packages + dotfiles
```

Update configs: edit files in `~/TapirLinux/config/…` — changes are live through the symlinks — then `git add -A && git commit && git push`.