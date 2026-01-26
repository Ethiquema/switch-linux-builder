# Architecture Switch Linux Builder

## Vue d'ensemble

Ce projet crée des images Linux bootables pour Nintendo Switch via Hekate, avec :
- **rootfs** : SquashFS immutable (lecture seule)
- **homefs** : ext4 dynamique avec expansion automatique
- **Accès SD** : La partition FAT32 de la SD est accessible depuis Linux

## Structure de la carte SD (output)

```
SD Card (FAT32, label: hos_data)
│
├── bootloader/                          # Hekate bootloader
│   ├── hekate_ipl.ini                   # Configuration principale
│   ├── ini/
│   │   └── switch-linux.ini             # Config boot pour notre distro
│   └── sys/
│       └── l4t/                         # Firmware L4T
│           ├── bpmpfw_b01.bin
│           ├── mtc_tbl_b01.bin
│           ├── sc7entry.bin
│           ├── sc7exit.bin
│           └── sc7exit_b01.bin
│
├── switchroot/
│   └── switch-linux/                    # Fichiers boot de notre distro
│       ├── boot.scr                     # Script U-Boot
│       ├── coreboot.rom                 # Payload coreboot
│       ├── Image                        # Kernel Linux
│       ├── tegra210-icosa.dtb           # Device Tree
│       └── initramfs.img                # Initramfs custom
│
├── linux_img/
│   └── <nom_image>/                     # Une distro = un dossier
│       ├── rootfs/
│       │   ├── rootfs.squashfs.part000  # SquashFS part 1 (max 3.9 Go)
│       │   ├── rootfs.squashfs.part001  # SquashFS part 2 (si nécessaire)
│       │   └── ...
│       └── homefs/
│           ├── homefs.ext4.part000      # ext4 part 1 (1.9 Go)
│           ├── homefs.ext4.part001      # ext4 part 2 (créé dynamiquement)
│           └── ...
│
├── atmosphere/                          # Coexistence avec CFW (optionnel)
├── Nintendo/                            # Données Switch
└── ...                                  # Autres fichiers SD accessibles
```

## Boot Chain

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. RCM Mode (Recovery Mode)                                         │
│    └── Exploit triggered (fusée gelée, etc.)                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Hekate Bootloader                                                │
│    ├── Lit bootloader/hekate_ipl.ini                                │
│    ├── Affiche menu de sélection                                    │
│    └── Charge le payload sélectionné                                │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Coreboot                                                         │
│    └── Initialise le hardware, charge U-Boot                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. U-Boot                                                           │
│    ├── Monte la SD (FAT32)                                          │
│    ├── Exécute switchroot/switch-linux/boot.scr                     │
│    ├── Charge Image (kernel) + tegra210-icosa.dtb                   │
│    ├── Charge initramfs.img                                         │
│    └── Boot le kernel avec arguments                                │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. Initramfs (notre script custom)                                  │
│    ├── Monte SD FAT32 sur /sd                                       │
│    ├── Assemble les parts rootfs en loop device                     │
│    ├── Monte le SquashFS assemblé sur /rootfs (read-only)           │
│    ├── Assemble les parts homefs en loop device                     │
│    ├── Monte le ext4 assemblé sur /rootfs/home                      │
│    ├── Crée overlay pour /etc, /var (écriture sur homefs)           │
│    └── switch_root vers /rootfs                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. Système Linux                                                    │
│    ├── /          → SquashFS (read-only)                            │
│    ├── /home      → ext4 homefs (read-write)                        │
│    ├── /etc       → overlay (base squashfs + delta sur homefs)      │
│    ├── /var       → overlay (base squashfs + delta sur homefs)      │
│    └── /sd        → SD card FAT32 (read-write)                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Système de fichiers partitionnés

### Pourquoi des parts de fichiers ?

FAT32 a une limite de 4 Go par fichier. Pour contourner cette limite :
- **rootfs** : découpé en parts de max 3.9 Go
- **homefs** : parts de 1.9 Go (pour permettre l'expansion)

### Assemblage des parts

L'initramfs assemble les parts en un seul block device virtuel :

```bash
# Exemple pour rootfs (3 parts)
losetup /dev/loop0 /sd/linux_img/mon_image/rootfs/rootfs.squashfs.part000
losetup /dev/loop1 /sd/linux_img/mon_image/rootfs/rootfs.squashfs.part001
losetup /dev/loop2 /sd/linux_img/mon_image/rootfs/rootfs.squashfs.part002

# Assemblage avec dm-linear (device mapper)
dmsetup create rootfs-combined << EOF
0 $(sectors_part0) linear /dev/loop0 0
$(sectors_part0) $(sectors_part1) linear /dev/loop1 0
$(sectors_part0+part1) $(sectors_part2) linear /dev/loop2 0
EOF

# Monte le squashfs assemblé
mount -t squashfs /dev/mapper/rootfs-combined /rootfs
```

### Expansion dynamique du homefs

Le système homefs s'étend automatiquement pendant l'utilisation :

```
┌────────────────────────────────────────────────────────────────────┐
│                    Service homefs-expand.service                    │
└────────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│ 1. Surveille  │     │ 2. Si espace    │     │ 3. Resize2fs       │
│    l'espace   │────▶│    < 1.9GO libre  │────▶│    en live          │
│    disque     │     │    créer part   │     │                     │
└───────────────┘     └─────────────────┘     └─────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Nouvelle part   │
                    │ homefs.ext4.    │
                    │ partXXX (1.9Go) │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ losetup + dm    │
                    │ étend le volume │
                    │ en live         │
                    └─────────────────┘
```

**Processus détaillé :**

1. **Surveillance** : Un service systemd surveille `/home` toutes les 30 secondes
2. **Détection** : Si espace libre < 1.9GO (ou < 500 Mo)
3. **Création** : Crée un nouveau fichier `homefs.ext4.partXXX` de 1.9 Go
4. **Attachement** : `losetup` pour créer un nouveau loop device
5. **Extension dm** : `dmsetup reload` pour étendre le volume
6. **Resize** : `resize2fs /dev/mapper/homefs-combined` en live

## Configuration Hekate

### bootloader/ini/switch-linux.ini

```ini
[Switch Linux]
l4t=1
boot_prefixes=/switchroot/switch-linux/
id=SWLINUX
icon=bootloader/res/switch-linux.bmp

; Hardware options
uart_port=0
usb3_enable=0
jc_rail_disable=0

; Boot arguments
bootargs_extra=quiet splash
```

### Support Multi-boot

Plusieurs distributions peuvent coexister :

```
linux_img/
├── emulation-station/     # Image principale avec ES
│   ├── rootfs/
│   └── homefs/
├── desktop/               # Image avec XFCE
│   ├── rootfs/
│   └── homefs/
└── minimal/               # Image minimale
    ├── rootfs/
    └── homefs/
```

Chaque image a son entrée dans `bootloader/ini/` :

```ini
# bootloader/ini/switch-linux-es.ini
[Switch Linux ES]
l4t=1
boot_prefixes=/switchroot/switch-linux/
bootargs_extra=swlinux.image=emulation-station

# bootloader/ini/switch-linux-desktop.ini
[Switch Linux Desktop]
l4t=1
boot_prefixes=/switchroot/switch-linux/
bootargs_extra=swlinux.image=desktop
```

L'initramfs lit `swlinux.image=` depuis cmdline pour choisir le dossier.

## Points de montage finaux

| Chemin | Type | Source | Mode |
|--------|------|--------|------|
| `/` | SquashFS | rootfs.squashfs.part* assemblé | read-only |
| `/home` | ext4 | homefs.ext4.part* assemblé | read-write |
| `/etc` | OverlayFS | base=squashfs, upper=homefs/.overlays/etc | read-write |
| `/var` | OverlayFS | base=squashfs, upper=homefs/.overlays/var | read-write |
| `/sd` | FAT32 | Carte SD complète | read-write |
| `/sd/linux_img` | - | Accès aux images Linux | read-write |

## Kernel et Drivers

### Source du kernel

Kernel L4T (Linux for Tegra) depuis le repo Switchroot :
- Base : Ubuntu L4T packages
- Drivers Tegra X1 (Maxwell GPU)
- Support Joy-Con
- Gestion thermique dock/portable

### Packages kernel à installer

```bash
# Depuis le PPA Switchroot
apt install linux-image-l4t-switch linux-headers-l4t-switch
apt install nvidia-l4t-core nvidia-l4t-firmware
```

## Services spécifiques Switch

### base (obligatoire)
- Kernel L4T + firmware Tegra
- Joy-Con drivers
- Gestion thermique (dock detection)
- zram 50%
- Accès SD (/sd)

### Pas de unattended-upgrades
- Retiré car non pertinent sur console portable

## Différences avec rpi-dev

| Aspect | rpi-dev | switch-linux-builder |
|--------|---------|---------------------|
| Image finale | 1 fichier .img | Dossier avec parts |
| Rootfs | ext4 (read-write) | SquashFS (read-only) |
| Home | Inclus dans rootfs | Séparé, ext4 dynamique |
| Boot | RaspiOS boot partition | Hekate + coreboot + U-Boot |
| Kernel | RaspiOS packages | L4T Switchroot packages |
| Merge | merge-debian-raspios.sh | Non applicable |
| PiShrink | Oui | Non (squashfs déjà compressé) |
| Multi-boot | Non | Oui via Hekate |

## Structure du repo

```
switch-linux-builder/
├── bin/
│   ├── autobuild                    # Script principal de build
│   ├── create-rootfs.sh             # Crée le squashfs
│   ├── create-homefs.sh             # Crée le homefs initial
│   └── split-image.sh               # Découpe en parts
│
├── images/
│   └── switch/
│       ├── config.sh                # Configuration de base
│       ├── initramfs/               # Sources initramfs custom
│       │   ├── init                 # Script init principal
│       │   └── scripts/
│       │       ├── mount-rootfs.sh
│       │       ├── mount-homefs.sh
│       │       └── expand-homefs.sh
│       └── services/
│           ├── base/                # Kernel L4T, Joy-Con, zram
│           ├── default/             # Wayland + cage + EmulationStation
│           ├── emulations/          # RetroArch, Dolphin, Azahar
│           ├── tabs/                # Phosh
│           ├── desktop/             # X11 + XFCE
│           ├── android/             # Waydroid
│           └── kodi/                # Kodi
│
├── output/                          # Images générées
│   └── switch-linux-<date>/
│       ├── bootloader/
│       ├── switchroot/
│       └── linux_img/
│
├── docs/
│   └── ARCHITECTURE.md              # Ce fichier
│
└── PROMPTE.MD                       # Spécifications projet
```
