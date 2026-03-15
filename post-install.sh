#!/bin/bash
# ============================================================
#   POST-INSTALL — Noctalia Edition
#   Runs automatically on first boot via systemd
#   Niri + Hyprland + Noctalia | RTX 4050 | BTRFS | KVM | AI
# ============================================================

set -e

USERNAME="__USERNAME__"
COLOR_SCHEME="__COLOR_SCHEME__"
WALLDIR="__WALLDIR__"
HOME_DIR="/home/$USERNAME"
LOGFILE="/var/log/arch-post-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

step() { echo -e "\n${CYAN}${BOLD}══ $1 ══${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${BLUE}→ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

run_as_user() {
    sudo -u "$USERNAME" env \
        HOME="$HOME_DIR" \
        XDG_RUNTIME_DIR="/run/user/$(id -u $USERNAME)" \
        "$@"
}

step "Post-Install Starting — Noctalia Edition"
info "User: $USERNAME | Theme: $COLOR_SCHEME | Wallpaper dir: $WALLDIR"

# ── Wait for network ──────────────────────────────────────────
step "Network Check"
for i in {1..30}; do
    ping -c1 archlinux.org &>/dev/null && break
    info "Waiting for internet... ($i/30)"
    sleep 3
done
ok "Network ready"

# ── Full system update ────────────────────────────────────────
step "Full System Update"
pacman -Syu --noconfirm
ok "System up to date"

# ── Install yay ───────────────────────────────────────────────
step "Installing yay AUR Helper"
if ! command -v yay &>/dev/null; then
    cd /tmp
    run_as_user git clone https://aur.archlinux.org/yay.git
    cd /tmp/yay
    run_as_user makepkg -si --noconfirm
    cd / && rm -rf /tmp/yay
fi
ok "yay ready"

# ── Enable multilib ───────────────────────────────────────────
step "Enabling multilib"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf
    pacman -Sy --noconfirm
fi
ok "multilib enabled"

# ── NVIDIA Drivers ────────────────────────────────────────────
step "NVIDIA Hybrid GPU Setup (RTX 4050 + AMD 760M)"
pacman -S --noconfirm \
    nvidia nvidia-utils nvidia-prime \
    lib32-nvidia-utils opencl-nvidia \
    libva-nvidia-driver

run_as_user yay -S --noconfirm envycontrol

# Default to integrated (silent, cool, best battery)
envycontrol -s integrated
ok "NVIDIA drivers installed — default: integrated (AMD iGPU)"
info "Aliases: gpu-int / gpu-hybrid / gpu-nvidia (all require reboot)"
info "Run AI tools with: prime-run lmstudio / prime-run ollama serve"

# ── Wayland Base Stack ────────────────────────────────────────
step "Wayland Base Stack"
pacman -S --noconfirm \
    wayland wayland-protocols xorg-xwayland xwayland-satellite \
    xdg-desktop-portal xdg-desktop-portal-wlr \
    xdg-desktop-portal-gnome \
    qt5-wayland qt6-wayland \
    polkit-gnome gnome-keyring libsecret \
    wl-clipboard wl-mirror \
    brightnessctl playerctl \
    grim slurp satty \
    kanshi \
    foot \
    fuzzel \
    swayidle \
    pavucontrol \
    ddcutil
ok "Wayland stack installed"

# ── Niri ─────────────────────────────────────────────────────
step "Installing Niri"
run_as_user yay -S --noconfirm niri
ok "Niri installed"

# ── Hyprland ──────────────────────────────────────────────────
step "Installing Hyprland"
pacman -S --noconfirm \
    hyprland \
    hyprpaper \
    hypridle \
    hyprpicker \
    xdg-desktop-portal-hyprland
ok "Hyprland installed"

# ── Noctalia Shell (Replaces Waybar + Mako + swww) ───────────
step "Installing Noctalia Shell"
info "This compiles noctalia-qs (Quickshell fork) — takes a few minutes..."
# noctalia-shell pulls in noctalia-qs automatically as its runtime
run_as_user yay -S --noconfirm noctalia-shell

# Verify qs binary is present
if ! command -v qs &>/dev/null; then
    warn "qs binary not found in PATH — checking alternate location"
    QS_PATH=$(find /usr -name "qs" -type f 2>/dev/null | head -1)
    [[ -n "$QS_PATH" ]] && ln -sf "$QS_PATH" /usr/local/bin/qs && ok "qs linked to /usr/local/bin/qs"
fi
ok "Noctalia shell installed"
info "Noctalia replaces: Waybar, Mako (notifications), swww (wallpaper)"

# ── SDDM ─────────────────────────────────────────────────────
step "SDDM Display Manager"
pacman -S --noconfirm sddm qt6-svg
run_as_user yay -S --noconfirm sddm-sugar-candy-git 2>/dev/null || \
    run_as_user yay -S --noconfirm sddm-astronaut-theme 2>/dev/null || \
    info "No custom SDDM theme — using default"

systemctl enable sddm

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/general.conf << 'EOF'
[Theme]
Current=sugar-candy

[Autologin]
Relogin=false
EOF
ok "SDDM configured"

# ── Noctalia Settings ─────────────────────────────────────────
step "Configuring Noctalia"
NOCTALIA_DIR="$HOME_DIR/.config/quickshell/noctalia"
WALLS_DIR="$HOME_DIR/Pictures/$WALLDIR"
mkdir -p "$NOCTALIA_DIR" "$WALLS_DIR"

cat > "$NOCTALIA_DIR/settings.json" << NOCEOF
{
  "bar": {
    "position": "top",
    "widgets": {
      "left": [
        {
          "id": "SystemMonitor",
          "showCpuTemp": true,
          "showCpuUsage": true,
          "showMemoryUsage": true
        },
        {
          "id": "ActiveWindow",
          "showIcon": true,
          "maxWidth": 160
        },
        {
          "id": "MediaMini",
          "maxWidth": 160
        }
      ],
      "center": [
        {
          "id": "Workspace",
          "labelMode": "name",
          "hideUnoccupied": false
        }
      ],
      "right": [
        { "id": "ScreenRecorder" },
        { "id": "Tray" },
        { "id": "Network" },
        { "id": "Battery" },
        { "id": "Volume" },
        {
          "id": "Clock",
          "formatHorizontal": "hh:mm A ddd, MMM dd"
        },
        { "id": "ControlCenter" }
      ]
    }
  },
  "colorSchemes": {
    "darkMode": true,
    "predefinedScheme": "$COLOR_SCHEME"
  },
  "ui": {
    "fontDefault": "JetBrainsMono Nerd Font Propo",
    "fontMonospace": "JetBrainsMono Nerd Font",
    "borderRadius": 12
  },
  "wallpaper": {
    "directory": "$WALLS_DIR",
    "enabled": true,
    "fillMode": "crop",
    "randomEnabled": true,
    "randomIntervalSec": 600,
    "transitionDuration": 1200,
    "enableOverviewWallpaper": true
  },
  "notifications": {
    "enabled": true,
    "position": "top-right",
    "timeout": 5000,
    "doNotDisturb": false
  },
  "dock": {
    "enabled": false
  },
  "overview": {
    "enabled": true
  }
}
NOCEOF

chown -R "$USERNAME:$USERNAME" "$NOCTALIA_DIR" "$WALLS_DIR"
ok "Noctalia configured — theme: $COLOR_SCHEME"

# ── Swayidle (idle/lock using Noctalia IPC) ───────────────────
step "Swayidle — Idle & Lock via Noctalia IPC"
# Create a user systemd service for swayidle that uses Noctalia's IPC
# to lock screen and suspend rather than calling swaylock directly.

mkdir -p "$HOME_DIR/.config/systemd/user"
cat > "$HOME_DIR/.config/systemd/user/swayidle.service" << 'IDLEEOF'
[Unit]
Description=SwayIdle — Screen lock and suspend (Noctalia IPC)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/swayidle -w \
    timeout 300 'qs -c noctalia-shell ipc call lockScreen lock' \
    timeout 600 'qs -c noctalia-shell ipc call sessionMenu lockAndSuspend' \
    before-sleep 'qs -c noctalia-shell ipc call lockScreen lock'
Restart=on-failure
TimeoutSec=30

[Install]
WantedBy=graphical-session.target
IDLEEOF

# Enable it for the user
loginctl enable-linger "$USERNAME"
run_as_user systemctl --user enable swayidle.service 2>/dev/null || \
    info "swayidle service will enable on first login"

chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.config/systemd"
ok "swayidle configured to use Noctalia IPC for lock/suspend"

# ── Niri Config ───────────────────────────────────────────────
step "Niri Configuration"
NIRI_DIR="$HOME_DIR/.config/niri"
mkdir -p "$NIRI_DIR"

cat > "$NIRI_DIR/config.kdl" << 'NIRIEOF'
// ╔══════════════════════════════════════════════════════════╗
// ║   Niri Config — Noctalia Edition                        ║
// ║   Keyboard-centric | RTX 4050 | AMD 760M | Wayland      ║
// ╚══════════════════════════════════════════════════════════╝

input {
    keyboard {
        xkb { layout "us" }
        repeat-delay 280
        repeat-rate 55
    }
    touchpad {
        tap
        natural-scroll
        accel-speed 0.35
        accel-profile "adaptive"
        // Disable while typing — important for laptop use
        dwt
    }
    focus-follows-mouse max-scroll-amount="0%"
}

output "eDP-1" {
    scale 1.0
    transform "normal"
}

layout {
    gaps 10
    center-focused-column "never"
    always-center-single-column
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        proportion 1.0
    }
    default-column-width { proportion 0.5; }
    focus-ring {
        width 2
        active-color "#89b4fa"
        inactive-color "#313244"
    }
    border { off }
    struts { left 0; right 0; top 0; bottom 0; }
}

// ── Required by Noctalia ────────────────────────────────────
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}

debug {
    // Allows Noctalia notifications and window activation
    honor-xdg-activation-with-invalid-serial
}

// ── Noctalia overview wallpaper backdrop ───────────────────
layer-rule {
    match namespace="^noctalia-overview*"
    place-within-backdrop true
}

// ── Autostart ───────────────────────────────────────────────
// Noctalia replaces Waybar, Mako, and swww — one shell to rule them all
spawn-at-startup "qs" "-c" "noctalia-shell"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"
spawn-at-startup "xwayland-satellite"

// ── Screenshot path ─────────────────────────────────────────
screenshot-path "~/Pictures/Screenshots/Screenshot %Y-%m-%d %H-%M-%S.png"

// ── Animations ──────────────────────────────────────────────
animations {
    slowdown 0.7
}

// ── Window Rules ────────────────────────────────────────────
window-rule {
    match app-id="foot"
    default-column-width { proportion 0.45; }
}
window-rule {
    match app-id="brave-browser"
    default-column-width { proportion 0.6; }
}
window-rule {
    match app-id="org.pulseaudio.pavucontrol"
    default-column-width { proportion 0.4; }
    open-floating true
}
window-rule {
    match app-id="com.lmstudio.LMStudio"
    default-column-width { proportion 0.7; }
}
window-rule {
    match is-floating=true
    shadow { on; }
}

// ── Keybindings ─────────────────────────────────────────────
binds {
    // ── Apps ────────────────────────────────────────────────
    Mod+Return      { spawn "foot"; }
    Mod+D           { spawn "fuzzel"; }
    Mod+E           { spawn "foot" "-e" "yazi"; }
    Mod+B           { spawn "brave"; }
    Mod+Shift+Return { spawn "foot" "-e" "ncmpcpp"; }
    Mod+V           { spawn "foot" "-e" "cava"; }

    // ── Noctalia Shell Controls ──────────────────────────────
    // Lock screen via Noctalia IPC
    Mod+L { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
    // Open Noctalia overview (like mission control)
    Mod+Tab { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "overview" "toggle"; }
    // Open Noctalia control center
    Mod+N { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "controlCenter" "toggle"; }
    // Power menu
    Mod+Shift+P { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "sessionMenu" "show"; }

    // ── Windows ─────────────────────────────────────────────
    Mod+Q           { close-window; }
    Mod+F           { fullscreen-window; }
    Mod+Shift+F     { toggle-window-floating; }
    Mod+C           { center-column; }
    Mod+Comma       { consume-window-into-column; }
    Mod+Period      { expel-window-from-column; }

    // ── Focus ────────────────────────────────────────────────
    Mod+H           { focus-column-left; }
    Mod+L           { focus-column-right; }
    Mod+J           { focus-window-down; }
    Mod+K           { focus-window-up; }
    Mod+Left        { focus-column-left; }
    Mod+Right       { focus-column-right; }
    Mod+Down        { focus-window-down; }
    Mod+Up          { focus-window-up; }
    Mod+Home        { focus-column-first; }
    Mod+End         { focus-column-last; }

    // ── Move ────────────────────────────────────────────────
    Mod+Shift+H     { move-column-left; }
    Mod+Shift+L     { move-column-right; }
    Mod+Shift+J     { move-window-down; }
    Mod+Shift+K     { move-window-up; }
    Mod+Shift+Left  { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Home  { move-column-to-first; }
    Mod+Shift+End   { move-column-to-last; }

    // ── Resize ──────────────────────────────────────────────
    Mod+Minus       { set-column-width "-10%"; }
    Mod+Equal       { set-column-width "+10%"; }
    Mod+Shift+Minus { set-window-height "-10%"; }
    Mod+Shift+Equal { set-window-height "+10%"; }

    // ── Scroll view ─────────────────────────────────────────
    Mod+WheelScrollRight      { focus-column-right; }
    Mod+WheelScrollLeft       { focus-column-left; }
    Mod+Shift+WheelScrollRight { move-column-right; }
    Mod+Shift+WheelScrollLeft  { move-column-left; }

    // ── Workspaces ──────────────────────────────────────────
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+Shift+4 { move-window-to-workspace 4; }
    Mod+Shift+5 { move-window-to-workspace 5; }
    Mod+Shift+6 { move-window-to-workspace 6; }
    Mod+Shift+7 { move-window-to-workspace 7; }
    Mod+Shift+8 { move-window-to-workspace 8; }
    Mod+Shift+9 { move-window-to-workspace 9; }

    // ── System / Quit ────────────────────────────────────────
    Mod+Shift+R     { reload-config; }
    Mod+Shift+Q     { quit; }

    // ── Screenshots ─────────────────────────────────────────
    Print           { screenshot; }
    Ctrl+Print      { screenshot-screen; }
    Alt+Print       { screenshot-window; }

    // ── Media keys ──────────────────────────────────────────
    XF86AudioRaiseVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume  allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute         allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioPlay         allow-when-locked=true { spawn "playerctl" "play-pause"; }
    XF86AudioNext         allow-when-locked=true { spawn "playerctl" "next"; }
    XF86AudioPrev         allow-when-locked=true { spawn "playerctl" "previous"; }
    XF86MonBrightnessUp   { spawn "brightnessctl" "set" "+5%"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
}
NIRIEOF

chown -R "$USERNAME:$USERNAME" "$NIRI_DIR"
ok "Niri config written with Noctalia integration"

# ── Hyprland Config ───────────────────────────────────────────
step "Hyprland Configuration (Backup WM — also uses Noctalia)"
HYPR_DIR="$HOME_DIR/.config/hypr"
mkdir -p "$HYPR_DIR"

cat > "$HYPR_DIR/hyprland.conf" << 'HYPREOF'
# ╔═══════════════════════════════════════════╗
# ║  Hyprland Config — Noctalia Edition       ║
# ║  Backup WM | Noctalia replaces Waybar     ║
# ╚═══════════════════════════════════════════╝

monitor=,preferred,auto,1

# ── Autostart ─────────────────────────────────────────────────
# Noctalia as the shell (replaces Waybar + Mako + swww)
exec-once = qs -c noctalia-shell
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = gnome-keyring-daemon --start --components=secrets

input {
    kb_layout = us
    repeat_delay = 280
    repeat_rate = 55
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faee)
    col.inactive_border = rgba(313244aa)
    layout = dwindle
}

decoration {
    rounding = 12
    blur {
        enabled = true
        size = 4
        passes = 2
        new_optimizations = true
    }
    shadow {
        enabled = true
        range = 10
        render_power = 2
        color = rgba(1a1a2eee)
    }
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 5, myBezier
    animation = fade, 1, 4, default
    animation = workspaces, 1, 4, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

$mod = SUPER

# ── Apps ──────────────────────────────────────────────────────
bind = $mod, Return,      exec, foot
bind = $mod, D,           exec, fuzzel
bind = $mod, E,           exec, foot -e yazi
bind = $mod, B,           exec, brave
bind = $mod SHIFT, Return,exec, foot -e ncmpcpp
bind = $mod, V,           exec, foot -e cava

# ── Noctalia IPC ──────────────────────────────────────────────
bind = $mod, L,           exec, qs -c noctalia-shell ipc call lockScreen lock
bind = $mod SHIFT, P,     exec, qs -c noctalia-shell ipc call sessionMenu show
bind = $mod, N,           exec, qs -c noctalia-shell ipc call controlCenter toggle
bind = $mod, Tab,         exec, qs -c noctalia-shell ipc call overview toggle

# ── Windows ───────────────────────────────────────────────────
bind = $mod, Q,           killactive
bind = $mod, F,           fullscreen
bind = $mod SHIFT, F,     togglefloating
bind = $mod, H,           movefocus, l
bind = $mod, L,           movefocus, r
bind = $mod, K,           movefocus, u
bind = $mod, J,           movefocus, d
bind = $mod SHIFT, H,     movewindow, l
bind = $mod SHIFT, L,     movewindow, r
bind = $mod SHIFT, K,     movewindow, u
bind = $mod SHIFT, J,     movewindow, d

# ── Workspaces ────────────────────────────────────────────────
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5

# ── Media ─────────────────────────────────────────────────────
bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = ,XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = ,XF86MonBrightnessUp,  exec, brightnessctl set 5%+
bindel = ,XF86MonBrightnessDown,exec, brightnessctl set 5%-
bindl  = ,XF86AudioPlay,        exec, playerctl play-pause
bindl  = ,XF86AudioNext,        exec, playerctl next
bindl  = ,XF86AudioPrev,        exec, playerctl previous
HYPREOF

chown -R "$USERNAME:$USERNAME" "$HYPR_DIR"
ok "Hyprland config written — also uses Noctalia"

# ── Snapper / BTRFS Snapshots ─────────────────────────────────
step "BTRFS Snapshots (Snapper + snap-pac + grub-btrfs)"
pacman -S --noconfirm snapper snap-pac grub-btrfs inotify-tools

snapper -c root delete-config 2>/dev/null || true
snapper -c root create-config /

# Sane limits
sed -i \
    -e 's/TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' \
    -e 's/TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' \
    -e 's/TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' \
    -e 's/TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="1"/' \
    -e 's/TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
    /etc/snapper/configs/root

chown -R ":$USERNAME" /.snapshots 2>/dev/null || true
chmod 750 /.snapshots 2>/dev/null || true

systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
systemctl enable --now grub-btrfs.path
ok "Every pacman install/update now auto-creates a snapshot"
info "Boot into any snapshot from GRUB if something breaks"

# ── VMs — virt-manager + KVM ──────────────────────────────────
step "VMs — virt-manager + KVM"
pacman -S --noconfirm \
    virt-manager qemu-desktop libvirt \
    dnsmasq bridge-utils virt-viewer \
    spice-vdagent

systemctl enable --now libvirtd
virsh net-autostart default
virsh net-start default 2>/dev/null || true

# No need for user to log out — add to group properly
gpasswd -a "$USERNAME" libvirt
ok "virt-manager ready — open it and click New VM"

# ── AI Tools ─────────────────────────────────────────────────
step "AI Tools (Ollama + LM Studio + Open WebUI)"
pacman -S --noconfirm ollama
systemctl enable ollama

run_as_user yay -S --noconfirm lmstudio-bin
run_as_user yay -S --noconfirm python-open-webui 2>/dev/null || \
    pip install open-webui --break-system-packages 2>/dev/null || \
    info "Open WebUI install failed — install manually: pip install open-webui"

info "Pulling llama3.2 in background (downloads after boot)..."
nohup bash -c "sleep 30 && ollama pull llama3.2" &>/tmp/ollama-pull.log &

ok "AI tools installed"
info "Use: prime-run lmstudio  →  runs LM Studio on RTX 4050"
info "Use: ollama run llama3.2 →  chat in terminal"

# ── Terminal Music (ncmpcpp + mpd + cava) ─────────────────────
step "Terminal Music Player (ncmpcpp + mpd + cava)"
pacman -S --noconfirm mpd ncmpcpp mpc cava

MPD_CONF_DIR="$HOME_DIR/.config/mpd"
MPD_DATA_DIR="$HOME_DIR/.local/share/mpd"
MUSIC_DIR="$HOME_DIR/Music"
mkdir -p "$MPD_CONF_DIR" "$MPD_DATA_DIR" "$MUSIC_DIR"

cat > "$MPD_CONF_DIR/mpd.conf" << MPDEOF
music_directory     "~/Music"
db_file             "~/.local/share/mpd/database"
log_file            "~/.local/share/mpd/log"
pid_file            "~/.local/share/mpd/pid"
state_file          "~/.local/share/mpd/state"
sticker_file        "~/.local/share/mpd/sticker.sql"
bind_to_address     "127.0.0.1"
port                "6600"
audio_output {
    type    "pipewire"
    name    "PipeWire Output"
}
MPDEOF

mkdir -p "$HOME_DIR/.config/ncmpcpp"
cat > "$HOME_DIR/.config/ncmpcpp/config" << 'NCEOF'
mpd_host = 127.0.0.1
mpd_port = 6600
mpd_music_dir = ~/Music
user_interface = alternative
visualizer_data_source = /tmp/mpd.fifo
visualizer_output_name = Visualizer
visualizer_in_stereo = yes
visualizer_type = spectrum
visualizer_look = ●▋
progressbar_look = ─╼─
media_library_primary_tag = album_artist
titles_visibility = yes
header_visibility = yes
statusbar_visibility = yes
display_volume_level = yes
display_bitrate = yes
song_columns_list_format = (6f)[]{NE} (50)[]{t} (20)[]{a} (20)[]{b} (5f)[]{l}
NCEOF

mkdir -p "$HOME_DIR/.config/cava"
cat > "$HOME_DIR/.config/cava/config" << 'CAVAEOF'
[general]
bars = 50
framerate = 60

[color]
gradient = 1
gradient_count = 2
gradient_color_1 = '#89b4fa'
gradient_color_2 = '#cba6f7'
CAVAEOF

loginctl enable-linger "$USERNAME"
run_as_user systemctl --user enable mpd 2>/dev/null || true

chown -R "$USERNAME:$USERNAME" \
    "$MPD_CONF_DIR" "$MPD_DATA_DIR" "$MUSIC_DIR" \
    "$HOME_DIR/.config/ncmpcpp" \
    "$HOME_DIR/.config/cava"
ok "ncmpcpp + mpd + cava configured"

# ── Brave Browser ─────────────────────────────────────────────
step "Brave Browser (native AUR)"
run_as_user yay -S --noconfirm brave-bin
ok "Brave installed"

# ── Terminal Tools ────────────────────────────────────────────
step "Terminal Tools + Shell"
pacman -S --noconfirm \
    zsh tmux starship \
    bat eza fzf fd ripgrep \
    zoxide tealdeer fastfetch bottom dust procs \
    yazi ffmpegthumbnailer unar jq imagemagick \
    pacman-contrib

# paccache: auto-clean old package cache weekly
systemctl enable paccache.timer

# ── Fonts ─────────────────────────────────────────────────────
step "Fonts"
pacman -S --noconfirm \
    ttf-jetbrains-mono-nerd \
    ttf-fira-code \
    noto-fonts noto-fonts-emoji noto-fonts-cjk \
    ttf-liberation \
    adobe-source-code-pro-fonts
fc-cache -fv
ok "Fonts installed"

# ── ZSH Setup ─────────────────────────────────────────────────
step "ZSH + Starship Prompt"
chsh -s /bin/zsh "$USERNAME"

cat > "$HOME_DIR/.zshrc" << 'ZSHEOF'
# ── History ───────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS SHARE_HISTORY AUTO_CD INTERACTIVE_COMMENTS

# ── Completion ────────────────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ── Key bindings ──────────────────────────────────────────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward

# ── Aliases ───────────────────────────────────────────────────
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias lt='eza --tree --icons -L 2'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias top='btop'
alias df='dust'
alias ps='procs'
alias cd='z'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'

# System
alias update='yay -Syu'
alias clean='yay -Sc --noconfirm && sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null; true'
alias snap-list='sudo snapper -c root list'
alias snap-new='sudo snapper -c root create --description'
alias snap-undo='sudo snapper -c root undochange'

# GPU switching (needs reboot after)
alias gpu-int='sudo envycontrol -s integrated && echo "→ Reboot to apply"'
alias gpu-hybrid='sudo envycontrol -s hybrid --rtd3 && echo "→ Reboot to apply"'
alias gpu-nvidia='sudo envycontrol -s nvidia && echo "→ Reboot to apply"'
alias gpu-status='envycontrol --query'

# AI tools
alias ai='ollama run llama3.2'
alias lms='prime-run lmstudio'
alias web-ui='open-webui serve'

# Noctalia IPC shortcuts
alias lock='qs -c noctalia-shell ipc call lockScreen lock'
alias noc-restart='qs -c noctalia-shell ipc call shell restart'

# Music
alias music='ncmpcpp'
alias viz='cava'

# ── Init tools ────────────────────────────────────────────────
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
source <(fzf --zsh) 2>/dev/null || true

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
ZSHEOF

# ── Starship ──────────────────────────────────────────────────
cat > "$HOME_DIR/.config/starship.toml" << 'STAREOF'
format = """
[╭─](bold blue)$os $directory$git_branch$git_status$python$nodejs$rust
[╰─](bold blue)$character"""

[os]
disabled = false
style = "bold blue"

[os.symbols]
Arch = ""

[directory]
style = "bold cyan"
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"
STAREOF

chown "$USERNAME:$USERNAME" "$HOME_DIR/.zshrc" "$HOME_DIR/.config/starship.toml"
ok "ZSH + Starship configured"

# ── Foot Terminal ─────────────────────────────────────────────
step "Foot Terminal Config"
mkdir -p "$HOME_DIR/.config/foot"
cat > "$HOME_DIR/.config/foot/foot.ini" << 'FOOTEOF'
[main]
font=JetBrainsMono Nerd Font:size=12
pad=8x8
shell=/bin/zsh

[colors]
# Catppuccin Mocha
background=1e1e2e
foreground=cdd6f4
regular0=45475a
regular1=f38ba8
regular2=a6e3a1
regular3=f9e2af
regular4=89b4fa
regular5=f5c2e7
regular6=94e2d5
regular7=bac2de
bright0=585b70
bright1=f38ba8
bright2=a6e3a1
bright3=f9e2af
bright4=89b4fa
bright5=f5c2e7
bright6=94e2d5
bright7=a6adc8

[cursor]
color=1e1e2e cba6f7
blink=yes
blink-rate=500

[scrollback]
lines=10000
FOOTEOF
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.config/foot"
ok "Foot terminal configured"

# ── Flatpak ───────────────────────────────────────────────────
step "Flatpak (backup app source)"
pacman -S --noconfirm flatpak
run_as_user flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
ok "Flatpak + Flathub ready"

# ── Create screenshot + pictures dirs ────────────────────────
mkdir -p \
    "$HOME_DIR/Pictures/Screenshots" \
    "$HOME_DIR/Pictures/$WALLDIR"
run_as_user xdg-user-dirs-update 2>/dev/null || true
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/Pictures"

# ── sudoers convenience ───────────────────────────────────────
echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/envycontrol" \
    > /etc/sudoers.d/envycontrol
chmod 440 /etc/sudoers.d/envycontrol

# ── Update GRUB with snapshot entries ─────────────────────────
step "Final GRUB Update"
grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB updated — snapshot entries available at boot"

# ── Welcome Message ───────────────────────────────────────────
cat > "$HOME_DIR/.welcome" << WELEOF
╔══════════════════════════════════════════════════════════════╗
║         Your Arch + Noctalia Setup is Complete! 🎉           ║
╠══════════════════════════════════════════════════════════════╣
║  Shell     : Noctalia ($COLOR_SCHEME)                        ║
║  WM (main) : Niri     — select at SDDM login screen         ║
║  WM (back) : Hyprland — select at SDDM login screen         ║
╠══════════════════════════════════════════════════════════════╣
║  KEYBINDS (Niri & Hyprland)                                  ║
║   Mod+Enter         → Terminal (foot)                        ║
║   Mod+D             → App Launcher (fuzzel)                  ║
║   Mod+B             → Brave Browser                          ║
║   Mod+E             → File Manager (yazi)                    ║
║   Mod+Shift+Enter   → Music (ncmpcpp)                        ║
║   Mod+V             → Visualizer (cava)                      ║
║   Mod+L             → Lock (Noctalia IPC)                    ║
║   Mod+N             → Noctalia Control Center                ║
║   Mod+Tab           → Noctalia Overview                      ║
║   Mod+Shift+P       → Power Menu                             ║
╠══════════════════════════════════════════════════════════════╣
║  GPU (reboot after switching)                                ║
║   gpu-int     → AMD iGPU only  (best battery)               ║
║   gpu-hybrid  → balanced       (prime-run for NVIDIA)        ║
║   gpu-nvidia  → NVIDIA only    (max performance)             ║
║   prime-run lmstudio           → LM Studio on RTX 4050      ║
╠══════════════════════════════════════════════════════════════╣
║  AI TOOLS                                                    ║
║   ai                → ollama run llama3.2 (in terminal)      ║
║   lms               → LM Studio on NVIDIA                   ║
║   web-ui            → Open WebUI at localhost:8080           ║
╠══════════════════════════════════════════════════════════════╣
║  SNAPSHOTS                                                   ║
║   snap-list         → list snapshots                         ║
║   snap-new "msg"    → create manual snapshot                 ║
║   (GRUB has snapshot boot entries if things break)          ║
╠══════════════════════════════════════════════════════════════╣
║  WALLPAPERS → drop images in ~/Pictures/$WALLDIR            ║
║  Noctalia will pick them up and rotate automatically         ║
╚══════════════════════════════════════════════════════════════╝
WELEOF

echo 'cat ~/.welcome' >> "$HOME_DIR/.zshrc"
chown "$USERNAME:$USERNAME" "$HOME_DIR/.welcome"

# ── Cleanup: disable this service ────────────────────────────
systemctl disable arch-post-install.service
rm -rf /root/setup

step "DONE — Rebooting in 15 seconds"
echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║  Everything installed! Rebooting now...              ║"
echo "  ║  Select Niri or Hyprland at SDDM login screen.      ║"
echo "  ║  Install log: $LOGFILE                   ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

sleep 15
reboot
