#!/bin/bash
# ============================================================
#   ARCH LINUX AUTO INSTALLER — v2 with Noctalia
#   AMD Ryzen 5 8645HS | RTX 4050 | Niri + Hyprland + Noctalia
# ============================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/404Prabhat/arch-installer/main"

# Auto-download post-install.sh if not present
if [[ ! -f "$(dirname "$0")/post-install.sh" ]]; then
    echo "Downloading post-install.sh..."
    curl -sLO "$REPO_RAW/post-install.sh"
    chmod +x post-install.sh
fi

# Safety guard — must be run from Arch live ISO only
if ! grep -q "archiso" /etc/hostname 2>/dev/null; then
    echo -e "\033[0;31m⛔ This must be run from an Arch live ISO — not your existing install!\033[0m"
    echo -e "\033[0;31m   Boot from archlinux-*.iso and run this from there.\033[0m"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║      ARCH LINUX — FULLY AUTOMATED INSTALLER v2          ║"
    echo "  ║  Niri + Hyprland + Noctalia | BTRFS | KVM | AI | More  ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

banner

echo -e "${BOLD}Just answer a few quick questions — then walk away ☕${NC}\n"

# ── Username ──────────────────────────────────────────────────
read -p "$(echo -e ${YELLOW}"Enter your username: "${NC})" USERNAME
while [[ -z "$USERNAME" || "$USERNAME" =~ [^a-z0-9_-] ]]; do
    echo -e "${RED}Invalid. Use only lowercase letters, numbers, - or _${NC}"
    read -p "$(echo -e ${YELLOW}"Enter your username: "${NC})" USERNAME
done

# ── Passwords ─────────────────────────────────────────────────
while true; do
    read -sp "$(echo -e ${YELLOW}"Password for $USERNAME: "${NC})" PASSWORD; echo
    read -sp "$(echo -e ${YELLOW}"Confirm password: "${NC})" PASSWORD2; echo
    [[ "$PASSWORD" == "$PASSWORD2" ]] && break
    echo -e "${RED}Passwords don't match.${NC}"
done

while true; do
    read -sp "$(echo -e ${YELLOW}"Root password: "${NC})" ROOT_PASSWORD; echo
    read -sp "$(echo -e ${YELLOW}"Confirm root password: "${NC})" ROOT_PASSWORD2; echo
    [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD2" ]] && break
    echo -e "${RED}Passwords don't match.${NC}"
done

# ── Hostname ──────────────────────────────────────────────────
read -p "$(echo -e ${YELLOW}"Hostname (default: archbox): "${NC})" HOSTNAME
HOSTNAME=${HOSTNAME:-archbox}

# ── Disk ──────────────────────────────────────────────────────
echo -e "\n${BOLD}Available disks:${NC}"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
echo ""
read -p "$(echo -e ${YELLOW}"Disk to install on (e.g. nvme0n1): "${NC})" DISK
DISK=${DISK:-nvme0n1}

# ── Timezone ──────────────────────────────────────────────────
read -p "$(echo -e ${YELLOW}"Timezone (default: Asia/Kathmandu): "${NC})" TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Kathmandu}

# ── Wallpaper directory ───────────────────────────────────────
read -p "$(echo -e ${YELLOW}"Wallpaper folder name in ~/Pictures (default: Wallpapers): "${NC})" WALLDIR
WALLDIR=${WALLDIR:-Wallpapers}

# ── Noctalia color scheme ─────────────────────────────────────
echo ""
echo -e "${BOLD}Noctalia Color Schemes:${NC}"
echo "  1) Tokyo Night  (dark blue/purple — popular)"
echo "  2) Catppuccin Mocha  (warm dark)"
echo "  3) Gruvbox  (earthy warm tones)"
echo "  4) Nord  (cool arctic blues)"
echo "  5) Dracula  (purple/pink dark)"
read -p "$(echo -e ${YELLOW}"Pick a color scheme (1-5, default: 1): "${NC})" SCHEME_CHOICE
case "$SCHEME_CHOICE" in
    2) COLOR_SCHEME="Catppuccin Mocha" ;;
    3) COLOR_SCHEME="Gruvbox" ;;
    4) COLOR_SCHEME="Nord" ;;
    5) COLOR_SCHEME="Dracula" ;;
    *) COLOR_SCHEME="Tokyo Night" ;;
esac

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${BOLD}  INSTALLATION SUMMARY${NC}"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo -e "  Username      : ${GREEN}$USERNAME${NC}"
echo -e "  Hostname      : ${GREEN}$HOSTNAME${NC}"
echo -e "  Disk          : ${GREEN}/dev/$DISK${NC}"
echo -e "  Timezone      : ${GREEN}$TIMEZONE${NC}"
echo -e "  Filesystem    : ${GREEN}BTRFS (5 subvolumes)${NC}"
echo -e "  Bootloader    : ${GREEN}GRUB (snapshot boot support)${NC}"
echo -e "  WMs           : ${GREEN}Niri (main) + Hyprland (backup)${NC}"
echo -e "  Shell         : ${GREEN}Noctalia ($COLOR_SCHEME theme)${NC}"
echo -e "  Wallpaper dir : ${GREEN}~/Pictures/$WALLDIR${NC}"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: /dev/$DISK will be COMPLETELY WIPED!${NC}"
echo ""
read -p "$(echo -e ${YELLOW}"Type YES to continue: "${NC})" CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 1

# ── Generate archinstall config ───────────────────────────────
echo -e "\n${BLUE}Generating install config...${NC}"

cat > /tmp/archinstall-config.json << JSONEOF
{
    "additional-repositories": ["multilib"],
    "archinstall-language": "English",
    "audio_config": { "audio": "pipewire" },
    "bootloader": "Grub",
    "config_version": "2.8.3",
    "debug": false,
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/$DISK",
                "wipe": true,
                "partitions": [
                    {
                        "boot": true,
                        "flags": ["Boot", "ESP"],
                        "fs_type": "fat32",
                        "length": { "unit": "GiB", "value": 1 },
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "boot-part",
                        "start": { "unit": "MiB", "value": 1 },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs_subvolumes": [
                            { "compress": false, "mountpoint": "/",           "name": "@",          "nodatacow": false },
                            { "compress": false, "mountpoint": "/home",        "name": "@home",      "nodatacow": false },
                            { "compress": false, "mountpoint": "/var/log",     "name": "@log",       "nodatacow": false },
                            { "compress": false, "mountpoint": "/var/cache",   "name": "@cache",     "nodatacow": false },
                            { "compress": false, "mountpoint": "/.snapshots",  "name": "@snapshots", "nodatacow": false }
                        ],
                        "flags": [],
                        "fs_type": "btrfs",
                        "length": { "unit": "Percent", "value": 100 },
                        "mount_options": ["compress=zstd", "noatime"],
                        "mountpoint": null,
                        "obj_id": "root-part",
                        "start": { "unit": "GiB", "value": 1 },
                        "status": "create",
                        "type": "primary"
                    }
                ]
            }
        ]
    },
    "hostname": "$HOSTNAME",
    "kernels": ["linux"],
    "locale_config": {
        "kb_layout": "us",
        "sys_enc": "UTF-8",
        "sys_lang": "en_US"
    },
    "network_config": { "type": "nm" },
    "ntp": true,
    "packages": [
        "git", "base-devel", "neovim", "wget", "curl",
        "htop", "btop", "unzip", "zip", "bash-completion",
        "man-db", "man-pages",
        "pipewire", "pipewire-alsa", "pipewire-pulse",
        "pipewire-jack", "wireplumber",
        "networkmanager", "network-manager-applet",
        "grub", "efibootmgr", "os-prober",
        "snapper", "snap-pac", "grub-btrfs", "inotify-tools",
        "btrfs-progs", "mesa", "vulkan-radeon",
        "libva-mesa-driver", "mesa-utils",
        "xdg-utils", "xdg-user-dirs",
        "polkit", "python", "python-pip",
        "docker", "docker-compose"
    ],
    "profile_config": {
        "gfx_driver": "All open-source (default)",
        "greeter": "sddm",
        "profile": { "custom_settings": {}, "details": [], "main": "minimal" }
    },
    "swap": false,
    "timezone": "$TIMEZONE",
    "uki": false
}
JSONEOF

cat > /tmp/archinstall-creds.json << CREDEOF
{
    "!root-password": "$ROOT_PASSWORD",
    "!users": [
        {
            "!password": "$PASSWORD",
            "groups": ["wheel","video","audio","storage","optical","network","libvirt","docker"],
            "sudo": true,
            "username": "$USERNAME"
        }
    ]
}
CREDEOF

# ── Embed variables into post-install script ──────────────────
SCRIPT_DIR="$(dirname "$0")"
cp "$SCRIPT_DIR/post-install.sh" /tmp/post-install.sh
chmod +x /tmp/post-install.sh
sed -i "s|__USERNAME__|$USERNAME|g"         /tmp/post-install.sh
sed -i "s|__COLOR_SCHEME__|$COLOR_SCHEME|g" /tmp/post-install.sh
sed -i "s|__WALLDIR__|$WALLDIR|g"           /tmp/post-install.sh

# ── Run archinstall ───────────────────────────────────────────
echo -e "\n${GREEN}Launching archinstall...${NC}\n"
sleep 2

archinstall \
    --config /tmp/archinstall-config.json \
    --creds  /tmp/archinstall-creds.json  \
    --silent

# ── Mount new root and inject post-install ────────────────────
echo -e "\n${BLUE}Injecting post-install into new system...${NC}"

PART2=""
if   [ -e "/dev/${DISK}p2" ]; then PART2="/dev/${DISK}p2"
elif [ -e "/dev/${DISK}2"  ]; then PART2="/dev/${DISK}2"
fi

if [ -n "$PART2" ]; then
    mount -o subvol=@ "$PART2" /mnt

    mkdir -p /mnt/root/setup
    cp /tmp/post-install.sh /mnt/root/setup/post-install.sh

    cat > /mnt/etc/systemd/system/arch-post-install.service << 'SVCEOF'
[Unit]
Description=Arch Post Install — Noctalia Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/root/setup/post-install.sh

[Service]
Type=oneshot
ExecStart=/root/setup/post-install.sh
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
SVCEOF

    mkdir -p /mnt/etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/arch-post-install.service \
        /mnt/etc/systemd/system/multi-user.target.wants/arch-post-install.service

    umount -R /mnt 2>/dev/null || true
    echo -e "${GREEN}✓ Post-install injected${NC}"
else
    echo -e "${YELLOW}⚠️  Could not auto-inject post-install.${NC}"
    echo -e "${YELLOW}   After reboot, run: bash /root/setup/post-install.sh${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Base install done! Rebooting...                    ║${NC}"
echo -e "${GREEN}║   Post-install runs automatically on first boot.     ║${NC}"
echo -e "${GREEN}║   Full setup ready after second reboot (~15-25 min)  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "Press Enter to reboot..."
reboot
