#!/bin/bash
# Description: RetroArch + Standalone emulators (L4T optimized ARM64 builds)
set -e

echo "=== Installing emulation packages ==="

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="--no-install-recommends -y"

# =============================================================================
# ALL EMULATORS (RetroArch from Ubuntu, standalone from L4T repo)
# =============================================================================

apt install $APT_OPTS \
    retroarch \
    retroarch-assets \
    libretro-core-info \
    libretro-cores-l4t \
    dolphin-emu-l4t \
    azahar-emu-l4t \
    duckstation-l4t \
    ppsspp-l4t \
    melonds-l4t \
    xemu-l4t

# =============================================================================
# RETROARCH CONFIGURATION
# =============================================================================

echo "Configuring RetroArch..."

mkdir -p /home/switch/.config/retroarch

cat > /home/switch/.config/retroarch/retroarch.cfg << 'EOF'
# RetroArch configuration optimized for Nintendo Switch

# Video
video_driver = "vulkan"
video_context_driver = "wayland"
video_vsync = "true"
video_max_swapchain_images = "2"
video_fullscreen = "true"
video_windowed_fullscreen = "true"

# Audio
audio_driver = "pipewire"
audio_latency = "64"

# Input
input_joypad_driver = "sdl2"
input_autodetect_enable = "true"

# Menu
menu_driver = "ozone"
menu_show_online_updater = "false"

# Paths (compatible with RetroArch Switch homebrew)
savefile_directory = "/sd/retroarch/saves"
savestate_directory = "/sd/retroarch/states"
screenshot_directory = "/sd/retroarch/screenshots"
system_directory = "/sd/retroarch/system"

# Performance
video_threaded = "true"
video_frame_delay = "0"

# Rewind (disabled by default for performance)
rewind_enable = "false"
EOF

# Note: SD card directories are created at first boot via first-boot/init.sh

# =============================================================================
# DOLPHIN CONFIGURATION (Vulkan + Wayland)
# =============================================================================

echo "Configuring Dolphin..."

mkdir -p /home/switch/.config/dolphin-emu

cat > /home/switch/.config/dolphin-emu/Dolphin.ini << 'EOF'
[General]
ISOPaths = 2
ISOPath0 = /sd/roms/gc
ISOPath1 = /sd/roms/wii
RecursiveISOPaths = True

[Interface]
ConfirmStop = False
UsePanicHandlers = False

[Display]
Fullscreen = True
RenderToMain = True

[Core]
CPUThread = True
Fastmem = True
SyncOnSkipIdle = True
GFXBackend = Vulkan
CPUCore = 4
EOF

cat > /home/switch/.config/dolphin-emu/GFX.ini << 'EOF'
[Settings]
AspectRatio = 0
ShaderCompilationMode = 1
WaitForShadersBeforeStarting = False
ShowFPS = True

[Hacks]
EFBAccessEnable = True
EFBToTextureEnable = True
XFBToTextureEnable = True
DeferEFBCopies = True
SkipDuplicateXFBs = True
EFBScaledCopy = True

[Enhancements]
ForceFiltering = False
DisableCopyFilter = True
ArbitraryMipmapDetection = True
EOF

# =============================================================================
# AZAHAR CONFIGURATION (Vulkan)
# =============================================================================

echo "Configuring Azahar..."

mkdir -p /home/switch/.config/azahar-emu

cat > /home/switch/.config/azahar-emu/qt-config.ini << 'EOF'
[Renderer]
use_hw_renderer=true
use_hw_shader=true
use_shader_jit=true
graphics_api=2
use_vsync_new=1
resolution_factor=1
use_disk_shader_cache=true
async_shader_compilation=true

[Layout]
custom_layout=false
swap_screen=false

[System]
region_value=1

[Audio]
enable_audio_stretching=true
output_type=auto
volume=1

[Data Storage]
use_virtual_sd=true
EOF

# =============================================================================
# DUCKSTATION CONFIGURATION (Vulkan)
# =============================================================================

echo "Configuring DuckStation..."

mkdir -p /home/switch/.config/duckstation

cat > /home/switch/.config/duckstation/settings.ini << 'EOF'
[Main]
SettingsVersion = 3

[GPU]
Renderer = Vulkan
UseDebugDevice = false
DisableShaderCache = false
ThreadedPresentation = true
VSync = true
DisplayAspectRatio = Auto
PGXPEnable = true

[Display]
Fullscreen = true
ShowFPS = true

[Audio]
Backend = SDL
OutputLatencyMS = 50

[Controller1]
Type = DigitalController
EOF

# =============================================================================
# PPSSPP CONFIGURATION (Vulkan)
# =============================================================================

echo "Configuring PPSSPP..."

mkdir -p /home/switch/.config/ppsspp/PSP/SYSTEM

cat > /home/switch/.config/ppsspp/PSP/SYSTEM/ppsspp.ini << 'EOF'
[General]
FirstRun = False
AutoRun = True
IgnoreBadMemAccess = True

[Graphics]
GPUBackend = 3
VulkanDevice =
SoftwareRendering = False
FullScreen = True
VSyncInterval = True
RenderingMode = 1
TextureFiltering = 1
InternalResolution = 1

[Sound]
Enable = True
AudioBackend = 0
GlobalVolume = 8

[Control]
ShowTouchControls = False
EOF

# =============================================================================
# MELONDS CONFIGURATION (OpenGL - no Vulkan support)
# =============================================================================

echo "Configuring melonDS..."

mkdir -p /home/switch/.config/melonDS

cat > /home/switch/.config/melonDS/melonDS.toml << 'EOF'
[3D]
Renderer = 1
Threaded = true

[Video]
OpenGL = true
VSyncInterval = 1

[Window]
Fullscreen = true
EOF

# =============================================================================
# XEMU CONFIGURATION (Vulkan)
# =============================================================================

echo "Configuring xemu..."

mkdir -p /home/switch/.local/share/xemu/xemu

cat > /home/switch/.local/share/xemu/xemu/xemu.toml << 'EOF'
[general]
show_welcome = false

[display]
renderer = "VULKAN"
ui_scale = 1
fit = "scale"

[input]
auto_bind = true
EOF

# =============================================================================
# EMULATIONSTATION SYSTEMS CONFIG
# =============================================================================

echo "Configuring EmulationStation systems..."

mkdir -p /home/switch/.emulationstation

cat > /home/switch/.emulationstation/es_systems_emulation.cfg << 'EOF'
<?xml version="1.0"?>
<systemList>
    <!-- Nintendo Systems -->
    <!-- Light: 8-bit/16-bit use battery mode for power saving -->
    <!-- Medium: 32/64-bit use balanced mode -->
    <!-- Heavy: 6th gen+ use performance mode with OC -->

    <system>
        <name>nes</name>
        <fullname>Nintendo Entertainment System</fullname>
        <path>/sd/roms/nes</path>
        <extension>.nes .NES .zip .ZIP .7z</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/fceumm_libretro.so %ROM%</command>
        <platform>nes</platform>
        <theme>nes</theme>
    </system>

    <system>
        <name>snes</name>
        <fullname>Super Nintendo</fullname>
        <path>/sd/roms/snes</path>
        <extension>.sfc .smc .SFC .SMC .zip .ZIP .7z</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/snes9x_libretro.so %ROM%</command>
        <platform>snes</platform>
        <theme>snes</theme>
    </system>

    <system>
        <name>n64</name>
        <fullname>Nintendo 64</fullname>
        <path>/sd/roms/n64</path>
        <extension>.n64 .N64 .z64 .Z64 .v64 .V64 .zip .ZIP</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/mupen64plus_next_libretro.so %ROM%</command>
        <platform>n64</platform>
        <theme>n64</theme>
    </system>

    <system>
        <name>gb</name>
        <fullname>Game Boy</fullname>
        <path>/sd/roms/gb</path>
        <extension>.gb .GB .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/gambatte_libretro.so %ROM%</command>
        <platform>gb</platform>
        <theme>gb</theme>
    </system>

    <system>
        <name>gbc</name>
        <fullname>Game Boy Color</fullname>
        <path>/sd/roms/gbc</path>
        <extension>.gbc .GBC .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/gambatte_libretro.so %ROM%</command>
        <platform>gbc</platform>
        <theme>gbc</theme>
    </system>

    <system>
        <name>gba</name>
        <fullname>Game Boy Advance</fullname>
        <path>/sd/roms/gba</path>
        <extension>.gba .GBA .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/mgba_libretro.so %ROM%</command>
        <platform>gba</platform>
        <theme>gba</theme>
    </system>

    <system>
        <name>nds</name>
        <fullname>Nintendo DS</fullname>
        <path>/sd/roms/nds</path>
        <extension>.nds .NDS .zip .ZIP</extension>
        <command>setperf -p balanced --oc off -n 2 melonDS %ROM%</command>
        <platform>nds</platform>
        <theme>nds</theme>
    </system>

    <system>
        <name>gc</name>
        <fullname>Nintendo GameCube</fullname>
        <path>/sd/roms/gc</path>
        <extension>.iso .ISO .gcm .GCM .gcz .GCZ .rvz .RVZ</extension>
        <command>setperf -p performance --oc oc -n 4 dolphin-emu -b -e %ROM%</command>
        <platform>gc</platform>
        <theme>gc</theme>
    </system>

    <system>
        <name>wii</name>
        <fullname>Nintendo Wii</fullname>
        <path>/sd/roms/wii</path>
        <extension>.iso .ISO .wbfs .WBFS .rvz .RVZ</extension>
        <command>setperf -p performance --oc oc -n 4 dolphin-emu -b -e %ROM%</command>
        <platform>wii</platform>
        <theme>wii</theme>
    </system>

    <system>
        <name>3ds</name>
        <fullname>Nintendo 3DS</fullname>
        <path>/sd/roms/3ds</path>
        <extension>.3ds .3DS .cci .CCI .cxi .CXI .app .APP</extension>
        <command>setperf -p performance --oc oc -n 4 azahar %ROM%</command>
        <platform>3ds</platform>
        <theme>3ds</theme>
    </system>

    <!-- Sony Systems -->
    <system>
        <name>psp</name>
        <fullname>PlayStation Portable</fullname>
        <path>/sd/roms/psp</path>
        <extension>.iso .ISO .cso .CSO .pbp .PBP</extension>
        <command>setperf -p balanced --oc off -n 2 ppsspp %ROM%</command>
        <platform>psp</platform>
        <theme>psp</theme>
    </system>

    <system>
        <name>psx</name>
        <fullname>PlayStation</fullname>
        <path>/sd/roms/ps1</path>
        <extension>.cue .CUE .bin .BIN .iso .ISO .pbp .PBP .chd .CHD</extension>
        <command>setperf -p balanced --oc off -n 2 duckstation %ROM%</command>
        <platform>psx</platform>
        <theme>psx</theme>
    </system>

    <!-- Microsoft Systems -->
    <system>
        <name>xbox</name>
        <fullname>Microsoft Xbox</fullname>
        <path>/sd/roms/xbox</path>
        <extension>.iso .ISO .xiso .XISO</extension>
        <command>setperf -p performance --oc oc -n 4 xemu -dvd_path %ROM%</command>
        <platform>xbox</platform>
        <theme>xbox</theme>
    </system>

    <!-- Sega Systems -->
    <system>
        <name>genesis</name>
        <fullname>Sega Genesis</fullname>
        <path>/sd/roms/genesis</path>
        <extension>.md .MD .gen .GEN .bin .BIN .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/genesis_plus_gx_libretro.so %ROM%</command>
        <platform>genesis</platform>
        <theme>genesis</theme>
    </system>

    <system>
        <name>saturn</name>
        <fullname>Sega Saturn</fullname>
        <path>/sd/roms/saturn</path>
        <extension>.cue .CUE .iso .ISO .chd .CHD</extension>
        <command>setperf -p performance --oc oc -n 4 retroarch -L /usr/lib/libretro/beetle_saturn_libretro.so %ROM%</command>
        <platform>saturn</platform>
        <theme>saturn</theme>
    </system>

    <system>
        <name>dreamcast</name>
        <fullname>Sega Dreamcast</fullname>
        <path>/sd/roms/dreamcast</path>
        <extension>.cdi .CDI .gdi .GDI .chd .CHD</extension>
        <command>setperf -p performance --oc oc -n 4 retroarch -L /usr/lib/libretro/flycast_libretro.so %ROM%</command>
        <platform>dreamcast</platform>
        <theme>dreamcast</theme>
    </system>

    <system>
        <name>mastersystem</name>
        <fullname>Sega Master System</fullname>
        <path>/sd/roms/mastersystem</path>
        <extension>.sms .SMS .zip .ZIP .7z</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/genesis_plus_gx_libretro.so %ROM%</command>
        <platform>mastersystem</platform>
        <theme>mastersystem</theme>
    </system>

    <system>
        <name>gamegear</name>
        <fullname>Sega Game Gear</fullname>
        <path>/sd/roms/gamegear</path>
        <extension>.gg .GG .zip .ZIP .7z</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/genesis_plus_gx_libretro.so %ROM%</command>
        <platform>gamegear</platform>
        <theme>gamegear</theme>
    </system>

    <system>
        <name>segacd</name>
        <fullname>Sega CD</fullname>
        <path>/sd/roms/segacd</path>
        <extension>.cue .CUE .iso .ISO .chd .CHD</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/picodrive_libretro.so %ROM%</command>
        <platform>segacd</platform>
        <theme>segacd</theme>
    </system>

    <system>
        <name>sega32x</name>
        <fullname>Sega 32X</fullname>
        <path>/sd/roms/sega32x</path>
        <extension>.32x .32X .zip .ZIP .7z</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/picodrive_libretro.so %ROM%</command>
        <platform>sega32x</platform>
        <theme>sega32x</theme>
    </system>

    <system>
        <name>neogeo</name>
        <fullname>Neo Geo</fullname>
        <path>/sd/roms/neogeo</path>
        <extension>.zip .ZIP .7z</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/fbneo_libretro.so %ROM%</command>
        <platform>neogeo</platform>
        <theme>neogeo</theme>
    </system>

    <system>
        <name>neogeocd</name>
        <fullname>Neo Geo CD</fullname>
        <path>/sd/roms/neogeocd</path>
        <extension>.cue .CUE .iso .ISO .chd .CHD</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/neocd_libretro.so %ROM%</command>
        <platform>neogeocd</platform>
        <theme>neogeocd</theme>
    </system>

    <!-- NEC Systems -->
    <system>
        <name>pcengine</name>
        <fullname>PC Engine / TurboGrafx-16</fullname>
        <path>/sd/roms/pcengine</path>
        <extension>.pce .PCE .cue .CUE .zip .ZIP .7z</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/beetle_pce_fast_libretro.so %ROM%</command>
        <platform>pcengine</platform>
        <theme>pcengine</theme>
    </system>

    <system>
        <name>supergrafx</name>
        <fullname>PC Engine SuperGrafx</fullname>
        <path>/sd/roms/supergrafx</path>
        <extension>.pce .PCE .sgx .SGX .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/beetle_supergrafx_libretro.so %ROM%</command>
        <platform>supergrafx</platform>
        <theme>supergrafx</theme>
    </system>

    <system>
        <name>pc88</name>
        <fullname>NEC PC-8801</fullname>
        <path>/sd/roms/pc88</path>
        <extension>.d88 .D88 .u88 .U88 .m3u .M3U</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/quasi88_libretro.so %ROM%</command>
        <platform>pc88</platform>
        <theme>pc88</theme>
    </system>

    <!-- SNK Systems -->
    <system>
        <name>ngp</name>
        <fullname>Neo Geo Pocket / Color</fullname>
        <path>/sd/roms/ngp</path>
        <extension>.ngp .NGP .ngc .NGC .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/mednafen_ngp_libretro.so %ROM%</command>
        <platform>ngp</platform>
        <theme>ngp</theme>
    </system>

    <!-- Bandai Systems -->
    <system>
        <name>wonderswan</name>
        <fullname>WonderSwan / Color</fullname>
        <path>/sd/roms/wonderswan</path>
        <extension>.ws .WS .wsc .WSC .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/beetle_wswan_libretro.so %ROM%</command>
        <platform>wonderswan</platform>
        <theme>wonderswan</theme>
    </system>

    <!-- Nintendo Misc -->
    <system>
        <name>virtualboy</name>
        <fullname>Virtual Boy</fullname>
        <path>/sd/roms/virtualboy</path>
        <extension>.vb .VB .vboy .VBOY .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/beetle_vb_libretro.so %ROM%</command>
        <platform>virtualboy</platform>
        <theme>virtualboy</theme>
    </system>

    <!-- Atari Systems -->
    <system>
        <name>atari2600</name>
        <fullname>Atari 2600</fullname>
        <path>/sd/roms/atari2600</path>
        <extension>.a26 .A26 .bin .BIN .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/stella_libretro.so %ROM%</command>
        <platform>atari2600</platform>
        <theme>atari2600</theme>
    </system>

    <system>
        <name>atari7800</name>
        <fullname>Atari 7800</fullname>
        <path>/sd/roms/atari7800</path>
        <extension>.a78 .A78 .bin .BIN .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/prosystem_libretro.so %ROM%</command>
        <platform>atari7800</platform>
        <theme>atari7800</theme>
    </system>

    <system>
        <name>atarilynx</name>
        <fullname>Atari Lynx</fullname>
        <path>/sd/roms/atarilynx</path>
        <extension>.lnx .LNX .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/handy_libretro.so %ROM%</command>
        <platform>atarilynx</platform>
        <theme>atarilynx</theme>
    </system>

    <system>
        <name>atari800</name>
        <fullname>Atari 800 / 5200</fullname>
        <path>/sd/roms/atari800</path>
        <extension>.a52 .A52 .atr .ATR .xex .XEX .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/atari800_libretro.so %ROM%</command>
        <platform>atari800</platform>
        <theme>atari800</theme>
    </system>

    <system>
        <name>jaguar</name>
        <fullname>Atari Jaguar</fullname>
        <path>/sd/roms/jaguar</path>
        <extension>.j64 .J64 .jag .JAG .zip .ZIP</extension>
        <command>setperf -p performance --oc oc -n 4 retroarch -L /usr/lib/libretro/virtualjaguar_libretro.so %ROM%</command>
        <platform>jaguar</platform>
        <theme>jaguar</theme>
    </system>

    <!-- 3DO -->
    <system>
        <name>3do</name>
        <fullname>3DO Interactive Multiplayer</fullname>
        <path>/sd/roms/3do</path>
        <extension>.iso .ISO .cue .CUE .chd .CHD</extension>
        <command>setperf -p performance --oc oc -n 4 retroarch -L /usr/lib/libretro/opera_libretro.so %ROM%</command>
        <platform>3do</platform>
        <theme>3do</theme>
    </system>

    <!-- Commodore Systems -->
    <system>
        <name>c64</name>
        <fullname>Commodore 64</fullname>
        <path>/sd/roms/c64</path>
        <extension>.d64 .D64 .t64 .T64 .prg .PRG .crt .CRT .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/vice_x64_libretro.so %ROM%</command>
        <platform>c64</platform>
        <theme>c64</theme>
    </system>

    <system>
        <name>amiga</name>
        <fullname>Commodore Amiga</fullname>
        <path>/sd/roms/amiga</path>
        <extension>.adf .ADF .ipf .IPF .lha .LHA .hdf .HDF .zip .ZIP</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/puae_libretro.so %ROM%</command>
        <platform>amiga</platform>
        <theme>amiga</theme>
    </system>

    <!-- Sinclair -->
    <system>
        <name>zxspectrum</name>
        <fullname>ZX Spectrum</fullname>
        <path>/sd/roms/zxspectrum</path>
        <extension>.tzx .TZX .tap .TAP .z80 .Z80 .sna .SNA .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/fuse_libretro.so %ROM%</command>
        <platform>zxspectrum</platform>
        <theme>zxspectrum</theme>
    </system>

    <!-- Amstrad -->
    <system>
        <name>amstradcpc</name>
        <fullname>Amstrad CPC</fullname>
        <path>/sd/roms/amstradcpc</path>
        <extension>.dsk .DSK .cdt .CDT .cpr .CPR .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/cap32_libretro.so %ROM%</command>
        <platform>amstradcpc</platform>
        <theme>amstradcpc</theme>
    </system>

    <!-- MSX -->
    <system>
        <name>msx</name>
        <fullname>MSX / MSX2</fullname>
        <path>/sd/roms/msx</path>
        <extension>.rom .ROM .mx1 .MX1 .mx2 .MX2 .dsk .DSK .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/bluemsx_libretro.so %ROM%</command>
        <platform>msx</platform>
        <theme>msx</theme>
    </system>

    <!-- Sharp -->
    <system>
        <name>x68000</name>
        <fullname>Sharp X68000</fullname>
        <path>/sd/roms/x68000</path>
        <extension>.dim .DIM .xdf .XDF .hdm .HDM .2hd .2HD .zip .ZIP</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/px68k_libretro.so %ROM%</command>
        <platform>x68000</platform>
        <theme>x68000</theme>
    </system>

    <!-- Miscellaneous Consoles -->
    <system>
        <name>odyssey2</name>
        <fullname>Magnavox Odyssey 2</fullname>
        <path>/sd/roms/odyssey2</path>
        <extension>.bin .BIN .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/o2em_libretro.so %ROM%</command>
        <platform>odyssey2</platform>
        <theme>odyssey2</theme>
    </system>

    <system>
        <name>vectrex</name>
        <fullname>Vectrex</fullname>
        <path>/sd/roms/vectrex</path>
        <extension>.vec .VEC .bin .BIN .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/vecx_libretro.so %ROM%</command>
        <platform>vectrex</platform>
        <theme>vectrex</theme>
    </system>

    <system>
        <name>channelf</name>
        <fullname>Fairchild Channel F</fullname>
        <path>/sd/roms/channelf</path>
        <extension>.bin .BIN .chf .CHF .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/freechaf_libretro.so %ROM%</command>
        <platform>channelf</platform>
        <theme>channelf</theme>
    </system>

    <system>
        <name>intellivision</name>
        <fullname>Mattel Intellivision</fullname>
        <path>/sd/roms/intellivision</path>
        <extension>.int .INT .bin .BIN .rom .ROM .zip .ZIP</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/freeintv_libretro.so %ROM%</command>
        <platform>intellivision</platform>
        <theme>intellivision</theme>
    </system>

    <!-- DOS -->
    <system>
        <name>dos</name>
        <fullname>DOS</fullname>
        <path>/sd/roms/dos</path>
        <extension>.exe .EXE .com .COM .bat .BAT .dosz .DOSZ .zip .ZIP</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/dosbox_pure_libretro.so %ROM%</command>
        <platform>dos</platform>
        <theme>dos</theme>
    </system>

    <!-- Arcade -->
    <system>
        <name>arcade</name>
        <fullname>Arcade</fullname>
        <path>/sd/roms/arcade</path>
        <extension>.zip .ZIP .7z</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/fbneo_libretro.so %ROM%</command>
        <platform>arcade</platform>
        <theme>arcade</theme>
    </system>

    <system>
        <name>mame</name>
        <fullname>MAME</fullname>
        <path>/sd/roms/mame</path>
        <extension>.zip .ZIP .7z</extension>
        <command>setperf -p balanced --oc off -n 2 retroarch -L /usr/lib/libretro/mame2003_plus_libretro.so %ROM%</command>
        <platform>mame</platform>
        <theme>mame</theme>
    </system>

    <!-- ScummVM -->
    <system>
        <name>scummvm</name>
        <fullname>ScummVM</fullname>
        <path>/sd/roms/scummvm</path>
        <extension>.scummvm .SCUMMVM</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/scummvm_libretro.so %ROM%</command>
        <platform>scummvm</platform>
        <theme>scummvm</theme>
    </system>

    <!-- Doom / FPS -->
    <system>
        <name>doom</name>
        <fullname>Doom</fullname>
        <path>/sd/roms/doom</path>
        <extension>.wad .WAD .iwad .IWAD .pwad .PWAD</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/prboom_libretro.so %ROM%</command>
        <platform>doom</platform>
        <theme>doom</theme>
    </system>

    <!-- Cave Story -->
    <system>
        <name>cavestory</name>
        <fullname>Cave Story</fullname>
        <path>/sd/roms/cavestory</path>
        <extension>.exe .EXE</extension>
        <command>setperf -p battery --oc battery retroarch -L /usr/lib/libretro/nxengine_libretro.so %ROM%</command>
        <platform>cavestory</platform>
        <theme>cavestory</theme>
    </system>
</systemList>
EOF

# Fix ownership (only for ext4 home partition, SD card is FAT32)
chown -R switch:switch /home/switch/.config
chown -R switch:switch /home/switch/.local
chown -R switch:switch /home/switch/.emulationstation

echo "=== Emulation installation complete ==="
