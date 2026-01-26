#!/bin/bash
# Script de test pour vérifier que QEMU fonctionne correctement

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Test QEMU Boot ==="

# Vérifier l'image cached
DEBIAN_IMAGE="$PROJECT_ROOT/.cache/debian-arm64-base.raw"
if [ ! -f "$DEBIAN_IMAGE" ]; then
    echo "Image Debian non trouvée. Téléchargement..."
    mkdir -p "$PROJECT_ROOT/.cache"
    curl -L -o "$DEBIAN_IMAGE" \
        "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.raw"
fi

# Créer un workdir temporaire
WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"

# Copier l'image
echo "Copie de l'image..."
cp "$DEBIAN_IMAGE" "$WORKDIR/test.raw"

# Redimensionner
echo "Redimensionnement à 8G..."
qemu-img resize -f raw "$WORKDIR/test.raw" 8G

# Trouver le firmware UEFI
UEFI_FW=""
for fw_path in \
    /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    /usr/share/edk2/aarch64/QEMU_EFI.fd \
    /usr/share/AAVMF/AAVMF_CODE.fd \
    /usr/share/qemu/edk2-aarch64-code.fd; do
    if [ -f "$fw_path" ]; then
        UEFI_FW="$fw_path"
        break
    fi
done

if [ -z "$UEFI_FW" ]; then
    echo "ERREUR: Firmware UEFI non trouvé!"
    exit 1
fi
echo "Firmware UEFI: $UEFI_FW"

# Créer seed cloud-init minimal
mkdir -p "$WORKDIR/seed"
cat > "$WORKDIR/seed/meta-data" << EOF
instance-id: test-001
local-hostname: test
EOF

cat > "$WORKDIR/seed/user-data" << EOF
#cloud-config
users:
  - name: test
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
chpasswd:
  list: |
    test:test
    root:root
  expire: false
runcmd:
  - echo "=== Cloud-init started ===" | tee /dev/console
  - echo "=== Test successful ===" | tee /dev/console
  - sleep 5
  - poweroff
EOF

echo "Création seed.img..."
genisoimage -o "$WORKDIR/seed.img" -V "cidata" -r -J "$WORKDIR/seed" 2>/dev/null

# Lancer QEMU
echo ""
echo "=== Lancement QEMU (timeout 120s) ==="
echo "Si ça marche, vous verrez 'Test successful' avant le poweroff"
echo ""

timeout 120 qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -m 2G \
    -smp 2 \
    -bios "$UEFI_FW" \
    -drive file="$WORKDIR/test.raw",format=raw,if=virtio \
    -drive file="$WORKDIR/seed.img",format=raw,if=virtio \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -nographic \
    2>&1 || echo "QEMU exited with code: $?"

echo ""
echo "=== Test terminé ==="

# Cleanup
rm -rf "$WORKDIR"