#!/bin/bash
# Description: Base system with L4T kernel, zram, Joy-Con support
set -e

echo "=== Installing base system ==="

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="--no-install-recommends -y"

# =============================================================================
# REPOSITORIES SETUP (all repos first, single apt update)
# =============================================================================

echo "=== Setting up repositories ==="

# Minimal packages needed to add repos
apt update
apt install $APT_OPTS ca-certificates curl gnupg

# Add L4T kernel repository (theofficialgman)
curl -fsSL https://ethiquema.github.io/l4t-debs/public.key | \
    gpg --dearmor -o /usr/share/keyrings/l4t-debs.gpg

cat > /etc/apt/sources.list.d/l4t-debs.list << 'EOF'
deb [signed-by=/usr/share/keyrings/l4t-debs.gpg] https://ethiquema.github.io/l4t-debs noble main
EOF

# Single apt update after all repos added
apt update

# =============================================================================
# PACKAGES INSTALLATION (single apt install)
# =============================================================================

echo "=== Installing packages ==="

apt install $APT_OPTS \
    systemd \
    systemd-sysv \
    dbus \
    network-manager \
    bluez \
    sudo \
    openssh-server \
    wget \
    udev \
    kmod \
    util-linux \
    e2fsprogs \
    dosfstools \
    zstd \
    zram-tools \
    switch-bsp

# NVIDIA L4T packages: preinst scripts check /proc/device-tree/compatible
# which doesn't exist in QEMU, so we force install and skip those checks
apt install $APT_OPTS -o Dpkg::Options::="--force-all" \
    nvidia-l4t-core \
    nvidia-l4t-firmware \
    nvidia-l4t-3d-core \
    nvidia-l4t-x11 \
    nvidia-l4t-wayland \
    nvidia-l4t-multimedia \
    nvidia-l4t-configs

# Stop zram during build (no module in QEMU)
systemctl stop zramswap 2>/dev/null || true

# Remove bloat and snap
apt purge -y unattended-upgrades snapd 2>/dev/null || true
apt autoremove -y --purge

# Prevent snap from being reinstalled
cat > /etc/apt/preferences.d/nosnap.pref << 'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# =============================================================================
# FLATPAK INSTALLATION
# =============================================================================

echo "=== Installing Flatpak ==="

apt install $APT_OPTS flatpak

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================

echo "=== Configuring system ==="

# Configure zram (50% of RAM, zstd compression)
cat > /etc/default/zramswap << 'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# Create switch user
if ! id -u switch &>/dev/null; then
    useradd -m -G sudo,video,audio,input,render,bluetooth -s /bin/bash switch
    echo "switch:switch" | chpasswd
fi

# Passwordless sudo
echo "switch ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/switch

# Hostname
echo "switch-linux" > /etc/hostname

cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
127.0.1.1   switch-linux
::1         localhost ip6-localhost ip6-loopback
EOF

# Enable services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable zramswap
systemctl enable ssh

# =============================================================================
# WAYLAND ENVIRONMENT VARIABLES (system-wide)
# =============================================================================

echo "=== Configuring Wayland environment ==="

# System-wide environment for Wayland/Qt/SDL
cat > /etc/environment.d/50-wayland.conf << 'EOF'
# Wayland session
WAYLAND_DISPLAY=wayland-0
XDG_SESSION_TYPE=wayland

# Qt Wayland
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# SDL Wayland
SDL_VIDEODRIVER=wayland

# GTK Wayland
GDK_BACKEND=wayland

# Clutter/Mutter
CLUTTER_BACKEND=wayland

# EGL/Vulkan
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
EOF

# Also set in profile.d for login shells
cat > /etc/profile.d/wayland.sh << 'EOF'
# Wayland environment variables
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland
export CLUTTER_BACKEND=wayland
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
EOF
chmod +x /etc/profile.d/wayland.sh

# =============================================================================
# HOMEFS EXPANSION SERVICE
# =============================================================================

echo "=== Installing homefs expansion service ==="

cp /etc/setupfiles/homefs-expand.service /etc/systemd/system/
cp /etc/setupfiles/homefs-expand-daemon.sh /usr/local/bin/
chmod +x /usr/local/bin/homefs-expand-daemon.sh
systemctl enable homefs-expand.service

# =============================================================================
# SERVICES FIRST-BOOT SERVICE
# =============================================================================

echo "=== Installing services first-boot service ==="

cp /etc/setupfiles/services-first-boot.service /etc/systemd/system/
cp /etc/setupfiles/services-first-boot.sh /usr/local/bin/
chmod +x /usr/local/bin/services-first-boot.sh
systemctl enable services-first-boot.service

# =============================================================================
# DISPLAY MANAGER SWITCH SCRIPT
# =============================================================================

cp /etc/setupfiles/switch-dm.sh /usr/local/bin/switch-dm
chmod +x /usr/local/bin/switch-dm

# =============================================================================
# CLEANUP
# =============================================================================

echo "=== Cleaning up ==="

apt clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*

echo "=== Base system installation complete ==="
