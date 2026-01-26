# Switch Linux Builder

A complete Linux distribution builder for Nintendo Switch, featuring retro and modern emulation with intelligent performance management.

## Key Features

### Hardware-Aware Performance Management

**setperf** - A performance tuning wrapper that automatically optimizes CPU, GPU, and RAM settings per application:

- **Switch Model Detection**: Automatically detects Erista (V1) or Mariko (V2/Lite/OLED) and applies appropriate frequency limits
- **Dock/Handheld Mode**: Monitors power delivery in real-time and adjusts frequencies when docking/undocking
- **Performance Profiles**:
  - `battery` - Underclocked for light emulation (8-bit, 16-bit), maximizes battery life
  - `balanced` - Stock frequencies for moderate workloads (32-bit, 64-bit era)
  - `performance` - Maximum governor responsiveness for demanding emulation
- **Optional Overclocking** (requires `~/.enable-overclock`):
  - Handheld-safe frequencies when on battery
  - Maximum frequencies when docked with external power
  - Erista: CPU up to 2091 MHz, GPU up to 921 MHz
  - Mariko: CPU up to 2295 MHz, GPU up to 1267 MHz
- **CPU Pinning**: Limit processes to 1-4 cores for better thread management

Each emulator is pre-configured with optimal settings - light games use battery mode, demanding ones use performance with overclock.

### Modular Services

| Service | Description |
|---------|-------------|
| **base** | L4T kernel, NVIDIA drivers, Joy-Con support, zram, NetworkManager, Flatpak |
| **default** | EmulationStation-DE on Wayland (cage compositor) |
| **emulations** | RetroArch + 50+ libretro cores + standalone emulators |
| **tabs** | Plasma Mobile - full tablet/phone interface with touch keyboard |
| **desktop** | XFCE4 - traditional desktop environment |
| **kodi** | Kodi media center for movies, TV, music |
| **android** | Waydroid - full Android container with Google Play |

All services integrate with EmulationStation as the main launcher. Switching between environments is seamless - close any app and return to ES automatically.

### Filesystem Architecture

- **Immutable rootfs** - SquashFS compressed, protects against corruption
- **Dynamic homefs** - ext4 that auto-expands as needed (no pre-allocation required)
- **Overlay system** - `/etc` and `/var` are writable via OverlayFS backed by homefs
- **FAT32 compatible** - Large files split into parts to work on any SD card
- **Multi-boot ready** - Multiple distributions can coexist via Hekate

## Emulators

### Standalone (Maximum Performance)

| System | Emulator | Package |
|--------|----------|---------|
| GameCube / Wii | Dolphin | dolphin-emu-l4t |
| Nintendo 3DS | Azahar | azahar-emu-l4t |
| PlayStation 1 | DuckStation | duckstation-l4t |
| PlayStation Portable | PPSSPP | ppsspp-l4t |
| Nintendo DS/DSi | melonDS | melonds-l4t |
| Xbox Original | xemu | xemu-l4t |

### RetroArch + Libretro Cores

**From Ubuntu repositories:**
- NES (FCEUmm, Nestopia, QuickNES)
- SNES (Snes9x, bsnes)
- Game Boy / Color / Advance (Gambatte, mGBA, gpSP)
- Nintendo 64 (Mupen64Plus-Next, ParaLLEl)
- Nintendo DS (DeSmuME)
- Genesis / Mega Drive (Genesis Plus GX, PicoDrive)
- Saturn (Beetle Saturn, Yabause)
- Dreamcast (Flycast)
- PlayStation 1 (Beetle PSX, PCSX ReARMed)
- PC Engine / TurboGrafx (Beetle PCE Fast)
- Neo Geo Pocket (Mednafen NGP)
- WonderSwan (Beetle WonderSwan)
- Atari 2600/7800/Lynx (Stella, ProSystem, Handy)
- Virtual Boy (Beetle VB)
- ScummVM

**Compiled from GitHub (libretro-cores-l4t):**
- FBNeo (Arcade, Neo Geo)
- MAME 2003+ (Arcade)
- VICE (Commodore 64/128/VIC-20/Plus4/PET)
- DOSBox Pure (DOS games)
- PUAE (Amiga)
- Fuse (ZX Spectrum)
- Cap32 (Amstrad CPC)
- blueMSX / fMSX (MSX/MSX2)
- Atari800 (Atari 8-bit/5200)
- PX68k (Sharp X68000)
- Quasi88 (NEC PC-8801)
- Opera (3DO)
- NeoCD (Neo Geo CD)
- Virtual Jaguar (Atari Jaguar)
- O2EM (Odyssey 2/Videopac)
- VecX (Vectrex)
- FreeChaF (Channel F)
- FreeIntv (Intellivision)
- Geolith (Neo Geo AES/MVS)
- PrBoom (Doom)
- NXEngine (Cave Story)

### Build Optimizations

All emulators are compiled with:
```
CFLAGS="-O3 -flto -march=armv8-a+crc+simd -mtune=cortex-a57"
LDFLAGS="-flto -ljemalloc"
```
- **LTO** (Link-Time Optimization) for smaller, faster binaries
- **jemalloc** memory allocator for reduced fragmentation
- **ARM64 NEON/SIMD** optimizations for the Tegra X1

## Quick Start

### Build an Emulation Image

```bash
./bin/autobuild --image switch/default+emulations
```

### Build a Full-Featured Image

```bash
./bin/autobuild --image switch/default+emulations+tabs+desktop+android+kodi
```

### List Available Services

```bash
./bin/autobuild --list
```

## Requirements

### Host System
- Linux x86_64 or ARM64
- 20 GB free disk space
- Root access (for losetup, mount)

### Dependencies

```bash
# Debian/Ubuntu
sudo apt install qemu-system-aarch64 qemu-user-static debootstrap \
    squashfs-tools e2fsprogs dosfstools parted curl wget xz-utils cpio

# Arch Linux
sudo pacman -S qemu-full debootstrap squashfs-tools e2fsprogs \
    dosfstools parted curl wget xz cpio
```

## Installation on Switch

1. Format SD card as FAT32
2. Copy contents of `output/switch-linux-YYYYMMDD/` to SD root
3. Install Hekate bootloader if not present
4. Boot Switch in RCM mode and inject Hekate payload
5. Select "Switch Linux" from Hekate menu

## Project Structure

```
switch-linux-builder/
├── bin/                      # Build scripts
│   ├── autobuild             # Main build orchestrator
│   ├── create-initramfs.sh   # Custom initramfs generator
│   └── split-image.sh        # FAT32-compatible file splitter
├── images/switch/
│   ├── config.sh             # Base configuration
│   ├── initramfs/            # Boot scripts (mount, overlays)
│   └── services/             # Modular service definitions
│       ├── base/             # L4T kernel, core system
│       ├── default/          # EmulationStation-DE
│       ├── emulations/       # Emulators + cores
│       ├── tabs/             # Plasma Mobile
│       ├── desktop/          # XFCE4
│       ├── kodi/             # Media center
│       └── android/          # Waydroid
├── l4t-debs/                 # Custom APT repository (submodule)
│   ├── .github/workflows/    # CI builds for all emulators
│   └── packages/             # Package sources (setperf, etc.)
└── docs/                     # Detailed documentation
```

## SD Card Layout (Output)

```
SD Card (FAT32)
├── bootloader/                    # Hekate
│   └── ini/switch-linux.ini       # Boot configuration
├── switchroot/switch-linux/       # Boot files
│   ├── Image                      # Linux kernel
│   ├── initramfs.img              # Custom initramfs
│   ├── tegra210-icosa.dtb         # Device tree
│   └── coreboot.rom               # Coreboot payload
└── linux_img/switch-linux/        # Linux filesystem
    ├── rootfs/
    │   └── rootfs.squashfs.part*  # Immutable system (split)
    └── homefs/
        └── homefs.ext4.part*      # User data (auto-expands)
```

## Performance Profiles by System

| System Category | Profile | OC Mode | CPU Cores |
|-----------------|---------|---------|-----------|
| 8-bit (NES, SMS, GB) | battery | battery | - |
| 16-bit (SNES, Genesis, GBA) | battery | battery | - |
| 32-bit (PS1, Saturn, N64) | balanced | off | 2 |
| CD-based (SegaCD, PCE-CD) | balanced | off | 2 |
| 6th gen (Dreamcast, GC, Wii, Xbox) | performance | oc | 4 |
| Handhelds (PSP, DS, 3DS) | balanced/perf | off/oc | 2-4 |

## GitHub Actions CI/CD

The `l4t-debs` submodule contains GitHub Actions workflows that:
- Cross-compile all standalone emulators for ARM64 via QEMU
- Build all libretro cores from source with LTO
- Package everything as .deb files
- Update the APT repository automatically

Builds use ccache for incremental compilation and Docker layer caching for fast rebuilds.

## Links

- [Switchroot](https://switchroot.org/) - L4T kernel and community
- [Hekate](https://github.com/CTCaer/hekate) - Bootloader
- [Libretro](https://github.com/libretro) - Emulation cores
- [EmulationStation-DE](https://es-de.org/) - Frontend

## License

This project is distributed under the MIT License.

Included emulators and cores retain their respective licenses (GPL, BSD, etc.).
