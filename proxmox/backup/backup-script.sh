#!/usr/bin/env bash
# backup-script.sh — Automated Proxmox VM/LXC backup
# Usage: sudo bash backup-script.sh [--vmid 100] [--mode snapshot|suspend|stop]
# Cron: 0 2 * * * /path/to/backup-script.sh >> /var/log/homelab/backup.log 2>&1

set -euo pipefail

# Configuration
BACKUP_DIR="/mnt/backup/proxmox"
RETENTION_DAYS=7
MODE="snapshot"  # snapshot | suspend | stop
COMPRESS="1"
NOTIFY_TELEGRAM=false
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"

log() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [INFO] $1"; }
warn() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [WARN] $1"; }
error() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [ERROR] $1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vmid) VMID="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --dir) BACKUP_DIR="$2"; shift 2 ;;
        *) warn "Unknown arg: $1"; shift ;;
    esac
done

# Check if running on Proxmox
if ! command -v pct &> /dev/null && ! command -v qm &> /dev/null; then
    error "This script must run on a Proxmox VE host (pct/qm not found)"
fi

# Create backup dir
mkdir -p "$BACKUP_DIR"

# Get list of containers/VMs
if [[ -n "${VMID:-}" ]]; then
    VMID_LIST=("$VMID")
else
    # All LXC containers
    VMID_LIST=($(pct list 2>/dev/null | awk 'NR>1 {print $1}'))
    # All QEMU VMs
    VMID_LIST+=($(qm list 2>/dev/null | awk 'NR>1 {print $1}'))
fi

if [[ ${#VMID_LIST[@]} -eq 0 ]]; then
    warn "No VMs or containers found to backup"
    exit 0
fi

log "Starting backup of ${#VMID_LIST[@]} instances..."

BACKED_UP=0
FAILED=0

for id in "${VMID_LIST[@]}"; do
    # Check if LXC or QEMU
    if pct status "$id" &>/dev/null; then
        TYPE="LXC"
        NAME=$(pct config "$id" | grep "^hostname:" | awk '{print $2}' || echo "ct-$id")
    elif qm status "$id" &>/dev/null; then
        TYPE="VM"
        NAME=$(qm config "$id" | grep "^name:" | awk '{print $2}' || echo "vm-$id")
    else
        warn "  ✗ Instance $id not found, skipping"
        ((FAILED++)) || true
        continue
    fi

    TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    BACKUP_FILE="$BACKUP_DIR/${TYPE}-${NAME}-${id}-${TIMESTAMP}.vma"

    log "  Backing up $TYPE $id ($NAME)..."

    if [[ "$TYPE" == "LXC" ]]; then
        if vzdump "$id" --mode "$MODE" --compress "$COMPRESS" --storage "$BACKUP_DIR" 2>/dev/null; then
            ((BACKED_UP++)) || true
            log "  ✓ $TYPE $id backup complete"
        else
            ((FAILED++)) || true
            warn "  ✗ $TYPE $id backup failed"
        fi
    else
        if vzdump "$id" --mode "$MODE" --compress "$COMPRESS" --storage "$BACKUP_DIR" 2>/dev/null; then
            ((BACKED_UP++)) || true
            log "  ✓ $TYPE $id backup complete"
        else
            ((FAILED++)) || true
            warn "  ✗ $TYPE $id backup failed"
        fi
    fi
done

# Cleanup old backups
log "Cleaning up old backups (> $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.vma.*" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true

# Notify via Telegram
if [[ "$NOTIFY_TELEGRAM" == true ]]; then
    MESSAGE="🗄️ <b>Backup Complete</b>
    
Instances backed up: <b>$BACKED_UP</b>
Failed: <b>$FAILED</b>
Location: $BACKUP_DIR
Time: $(date '+%Y-%m-%d %H:%M:%S')"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=HTML" > /dev/null 2>&1
fi

log "=========================================="
log "Backup finished!"
log "  • Successful: $BACKED_UP"
log "  • Failed: $FAILED"
log "=========================================="
