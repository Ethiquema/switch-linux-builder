#!/bin/bash
# Description: Wayland + cage + EmulationStation (default UI)
set -e

echo "=== Installing default UI (EmulationStation) ==="

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="--no-install-recommends -y"

# Wayland stack + EmulationStation-DE from L4T repo
apt install $APT_OPTS \
    wayland-protocols \
    libwayland-client0 \
    libwayland-server0 \
    cage \
    xwayland \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    wireplumber \
    fonts-dejavu-core \
    libsdl2-2.0-0 \
    libfreeimage3 \
    libfreetype6 \
    libcurl4 \
    libpugixml1v5 \
    libfuse2t64 \
    setperf \
    emulationstation-de-l4t


# =============================================================================
# EMULATIONSTATION SERVICE
# =============================================================================

cat > /etc/systemd/system/emulationstation.service << 'EOF'
[Unit]
Description=EmulationStation Frontend
After=graphical.target
Wants=graphical.target
Conflicts=phosh.service xfce.service waydroid-session.service kodi.service

[Service]
Type=simple
User=switch
Group=switch
PAMName=login

Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=XDG_SESSION_TYPE=wayland
Environment=WAYLAND_DISPLAY=wayland-1
Environment=SDL_VIDEODRIVER=wayland

ExecStart=/usr/bin/setperf -p battery --oc battery /usr/bin/cage -s -- emulationstation --no-splash

Restart=on-failure
RestartSec=3
SuccessExitStatus=0 1

[Install]
WantedBy=graphical.target
EOF

# User runtime directory
mkdir -p /etc/tmpfiles.d
echo "d /run/user/1000 0700 switch switch -" > /etc/tmpfiles.d/switch-user.conf

# =============================================================================
# EMULATIONSTATION CONFIGURATION
# =============================================================================

mkdir -p /home/switch/.emulationstation/systems

# System switcher config
cat > /home/switch/.emulationstation/es_systems.cfg << 'EOF'
<?xml version="1.0"?>
<systemList>
    <system>
        <name>switch</name>
        <fullname>System Menu</fullname>
        <path>/home/switch/.emulationstation/systems</path>
        <extension>.sh</extension>
        <command>%ROM%</command>
        <platform>switch</platform>
        <theme>switch</theme>
    </system>
</systemList>
EOF

# Note: Each service (tabs, desktop, android, kodi) creates its own launcher script

# ES settings
cat > /home/switch/.emulationstation/es_settings.cfg << 'EOF'
<?xml version="1.0"?>
<config>
    <string name="AudioDevice" value="default" />
    <bool name="EnableSounds" value="true" />
    <string name="TransitionStyle" value="instant" />
    <bool name="VSync" value="true" />
</config>
EOF

chown -R switch:switch /home/switch/.emulationstation

# Enable as default
systemctl enable emulationstation.service
systemctl set-default graphical.target

echo "=== Default UI installation complete ==="
