# Kodi first-boot initialization
# Creates SD card directories for media files

echo "[Kodi] Creating SD card directories..."

if mountpoint -q /sd 2>/dev/null; then
    # Kodi media directories
    mkdir -p /sd/kodi/{Videos,Music,Pictures}

    echo "[Kodi] SD card directories created"
else
    echo "[Kodi] WARNING: /sd not mounted, skipping directory creation"
fi
