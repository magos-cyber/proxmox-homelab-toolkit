#!/bin/bash
# Backup All VMs and LXC
# Creates snapshots of all running VMs and containers

set -euo pipefail

NODE="${NODE:-pve}"
STORAGE="${STORAGE:-local}"
MODE="${MODE:-snapshot}"
RETENTION="${RETENTION:-7}"
DATE=$(date +%Y%m%d-%H%M%S)

echo "=== Proxmox Backup All ==="
echo "Node: $NODE"
echo "Storage: $STORAGE"
echo "Mode: $MODE"
echo "Retention: ${RETENTION} days"
echo "Date: $DATE"
echo ""

# Backup VMs
echo "=== Backing up VMs ==="
qm list | tail -n +2 | awk '{print $1}' | while read vmid; do
    echo "Backing up VM $vmid..."
    vzdump "$vmid"         --storage "$STORAGE"         --mode "$MODE"         --compress zstd         --quiet 1         --notes-template "automated-backup-{{ctime}}"
done

# Backup LXC
echo ""
echo "=== Backing up LXC Containers ==="
pct list | tail -n +2 | awk '{print $1}' | while read ctid; do
    echo "Backing up CT $ctid..."
    vzdump "$ctid"         --storage "$STORAGE"         --mode "$MODE"         --compress zstd         --quiet 1         --notes-template "automated-backup-{{ctime}}"
done

# Cleanup old backups
echo ""
echo "=== Cleaning up old backups ==="
find /var/lib/vz/dump -name "vzdump-*" -mtime +${RETENTION} -delete 2>/dev/null || true

echo ""
echo "Backup complete!"
