#!/bin/bash
#
# Download Switch boot files (kernel, dtb, coreboot, firmware)
# These files come from Switchroot/Lakka projects
#

set -e

OUTPUT_DIR="${1:-.}"
CACHE_DIR="${2:-$HOME/.cache/switch-linux-builder}"

# URLs for boot files (from Switchroot/Lakka)
# Note: These URLs may need to be updated as new versions are released
LAKKA_RELEASE_URL="https://github.com/lakka-switch/lakka-switch/releases/latest"
SWITCHROOT_L4T_URL="https://download.switchroot.org/ubuntu/"

mkdir -p "$CACHE_DIR"
mkdir -p "$OUTPUT_DIR"

log() {
    echo "[download-bootfiles] $1"
}

error() {
    echo "[download-bootfiles] ERROR: $1" >&2
    exit 1
}

# Download a file if not cached
download_cached() {
    local url="$1"
    local filename="$2"
    local cache_file="$CACHE_DIR/$filename"

    if [ -f "$cache_file" ]; then
        log "Using cached: $filename"
    else
        log "Downloading: $filename"
        curl -L -o "$cache_file.tmp" "$url" || error "Failed to download $url"
        mv "$cache_file.tmp" "$cache_file"
    fi

    echo "$cache_file"
}

# =============================================================================
# OPTION 1: Extract from Lakka release (includes everything pre-packaged)
# =============================================================================

download_from_lakka() {
    log "Downloading boot files from Lakka Switch release..."

    # Get latest Lakka Switch release
    LAKKA_TAR_URL="https://le-builds.lakka.tv/Switch.aarch64/Lakka-Switch.aarch64-5.0.tar"

    local lakka_tar=$(download_cached "$LAKKA_TAR_URL" "lakka-switch-latest.tar")

    # Extract boot files
    log "Extracting boot files from Lakka..."

    local extract_dir="$CACHE_DIR/lakka-extract"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    # Extract only the boot-related files
    tar -xf "$lakka_tar" -C "$extract_dir" \
        --wildcards \
        'lakka/boot/*' \
        'bootloader/*' \
        2>/dev/null || true

    # Copy to output
    if [ -d "$extract_dir/lakka/boot" ]; then
        cp -r "$extract_dir/lakka/boot"/* "$OUTPUT_DIR/"
        log "Copied boot files from Lakka"
    fi

    if [ -d "$extract_dir/bootloader/sys/l4t" ]; then
        mkdir -p "$OUTPUT_DIR/l4t-firmware"
        cp -r "$extract_dir/bootloader/sys/l4t"/* "$OUTPUT_DIR/l4t-firmware/"
        log "Copied L4T firmware"
    fi

    rm -rf "$extract_dir"
}

# =============================================================================
# OPTION 2: Download individual files from Switchroot
# =============================================================================

download_from_switchroot() {
    log "Downloading boot files from Switchroot..."

    # These would be the actual URLs - they need to be verified
    # as Switchroot packages things differently

    # For now, create placeholder structure
    log "Note: Switchroot downloads require manual verification of URLs"

    # The kernel and dtb come from the L4T kernel package installed in QEMU
    # They should be extracted from /boot after the QEMU stage
}

# =============================================================================
# OPTION 3: Generate/extract from QEMU build
# =============================================================================

extract_from_qemu_image() {
    local qemu_image="$1"

    if [ -z "$qemu_image" ] || [ ! -f "$qemu_image" ]; then
        log "No QEMU image provided, skipping kernel extraction"
        return 1
    fi

    log "Extracting kernel and dtb from QEMU image..."

    local loop_dev=$(losetup -f --show -P "$qemu_image")
    local mount_point="$CACHE_DIR/qemu-mount"
    mkdir -p "$mount_point"

    # Find and mount the root partition
    for part in "${loop_dev}p1" "${loop_dev}p2" "${loop_dev}p3"; do
        if [ -b "$part" ]; then
            fstype=$(blkid -o value -s TYPE "$part" 2>/dev/null || true)
            if [ "$fstype" = "ext4" ]; then
                mount "$part" "$mount_point"
                break
            fi
        fi
    done

    # Copy kernel
    if [ -f "$mount_point/boot/Image" ]; then
        cp "$mount_point/boot/Image" "$OUTPUT_DIR/"
        log "Copied kernel Image"
    elif [ -f "$mount_point/boot/vmlinuz-"* ]; then
        # Debian-style kernel
        local vmlinuz=$(ls "$mount_point/boot/vmlinuz-"* | head -1)
        cp "$vmlinuz" "$OUTPUT_DIR/Image"
        log "Copied kernel from $vmlinuz"
    fi

    # Copy device tree
    if [ -d "$mount_point/boot/dtb" ]; then
        cp "$mount_point/boot/dtb/tegra210-icosa.dtb" "$OUTPUT_DIR/" 2>/dev/null || \
        cp "$mount_point/boot/dtb/"*icosa*.dtb "$OUTPUT_DIR/tegra210-icosa.dtb" 2>/dev/null || \
        log "Warning: Could not find tegra210-icosa.dtb"
    elif [ -f "$mount_point/boot/tegra210-icosa.dtb" ]; then
        cp "$mount_point/boot/tegra210-icosa.dtb" "$OUTPUT_DIR/"
    fi

    # Copy initramfs if exists
    if [ -f "$mount_point/boot/initramfs-"* ]; then
        local initramfs=$(ls "$mount_point/boot/initramfs-"* | head -1)
        cp "$initramfs" "$OUTPUT_DIR/initramfs-l4t.img"
        log "Copied L4T initramfs"
    fi

    # Cleanup
    umount "$mount_point" 2>/dev/null || true
    losetup -d "$loop_dev" 2>/dev/null || true

    return 0
}

# =============================================================================
# Create boot.scr (U-Boot script)
# =============================================================================

create_boot_scr() {
    log "Creating boot.scr..."

    local boot_txt="$OUTPUT_DIR/boot.txt"
    local boot_scr="$OUTPUT_DIR/boot.scr"

    cat > "$boot_txt" << 'EOF'
# U-Boot boot script for Switch Linux

echo "Loading Switch Linux..."

# Set boot arguments
setenv bootargs "root=/dev/ram0 rw rootwait fbcon=rotate:1 consoleblank=0 audit=0"

# Load kernel
echo "Loading kernel..."
load mmc 1:1 ${kernel_addr_r} /switchroot/switch-linux/Image

# Load device tree
echo "Loading device tree..."
load mmc 1:1 ${fdt_addr_r} /switchroot/switch-linux/tegra210-icosa.dtb

# Load initramfs
echo "Loading initramfs..."
load mmc 1:1 ${ramdisk_addr_r} /switchroot/switch-linux/initramfs.img

# Boot
echo "Booting..."
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
EOF

    # Compile boot.scr (requires u-boot-tools)
    if command -v mkimage &> /dev/null; then
        mkimage -A arm64 -T script -C none -n "Switch Linux Boot" -d "$boot_txt" "$boot_scr"
        log "Created boot.scr"
    else
        log "Warning: mkimage not found, boot.scr not compiled"
        log "Install u-boot-tools to compile boot.scr"
        # Keep the text version
        mv "$boot_txt" "$boot_scr.txt"
    fi

    rm -f "$boot_txt"
}

# =============================================================================
# Download coreboot.rom
# =============================================================================

download_coreboot() {
    log "Downloading coreboot.rom..."

    # Coreboot from Lakka Switch project
    local coreboot_url="https://github.com/lakka-switch/boot-scripts/raw/master/payloads/coreboot.rom"

    local coreboot_file=$(download_cached "$coreboot_url" "coreboot.rom")
    cp "$coreboot_file" "$OUTPUT_DIR/coreboot.rom"

    log "Downloaded coreboot.rom"
}

# =============================================================================
# Download L4T firmware files
# =============================================================================

download_l4t_firmware() {
    log "Setting up L4T firmware placeholders..."

    # These files are typically bundled with hekate or L4T releases
    # They're required for L4T boot to work

    mkdir -p "$OUTPUT_DIR/l4t-firmware"

    cat > "$OUTPUT_DIR/l4t-firmware/README.txt" << 'EOF'
L4T Firmware Files

These files are required for booting L4T Linux on Switch:
- bpmpfw.bin / bpmpfw_b01.bin - BPMP firmware
- mtc_tbl.bin / mtc_tbl_b01.bin - Memory training table
- sc7entry.bin - SC7 entry firmware
- sc7exit.bin / sc7exit_b01.bin - SC7 exit firmware

These files should be copied from:
1. A working Hekate installation (bootloader/sys/l4t/)
2. Lakka Switch release
3. Switchroot L4T Ubuntu release

They are NOT included in this builder due to licensing.
EOF

    log "Note: L4T firmware files need to be obtained separately"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log "Downloading Switch boot files to: $OUTPUT_DIR"

    # Download coreboot
    download_coreboot

    # Create boot script
    create_boot_scr

    # Setup L4T firmware placeholders
    download_l4t_firmware

    # If a QEMU image is provided as third argument, extract kernel from it
    if [ -n "$3" ] && [ -f "$3" ]; then
        extract_from_qemu_image "$3"
    else
        log "Note: Kernel and DTB will be extracted from QEMU image during build"
    fi

    log "Boot files download complete"
    ls -la "$OUTPUT_DIR/"
}

main "$@"