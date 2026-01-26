#!/bin/bash
set -e

echo "====== Running services first-boot setup... ======"

# Wait for SD card to be mounted
timeout=60
counter=0
while [ ! -d "/sd" ] || ! mountpoint -q /sd 2>/dev/null; do
    sleep 1
    counter=$((counter + 1))
    if [ $counter -ge $timeout ]; then
        echo "Warning: SD card not mounted after ${timeout}s, continuing anyway..."
        break
    fi
done

if mountpoint -q /sd 2>/dev/null; then
    echo "SD card mounted at /sd"
fi

# ====== SERVICES INITIALIZATION ======

# ====== END SERVICES INITIALIZATION ======

echo "====== Services first-boot setup complete! ======"

# Disable this service (one-shot)
systemctl disable services-first-boot.service

exit 0
