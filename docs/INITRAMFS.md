# Initramfs Switch Linux

## Vue d'ensemble

L'initramfs est le cœur du système de boot. Il assemble les fichiers partitionnés et monte le système de fichiers final.

## Fonctionnalités principales

1. Monte la SD card FAT32
2. Lit le paramètre `swlinux.image=` pour choisir l'image
3. Assemble les parts rootfs en un seul block device
4. Monte le SquashFS comme rootfs (read-only)
5. Assemble les parts homefs en un seul block device
6. Monte l'ext4 comme /home (read-write)
7. Configure les overlays pour /etc et /var
8. Effectue le switch_root

## Structure de l'initramfs

```
initramfs/
├── init                           # Script principal (PID 1)
├── bin/
│   ├── busybox                    # Utilitaires de base
│   ├── losetup                    # Gestion loop devices
│   └── dmsetup                    # Device mapper
├── sbin/
│   ├── mount
│   ├── umount
│   └── switch_root
├── lib/
│   └── modules/                   # Modules kernel nécessaires
│       ├── loop.ko
│       ├── dm-mod.ko
│       ├── squashfs.ko
│       ├── ext4.ko
│       ├── fat.ko
│       ├── vfat.ko
│       ├── nls_cp437.ko
│       └── overlay.ko
└── scripts/
    ├── mount-sd.sh                # Monte la SD
    ├── assemble-parts.sh          # Assemble les parts en dm device
    ├── mount-rootfs.sh            # Monte le squashfs
    ├── mount-homefs.sh            # Monte l'ext4 homefs
    └── setup-overlays.sh          # Configure /etc et /var overlays
```

## Script init principal

```bash
#!/bin/busybox sh
# /init - Premier processus (PID 1)

# Monter les systèmes de fichiers virtuels
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Charger les modules nécessaires
modprobe loop
modprobe dm-mod
modprobe squashfs
modprobe ext4
modprobe vfat
modprobe overlay

# Créer les points de montage
mkdir -p /sd /rootfs /home /newroot

# Parse cmdline pour trouver l'image
IMAGE_NAME="default"
for param in $(cat /proc/cmdline); do
    case $param in
        swlinux.image=*)
            IMAGE_NAME="${param#swlinux.image=}"
            ;;
    esac
done

echo "Booting image: $IMAGE_NAME"

# Étape 1: Monter la SD
. /scripts/mount-sd.sh

# Étape 2: Assembler et monter rootfs
. /scripts/mount-rootfs.sh "$IMAGE_NAME"

# Étape 3: Assembler et monter homefs
. /scripts/mount-homefs.sh "$IMAGE_NAME"

# Étape 4: Configurer les overlays
. /scripts/setup-overlays.sh

# Étape 5: Préparer le switch_root
mkdir -p /rootfs/sd
mount --move /sd /rootfs/sd

# Cleanup
umount /proc /sys
rm -rf /scripts /bin /sbin /lib

# Switch vers le vrai rootfs
exec switch_root /rootfs /sbin/init
```

## Scripts détaillés

### mount-sd.sh

```bash
#!/bin/busybox sh
# Monte la carte SD FAT32

SD_DEV="/dev/mmcblk0p1"
SD_MOUNT="/sd"

echo "Mounting SD card..."

# Attendre que le device soit disponible
attempts=0
while [ ! -b "$SD_DEV" ] && [ $attempts -lt 30 ]; do
    sleep 0.2
    attempts=$((attempts + 1))
done

if [ ! -b "$SD_DEV" ]; then
    echo "ERROR: SD card not found!"
    exec sh
fi

mount -t vfat -o rw,utf8 "$SD_DEV" "$SD_MOUNT"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to mount SD card!"
    exec sh
fi

echo "SD card mounted on $SD_MOUNT"
```

### mount-rootfs.sh (assemble-parts.sh intégré)

```bash
#!/bin/busybox sh
# Assemble les parts rootfs et monte le squashfs

IMAGE_NAME="$1"
ROOTFS_DIR="/sd/linux_img/$IMAGE_NAME/rootfs"
ROOTFS_MOUNT="/rootfs"

echo "Assembling rootfs for image: $IMAGE_NAME"

# Vérifie que le dossier existe
if [ ! -d "$ROOTFS_DIR" ]; then
    echo "ERROR: Image directory not found: $ROOTFS_DIR"
    exec sh
fi

# Compte les parts
PARTS=$(ls "$ROOTFS_DIR"/rootfs.squashfs.part* 2>/dev/null | sort)
PART_COUNT=$(echo "$PARTS" | wc -w)

if [ "$PART_COUNT" -eq 0 ]; then
    echo "ERROR: No rootfs parts found!"
    exec sh
fi

echo "Found $PART_COUNT rootfs part(s)"

# Si une seule part, montage direct
if [ "$PART_COUNT" -eq 1 ]; then
    SINGLE_PART=$(echo "$PARTS" | head -1)
    losetup /dev/loop0 "$SINGLE_PART"
    mount -t squashfs -o ro /dev/loop0 "$ROOTFS_MOUNT"
    echo "Single part rootfs mounted"
    return 0
fi

# Plusieurs parts: utiliser device-mapper
LOOP_NUM=0
DM_TABLE=""
OFFSET=0

for PART in $PARTS; do
    # Créer loop device
    LOOP_DEV="/dev/loop$LOOP_NUM"
    losetup "$LOOP_DEV" "$PART"

    # Calculer la taille en secteurs (512 bytes)
    SIZE_BYTES=$(stat -c %s "$PART")
    SIZE_SECTORS=$((SIZE_BYTES / 512))

    # Ajouter à la table dm
    DM_TABLE="$DM_TABLE$OFFSET $SIZE_SECTORS linear $LOOP_DEV 0\n"

    OFFSET=$((OFFSET + SIZE_SECTORS))
    LOOP_NUM=$((LOOP_NUM + 1))
done

# Créer le device mapper combiné
echo -e "$DM_TABLE" | dmsetup create rootfs-combined

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create dm device!"
    exec sh
fi

# Monter le squashfs
mount -t squashfs -o ro /dev/mapper/rootfs-combined "$ROOTFS_MOUNT"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to mount squashfs!"
    exec sh
fi

echo "Rootfs mounted successfully"
```

### mount-homefs.sh

```bash
#!/bin/busybox sh
# Assemble les parts homefs et monte l'ext4

IMAGE_NAME="$1"
HOMEFS_DIR="/sd/linux_img/$IMAGE_NAME/homefs"
HOMEFS_MOUNT="/rootfs/home"

echo "Assembling homefs for image: $IMAGE_NAME"

# Vérifie que le dossier existe
if [ ! -d "$HOMEFS_DIR" ]; then
    echo "Creating initial homefs directory..."
    mkdir -p "$HOMEFS_DIR"
fi

# Compte les parts
PARTS=$(ls "$HOMEFS_DIR"/homefs.ext4.part* 2>/dev/null | sort)
PART_COUNT=$(echo "$PARTS" | wc -w)

# Si aucune part, créer la première
if [ "$PART_COUNT" -eq 0 ]; then
    echo "Creating initial homefs partition (1.9GB)..."
    FIRST_PART="$HOMEFS_DIR/homefs.ext4.part000"

    # Créer fichier sparse de 1.9GB
    dd if=/dev/zero of="$FIRST_PART" bs=1M count=0 seek=1900 2>/dev/null

    # Formater en ext4
    losetup /dev/loop10 "$FIRST_PART"
    mkfs.ext4 -q -L SWLINUX_HOME /dev/loop10
    losetup -d /dev/loop10

    PARTS="$FIRST_PART"
    PART_COUNT=1
fi

echo "Found $PART_COUNT homefs part(s)"

# Stocker le nombre de loop devices utilisés pour l'expansion future
LOOP_START=10

# Si une seule part, montage direct
if [ "$PART_COUNT" -eq 1 ]; then
    SINGLE_PART=$(echo "$PARTS" | head -1)
    losetup /dev/loop$LOOP_START "$SINGLE_PART"
    mkdir -p "$HOMEFS_MOUNT"
    mount -t ext4 /dev/loop$LOOP_START "$HOMEFS_MOUNT"

    # Sauvegarder les infos pour le service d'expansion
    echo "HOMEFS_DIR=$HOMEFS_DIR" > /rootfs/run/homefs-info
    echo "LOOP_START=$LOOP_START" >> /rootfs/run/homefs-info
    echo "PART_COUNT=1" >> /rootfs/run/homefs-info
    echo "DEVICE=/dev/loop$LOOP_START" >> /rootfs/run/homefs-info

    echo "Single part homefs mounted"
    return 0
fi

# Plusieurs parts: utiliser device-mapper
LOOP_NUM=$LOOP_START
DM_TABLE=""
OFFSET=0

for PART in $PARTS; do
    LOOP_DEV="/dev/loop$LOOP_NUM"
    losetup "$LOOP_DEV" "$PART"

    SIZE_BYTES=$(stat -c %s "$PART")
    SIZE_SECTORS=$((SIZE_BYTES / 512))

    DM_TABLE="$DM_TABLE$OFFSET $SIZE_SECTORS linear $LOOP_DEV 0\n"

    OFFSET=$((OFFSET + SIZE_SECTORS))
    LOOP_NUM=$((LOOP_NUM + 1))
done

echo -e "$DM_TABLE" | dmsetup create homefs-combined

mkdir -p "$HOMEFS_MOUNT"
mount -t ext4 /dev/mapper/homefs-combined "$HOMEFS_MOUNT"

# Sauvegarder les infos pour le service d'expansion
echo "HOMEFS_DIR=$HOMEFS_DIR" > /rootfs/run/homefs-info
echo "LOOP_START=$LOOP_START" >> /rootfs/run/homefs-info
echo "LOOP_CURRENT=$LOOP_NUM" >> /rootfs/run/homefs-info
echo "PART_COUNT=$PART_COUNT" >> /rootfs/run/homefs-info
echo "DEVICE=/dev/mapper/homefs-combined" >> /rootfs/run/homefs-info
echo "DM_OFFSET=$OFFSET" >> /rootfs/run/homefs-info

echo "Homefs mounted successfully"
```

### setup-overlays.sh

```bash
#!/bin/busybox sh
# Configure les overlays pour /etc et /var

OVERLAY_BASE="/rootfs/home/.overlays"

echo "Setting up overlays..."

# Créer les dossiers overlay sur homefs
mkdir -p "$OVERLAY_BASE/etc/upper" "$OVERLAY_BASE/etc/work"
mkdir -p "$OVERLAY_BASE/var/upper" "$OVERLAY_BASE/var/work"

# Sauvegarder /etc et /var originaux
mkdir -p /rootfs/.squashfs-base/etc /rootfs/.squashfs-base/var
mount --bind /rootfs/etc /rootfs/.squashfs-base/etc
mount --bind /rootfs/var /rootfs/.squashfs-base/var

# Monter overlay pour /etc
mount -t overlay overlay \
    -o lowerdir=/rootfs/.squashfs-base/etc,upperdir=$OVERLAY_BASE/etc/upper,workdir=$OVERLAY_BASE/etc/work \
    /rootfs/etc

# Monter overlay pour /var
mount -t overlay overlay \
    -o lowerdir=/rootfs/.squashfs-base/var,upperdir=$OVERLAY_BASE/var/upper,workdir=$OVERLAY_BASE/var/work \
    /rootfs/var

echo "Overlays configured"
```

## Service d'expansion homefs (post-boot)

Ce service tourne dans le système final, pas dans l'initramfs.

### /etc/systemd/system/homefs-expand.service

```ini
[Unit]
Description=Homefs Dynamic Expansion Service
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/homefs-expand-daemon.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### /usr/local/bin/homefs-expand-daemon.sh

```bash
#!/bin/bash
# Daemon de surveillance et expansion du homefs

source /run/homefs-info

MIN_FREE_BYTES=$((1900 * 1024 * 1024))  # 1.9 Go minimum libre
PART_SIZE_MB=1900

while true; do
    # Vérifier l'espace libre
    FREE_BYTES=$(df --output=avail -B1 /home | tail -1)

    if [ "$FREE_BYTES" -lt "$MIN_FREE_BYTES" ]; then
        echo "Low space detected: ${FREE_BYTES} bytes free"

        # Calculer le numéro de la prochaine part
        NEXT_PART_NUM=$(printf "%03d" $PART_COUNT)
        NEW_PART="$HOMEFS_DIR/homefs.ext4.part$NEXT_PART_NUM"

        echo "Creating new partition: $NEW_PART"

        # Créer nouveau fichier sparse
        dd if=/dev/zero of="$NEW_PART" bs=1M count=0 seek=$PART_SIZE_MB 2>/dev/null

        # Attacher nouveau loop device
        if [ -z "$LOOP_CURRENT" ]; then
            LOOP_CURRENT=$((LOOP_START + 1))
        fi
        NEW_LOOP="/dev/loop$LOOP_CURRENT"
        losetup "$NEW_LOOP" "$NEW_PART"

        # Calculer les nouveaux secteurs
        NEW_SIZE_BYTES=$(stat -c %s "$NEW_PART")
        NEW_SIZE_SECTORS=$((NEW_SIZE_BYTES / 512))

        if [ "$DEVICE" = "/dev/mapper/homefs-combined" ]; then
            # Étendre le device mapper existant
            CURRENT_TABLE=$(dmsetup table homefs-combined)
            NEW_LINE="$DM_OFFSET $NEW_SIZE_SECTORS linear $NEW_LOOP 0"

            echo -e "$CURRENT_TABLE\n$NEW_LINE" | dmsetup reload homefs-combined
            dmsetup resume homefs-combined

            DM_OFFSET=$((DM_OFFSET + NEW_SIZE_SECTORS))
        else
            # Premier ajout: convertir loop simple en device mapper
            CURRENT_LOOP="$DEVICE"
            CURRENT_SIZE=$(blockdev --getsz "$CURRENT_LOOP")

            # Créer la table dm
            DM_TABLE="0 $CURRENT_SIZE linear $CURRENT_LOOP 0"
            DM_TABLE="$DM_TABLE\n$CURRENT_SIZE $NEW_SIZE_SECTORS linear $NEW_LOOP 0"

            # Démonter, créer dm, remonter
            umount /home
            echo -e "$DM_TABLE" | dmsetup create homefs-combined
            mount -t ext4 /dev/mapper/homefs-combined /home

            DEVICE="/dev/mapper/homefs-combined"
            DM_OFFSET=$((CURRENT_SIZE + NEW_SIZE_SECTORS))
        fi

        # Étendre le système de fichiers
        resize2fs "$DEVICE"

        # Mettre à jour les infos
        PART_COUNT=$((PART_COUNT + 1))
        LOOP_CURRENT=$((LOOP_CURRENT + 1))

        cat > /run/homefs-info << EOF
HOMEFS_DIR=$HOMEFS_DIR
LOOP_START=$LOOP_START
LOOP_CURRENT=$LOOP_CURRENT
PART_COUNT=$PART_COUNT
DEVICE=$DEVICE
DM_OFFSET=$DM_OFFSET
EOF

        echo "Homefs expanded successfully. New size: $(df -h /home | tail -1 | awk '{print $2}')"
    fi

    sleep 30
done
```

## Génération de l'initramfs

### Script de création

```bash
#!/bin/bash
# bin/create-initramfs.sh

WORKDIR=$(mktemp -d)
KERNEL_VERSION="5.10.xxx-l4t"  # Version du kernel L4T

echo "Creating initramfs in $WORKDIR"

# Structure de base
mkdir -p "$WORKDIR"/{bin,sbin,lib/modules,scripts,proc,sys,dev,sd,rootfs,newroot}

# Copier busybox
cp /bin/busybox "$WORKDIR/bin/"
for cmd in sh mount umount mkdir cat echo ls stat dd mkfs.ext4 sleep; do
    ln -s busybox "$WORKDIR/bin/$cmd"
done

# Copier les outils nécessaires
cp /sbin/losetup "$WORKDIR/sbin/"
cp /sbin/dmsetup "$WORKDIR/sbin/"
cp /sbin/switch_root "$WORKDIR/sbin/"

# Copier les modules kernel
MODULES="loop dm-mod squashfs ext4 fat vfat nls_cp437 overlay"
for mod in $MODULES; do
    modpath=$(find /lib/modules/$KERNEL_VERSION -name "${mod}.ko*" | head -1)
    if [ -n "$modpath" ]; then
        cp "$modpath" "$WORKDIR/lib/modules/"
    fi
done

# Copier les scripts
cp images/switch/initramfs/init "$WORKDIR/init"
cp images/switch/initramfs/scripts/* "$WORKDIR/scripts/"
chmod +x "$WORKDIR/init" "$WORKDIR/scripts/"*

# Créer l'initramfs
cd "$WORKDIR"
find . | cpio -H newc -o | gzip > /tmp/initramfs.img

echo "Initramfs created: /tmp/initramfs.img"
rm -rf "$WORKDIR"
```

## Dépannage

### Mode debug

Ajouter `swlinux.debug=1` à la cmdline pour activer les messages détaillés et un shell de secours en cas d'erreur.

### Shell de secours

Si une erreur survient, le script init lance un shell busybox :
```bash
exec sh
```

### Vérifier les montages

Depuis le shell de secours :
```bash
cat /proc/mounts
ls /dev/loop*
dmsetup ls
```