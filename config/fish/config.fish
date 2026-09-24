source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# opencode
fish_add_path /home/arch/.opencode/bin

fish_add_path /home/arch/.spicetify

# Start Hyprland automatically when logging in on a TTY.
# Uses `hyprland` directly (not start-hyprland).
if status --is-login
    and test -z "$WAYLAND_DISPLAY"
    and test -z "$DISPLAY"
    and string match -q "/dev/tty*" (tty)
    exec hyprland
end
