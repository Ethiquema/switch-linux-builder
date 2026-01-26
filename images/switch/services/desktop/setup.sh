#!/bin/bash
# Description: XFCE desktop environment (X11)
set -e

echo "=== Installing XFCE Desktop ==="

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="--no-install-recommends -y"

# =============================================================================
# REPOSITORIES (Mozilla PPA for Firefox)
# =============================================================================

add-apt-repository -y ppa:mozillateam/ppa

# Prefer Firefox from PPA over snap
cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

# Single update after adding repo
apt update

# =============================================================================
# PACKAGES (single install)
# =============================================================================

apt install $APT_OPTS \
    xserver-xorg-core \
    xserver-xorg-input-libinput \
    xinit \
    x11-xserver-utils \
    xfce4 \
    xfce4-goodies \
    thunar-archive-plugin \
    lightdm \
    lightdm-gtk-greeter \
    firefox \
    file-roller \
    parole \
    gnome-software \
    gnome-software-plugin-flatpak

# =============================================================================
# LIGHTDM CONFIGURATION
# =============================================================================

cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=switch
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

# =============================================================================
# XFCE SERVICE
# =============================================================================

cat > /etc/systemd/system/xfce.service << 'EOF'
[Unit]
Description=XFCE Desktop Session
After=graphical.target
Wants=graphical.target
Conflicts=emulationstation.service plasma-mobile.service waydroid-session.service kodi.service

[Service]
Type=simple
User=switch
Group=switch
PAMName=login

Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=DISPLAY=:0

ExecStart=/usr/bin/setperf -p battery --oc off /usr/bin/startxfce4

Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical.target
EOF

# =============================================================================
# XFCE CONFIGURATION
# =============================================================================

mkdir -p /home/switch/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p /home/switch/Desktop

# Panel config (bottom, 48px)
cat > /home/switch/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=640;y=696"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="48"/>
    </property>
  </property>
</channel>
EOF

# Return to ES shortcut
cat > /home/switch/Desktop/return-to-es.desktop << 'EOF'
[Desktop Entry]
Name=Return to EmulationStation
Exec=/usr/local/bin/switch-dm emulationstation
Icon=go-home
Terminal=false
Type=Application
EOF
chmod +x /home/switch/Desktop/return-to-es.desktop

# Keyboard shortcuts
cat > /home/switch/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Super&gt;Escape" type="string" value="/usr/local/bin/switch-dm emulationstation"/>
      <property name="&lt;Super&gt;t" type="string" value="xfce4-terminal"/>
      <property name="&lt;Super&gt;e" type="string" value="thunar"/>
    </property>
  </property>
</channel>
EOF

# =============================================================================
# EMULATIONSTATION LAUNCHER
# =============================================================================

mkdir -p /home/switch/.emulationstation/systems

cat > /home/switch/.emulationstation/systems/xfce.sh << 'EOF'
#!/bin/bash
# Launch XFCE Desktop
/usr/local/bin/switch-dm xfce
EOF
chmod +x /home/switch/.emulationstation/systems/xfce.sh

chown -R switch:switch /home/switch/.config
chown -R switch:switch /home/switch/Desktop
chown -R switch:switch /home/switch/.emulationstation

# Disable lightdm (we use our own service)
systemctl disable lightdm 2>/dev/null || true

echo "=== XFCE Desktop installation complete ==="
