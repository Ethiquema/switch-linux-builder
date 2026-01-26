# Services Switch Linux Builder

## Vue d'ensemble

Les services sont modulaires et composables. Chaque service ajoute des fonctionnalités spécifiques à l'image finale.

## Architecture des Display Managers

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EmulationStation                              │
│                    (Interface principale)                            │
│                                                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │Emulators│  │  Phosh  │  │  XFCE   │  │Waydroid │  │  Kodi   │   │
│  │RetroArch│  │ (tabs)  │  │(desktop)│  │(android)│  │ (kodi)  │   │
│  │ Dolphin │  │         │  │         │  │         │  │         │   │
│  │ Azahar  │  │         │  │         │  │         │  │         │   │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘   │
│       │            │            │            │            │         │
│       │      Menu Select - Lancement depuis ES                      │
│       │            │            │            │            │         │
└───────┼────────────┼────────────┼────────────┼────────────┼─────────┘
        │            │            │            │            │
        ▼            ▼            ▼            ▼            ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                     Retour automatique                       │
   │              à EmulationStation à la fermeture               │
   └─────────────────────────────────────────────────────────────┘
```

## Principe de fonctionnement

1. **EmulationStation** est toujours le point d'entrée
2. Les autres DM se lancent depuis le menu Select de ES
3. À la fermeture d'un DM, ES est automatiquement relancé
4. **Aucun DM en arrière-plan** sauf ES derrière les émulateurs
5. **Wayland prioritaire** sur X11
6. **Environnement minimal** : cage si nécessaire, pas de DE complet en tâche de fond

---

## Service : base

**Obligatoire** - Inclus automatiquement dans toutes les images.

### Fonctionnalités
- Kernel L4T (Linux for Tegra) depuis Switchroot
- Drivers Tegra X1 / Maxwell GPU
- Support Joy-Con (Bluetooth + rail)
- Gestion thermique (dock/portable)
- zram 50% de la RAM
- Montage SD sur `/sd`
- NetworkManager
- Service d'expansion homefs

### Packages installés
```bash
# Kernel et firmware
linux-image-l4t-switch
linux-headers-l4t-switch
nvidia-l4t-core
nvidia-l4t-firmware
nvidia-l4t-gbm

# Système
systemd
networkmanager
zram-tools
bluez
```

### Configuration zram
```ini
# /etc/default/zramswap
ALGO=zstd
PERCENT=50
```

### Ce qui est retiré
- `unattended-upgrades` (non pertinent sur console)

---

## Service : default

**Dépend de** : base

Interface principale au démarrage.

### Stack graphique
```
Wayland → cage (compositeur minimal) → EmulationStation
```

### Packages installés
```bash
# Wayland
wayland-utils
weston
cage

# XWayland (pour apps X11)
xwayland

# EmulationStation
emulationstation-de
```

### Service systemd
```ini
# /etc/systemd/system/emulationstation.service
[Unit]
Description=EmulationStation
After=graphical.target

[Service]
Type=simple
User=switch
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/cage -s -- emulationstation
Restart=always
RestartSec=2

[Install]
WantedBy=graphical.target
```

### Script de lancement DM
```bash
#!/bin/bash
# /usr/local/bin/switch-dm

DM=$1

# Arrête EmulationStation
systemctl stop emulationstation.service

case $DM in
    phosh)
        systemctl start phosh.service
        ;;
    xfce)
        systemctl start xfce.service
        ;;
    waydroid)
        systemctl start waydroid-session.service
        ;;
    kodi)
        systemctl start kodi.service
        ;;
esac

# Attend la fin du DM puis relance ES
while systemctl is-active --quiet $DM.service; do
    sleep 1
done

systemctl start emulationstation.service
```

---

## Service : emulations

**Dépend de** : base, default

Émulateurs et cores RetroArch.

### Packages installés
```bash
# RetroArch
retroarch
retroarch-assets

# Tous les cores SAUF citra et dolphin (standalone)
libretro-*
!libretro-citra
!libretro-dolphin

# Standalone (meilleures performances sur Switch)
dolphin-emu          # GameCube / Wii
azahar               # 3DS (fork Citra maintenu)
```

### Configuration RetroArch
```ini
# /home/switch/.config/retroarch/retroarch.cfg
video_driver = "vulkan"
menu_driver = "ozone"
input_joypad_driver = "sdl2"

# Optimisations Switch
video_vsync = "true"
video_max_swapchain_images = "2"
```

### Intégration EmulationStation
Les émulateurs sont lancés depuis ES qui reste en arrière-plan :
```xml
<!-- /home/switch/.emulationstation/es_systems.cfg -->
<system>
    <name>gc</name>
    <fullname>Nintendo GameCube</fullname>
    <path>/home/switch/roms/gc</path>
    <extension>.iso .gcm .gcz .rvz</extension>
    <command>dolphin-emu -b -e %ROM%</command>
    <platform>gc</platform>
</system>
```

---

## Service : tabs

**Dépend de** : base

Interface tactile mobile (Phosh).

### Stack graphique
```
Wayland → phoc (compositeur) → Phosh (shell)
```

### Packages installés
```bash
phosh
phoc
squeekboard        # Clavier virtuel
gnome-calls        # (optionnel, peut être retiré)
gnome-contacts
```

### Service systemd
```ini
# /etc/systemd/system/phosh.service
[Unit]
Description=Phosh Mobile Shell
Conflicts=emulationstation.service

[Service]
Type=simple
User=switch
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/phosh
Restart=on-failure

[Install]
WantedBy=graphical.target
```

### Raccourci retour ES
Bouton physique ou geste pour fermer Phosh et retourner à ES.

---

## Service : desktop

**Dépend de** : base

Bureau traditionnel XFCE.

### Stack graphique
```
X11 → XFCE4
```

**Note** : X11 utilisé car XFCE n'a pas encore de support Wayland natif complet.

### Packages installés
```bash
xorg
xfce4
xfce4-goodies
lightdm            # DM minimal, auto-login
```

### Configuration LightDM
```ini
# /etc/lightdm/lightdm.conf
[Seat:*]
autologin-user=switch
autologin-session=xfce
```

### Service systemd
```ini
# /etc/systemd/system/xfce.service
[Unit]
Description=XFCE Desktop
Conflicts=emulationstation.service

[Service]
Type=simple
User=switch
ExecStart=/usr/bin/startxfce4
Restart=on-failure

[Install]
WantedBy=graphical.target
```

### Raccourci retour ES
- Raccourci clavier configurable
- Script dans le menu XFCE

---

## Service : android

**Dépend de** : base

Android via Waydroid.

### Stack graphique
```
Wayland → cage → Waydroid (plein écran)
```

### Packages installés
```bash
waydroid
lxc
python3-gbinder
```

### Premier démarrage
Service qui configure Android automatiquement au premier boot :

```bash
#!/bin/bash
# /usr/local/bin/waydroid-first-boot.sh

if [ ! -f /home/switch/.waydroid-initialized ]; then
    # Initialise Waydroid
    waydroid init -s GAPPS

    # Télécharge la dernière version GApps
    # (stocké dans homefs)

    touch /home/switch/.waydroid-initialized
fi
```

### Service systemd
```ini
# /etc/systemd/system/waydroid-session.service
[Unit]
Description=Waydroid Session
Conflicts=emulationstation.service
After=waydroid-first-boot.service

[Service]
Type=simple
User=switch
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/cage -s -- waydroid show-full-ui
Restart=on-failure

[Install]
WantedBy=graphical.target
```

---

## Service : kodi

**Dépend de** : base

Media center Kodi.

### Stack graphique
```
Wayland → cage → Kodi (GBM/Wayland)
```

### Packages installés
```bash
kodi
kodi-inputstream-adaptive
kodi-pvr-*          # PVR addons (optionnel)
```

### Service systemd
```ini
# /etc/systemd/system/kodi.service
[Unit]
Description=Kodi Media Center
Conflicts=emulationstation.service

[Service]
Type=simple
User=switch
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/cage -s -- kodi
Restart=on-failure

[Install]
WantedBy=graphical.target
```

### Raccourci retour ES
- Bouton "Quitter" dans Kodi → ferme cage → ES relancé automatiquement

---

## Composition des services

### Image minimale (émulation uniquement)
```bash
./bin/autobuild --services "base default emulations"
```

### Image complète
```bash
./bin/autobuild --services "base default emulations tabs desktop android kodi"
```

### Dépendances automatiques

```
emulations → default → base
tabs → base
desktop → base
android → base
kodi → base
```

Le service `base` est toujours inclus automatiquement.

---

## Gestion des conflits

### Règles
1. Un seul DM actif à la fois (Conflicts= dans systemd)
2. EmulationStation est le DM par défaut
3. Les autres DM sont lancés à la demande
4. Retour automatique à ES quand un DM se termine

### Flow de transition
```
ES running
    │
    ├── User sélectionne "Phosh" dans menu
    │       │
    │       ▼
    │   systemctl stop emulationstation
    │   systemctl start phosh
    │       │
    │       ▼
    │   Phosh running (ES stopped)
    │       │
    │       ├── User ferme Phosh
    │       │       │
    │       │       ▼
    │       │   systemctl start emulationstation
    │       │       │
    │       │       ▼
    │       │   ES running (retour)
```
