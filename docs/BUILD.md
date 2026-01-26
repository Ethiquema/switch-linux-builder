# Guide de Build Switch Linux

## Prérequis

### Système hôte
- Linux x86_64 ou ARM64
- 20 Go d'espace disque minimum
- Accès root (pour losetup, mount)

### Paquets requis

```bash
# Debian/Ubuntu
sudo apt install \
    qemu-system-aarch64 \
    qemu-user-static \
    debootstrap \
    squashfs-tools \
    e2fsprogs \
    dosfstools \
    parted \
    curl \
    wget \
    xz-utils \
    cpio \
    genisoimage

# Arch Linux
sudo pacman -S \
    qemu-full \
    debootstrap \
    squashfs-tools \
    e2fsprogs \
    dosfstools \
    parted \
    curl \
    wget \
    xz \
    cpio \
    cdrtools
```

## Utilisation rapide

### Build image par défaut (EmulationStation + RetroArch)

```bash
./bin/autobuild --image switch/default+emulations
```

### Build image complète

```bash
./bin/autobuild --image switch/default+emulations+tabs+desktop+android+kodi
```

### Lister les services disponibles

```bash
./bin/autobuild --list
```

## Pipeline de build

```
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 1: Download                                                │
│ - Télécharge l'image Debian ARM64 (cloud image)                  │
│ - Vérifie les dépendances système                                │
│ - Parse la configuration des services                            │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 2: QEMU Setup                                              │
│ - Redimensionne l'image Debian à 16 Go                           │
│ - Lance QEMU ARM64 avec cloud-init                               │
│ - Exécute les scripts setup.sh de chaque service                 │
│ - Installe le kernel L4T Switchroot                              │
│ - Configure le système (utilisateur, services)                   │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 3: Rootfs                                                  │
│ - Monte l'image QEMU et extrait le rootfs                        │
│ - Nettoie les fichiers temporaires et caches                     │
│ - Crée le SquashFS compressé (zstd level 19)                     │
│ - Découpe en parts de 3.9 Go max (limite FAT32)                  │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 4: Homefs                                                  │
│ - Crée un fichier ext4 sparse de 1.9 Go                          │
│ - Copie les fichiers de /home depuis l'image QEMU                │
│ - Prépare les dossiers overlay (.overlays/etc, .overlays/var)    │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 5: Initramfs                                               │
│ - Génère l'initramfs custom avec busybox                         │
│ - Inclut losetup, dmsetup pour assemblage des parts              │
│ - Script init qui monte squashfs + ext4 + overlays               │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 6: Bootfiles                                               │
│ - Extrait le kernel (Image) de l'image QEMU                      │
│ - Extrait le device tree (tegra210-icosa.dtb)                    │
│ - Télécharge coreboot.rom depuis lakka-switch                    │
│ - Génère boot.scr (script U-Boot)                                │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ ÉTAPE 7: Package                                                 │
│ - Crée la structure de dossiers finale                           │
│ - Copie tous les fichiers (boot, rootfs, homefs)                 │
│ - Génère les configs Hekate (switch-linux.ini)                   │
│ - Crée le README avec instructions d'installation                │
└──────────────────────────────────────────────────────────────────┘
```

## Configuration

### images/switch/config.sh

```bash
# Configuration de base pour Switch Linux

# Image Debian source
IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-genericcloud-arm64-daily.raw"

# Ressources QEMU
QEMU_RAM="4G"
QEMU_CPUS="4"

# Nom de l'image de sortie
OUTPUT_NAME="switch-linux"

# Services par défaut
SERVICES="base"

# Taille des parts
ROOTFS_PART_SIZE="3900M"   # 3.9 Go (limite FAT32 = 4Go)
HOMEFS_PART_SIZE="1900M"   # 1.9 Go

# Repo Switchroot pour le kernel L4T
SWITCHROOT_REPO="https://download.switchroot.org/ubuntu/"

# Description
DESCRIPTION="Switch Linux - Debian ARM64 for Nintendo Switch"
```

### Structure d'un service

```
images/switch/services/<nom>/
├── setup.sh              # Script d'installation (exécuté dans QEMU)
├── first-boot/
│   └── init.sh           # Script premier démarrage
├── setupfiles/           # Fichiers à copier vers /etc/setupfiles/
├── depends.sh            # Dépendances (optionnel)
└── motd.sh               # Message du jour (optionnel)
```

### Exemple: service base

```bash
# images/switch/services/base/setup.sh

#!/bin/bash
set -e

echo "=== Installing base system ==="

# Mise à jour système
apt update && apt upgrade -y

# Paquets essentiels
apt install -y \
    systemd \
    networkmanager \
    bluez \
    zram-tools \
    sudo \
    openssh-server \
    curl \
    wget

# Ajouter le repo Switchroot pour le kernel L4T
curl -fsSL https://download.switchroot.org/ubuntu/switchroot.gpg | \
    gpg --dearmor -o /usr/share/keyrings/switchroot-archive-keyring.gpg

cat > /etc/apt/sources.list.d/switchroot.sources << 'EOF'
Types: deb
URIs: https://download.switchroot.org/ubuntu/
Suites: jammy
Components: main
Signed-By: /usr/share/keyrings/switchroot-archive-keyring.gpg
EOF

# APT pinning pour kernel/firmware
cat > /etc/apt/preferences.d/switchroot-pin << 'EOF'
Package: linux-image-* linux-headers-* nvidia-l4t-*
Pin: origin download.switchroot.org
Pin-Priority: 1001
EOF

apt update

# Installer kernel L4T et drivers NVIDIA
apt install -y \
    linux-image-l4t-switch \
    linux-headers-l4t-switch \
    nvidia-l4t-core \
    nvidia-l4t-firmware \
    nvidia-l4t-gbm

# Configurer zram 50%
cat > /etc/default/zramswap << 'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# Retirer unattended-upgrades
apt purge -y unattended-upgrades || true

# Créer utilisateur switch
useradd -m -G sudo,video,audio,input -s /bin/bash switch
echo "switch:switch" | chpasswd

# Activer les services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable zramswap
systemctl enable ssh

# Copier le service d'expansion homefs
cp /etc/setupfiles/homefs-expand.service /etc/systemd/system/
cp /etc/setupfiles/homefs-expand-daemon.sh /usr/local/bin/
chmod +x /usr/local/bin/homefs-expand-daemon.sh
systemctl enable homefs-expand.service

echo "=== Base system installed ==="
```

## Commandes utiles

### Rebuild d'une seule étape

```bash
# Seulement l'étape QEMU (après avoir modifié un service)
./bin/autobuild --image switch/default --stage qemu

# Seulement la création du squashfs
./bin/autobuild --image switch/default --stage rootfs

# Seulement le packaging final
./bin/autobuild --image switch/default --stage package
```

### Mode verbose

```bash
./bin/autobuild --image switch/default --verbose
```

### Garder les fichiers temporaires (debug)

```bash
./bin/autobuild --image switch/default --keep-temp
```

### Spécifier le dossier de sortie

```bash
./bin/autobuild --image switch/default --output /path/to/output
```

## Output final

Après le build, le dossier output contient :

```
output/switch-linux-YYYYMMDD/
├── bootloader/
│   ├── hekate_ipl.ini
│   ├── ini/
│   │   └── switch-linux.ini
│   └── sys/
│       └── l4t/
│           └── (firmware files)
├── switchroot/
│   └── switch-linux/
│       ├── boot.scr
│       ├── coreboot.rom
│       ├── Image
│       ├── tegra210-icosa.dtb
│       └── initramfs.img
└── linux_img/
    └── switch-linux/
        ├── rootfs/
        │   ├── rootfs.squashfs.part000
        │   └── (autres parts si nécessaire)
        └── homefs/
            └── homefs.ext4.part000
```

## Installation sur SD

1. Copier le contenu de `output/switch-linux-YYYYMMDD/` à la racine de la SD
2. Si hekate n'est pas déjà installé, le télécharger séparément
3. Injecter hekate via RCM
4. Sélectionner "Switch Linux" dans le menu hekate

## Dépannage

### QEMU ne démarre pas

```bash
# Vérifier que KVM est disponible
ls -la /dev/kvm

# Si pas de KVM, utiliser l'émulation (plus lent)
./bin/autobuild --image switch/default --no-kvm
```

### Erreur de montage loop

```bash
# Vérifier les loop devices disponibles
losetup -a

# Libérer les loop devices
sudo losetup -D
```

### Espace disque insuffisant

```bash
# Utiliser un dossier temporaire sur un autre disque
TMPDIR=/mnt/bigdisk/tmp ./bin/autobuild --image switch/default
```