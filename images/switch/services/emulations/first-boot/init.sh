# Emulations first-boot initialization
# Creates SD card directories for RetroArch and ROMs

echo "[Emulations] Creating SD card directories..."

if mountpoint -q /sd 2>/dev/null; then
    # RetroArch directories (compatible with Switch homebrew structure)
    mkdir -p /sd/retroarch/{saves,states,screenshots,system}

    # ROM directories
    mkdir -p /sd/roms/{nes,snes,n64,gb,gbc,gba,nds,psp,ps1,gc,wii,3ds,genesis,saturn,dreamcast,xbox}

    echo "[Emulations] SD card directories created"
else
    echo "[Emulations] WARNING: /sd not mounted, skipping directory creation"
fi
