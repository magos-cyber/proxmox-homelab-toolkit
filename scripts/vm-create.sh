#!/usr/bin/env bash
# vm-create.sh — Create a new VM on Proxmox VE via API
# Usage: ./vm-create.sh --name myvm --memory 2048 --cores 2 --disk 30 --iso local:iso/ubuntu-22.04.iso --bridge vmbr0

set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-localhost}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
PROXMOX_TOKEN="${PROXMOX_TOKEN:-}"
PROXMOX_VERIFY_SSL="${PROXMOX_VERIFY_SSL:-false}"

log() { echo -e "[$(date '+%Y-%m-%d %H:%M')] $1"; }
error() { echo -e "[$(date '+%Y-%m-%d %H:%M')] $1"; exit 1; }

usage() {
 cat << EOF
Usage: $0 

Options:
 --name NAME VM name (required)
 --memory MB Memory in MB (default: 2048)
 --cores N CPU cores (default: 2)
 --disk GB Disk size in GB (default: 30)
 --iso PATH ISO path for installation (optional)
 --bridge NAME Network bridge (default: vmbr0)
 --vmid ID VM ID (auto-assign if not specified)
 --storage NAME Storage name (default: local-lvm)
 --ostype TYPE OS type (default: l26)
 --help Show this help

Environment variables:
 PROXMOX_HOST Proxmox API host (default: localhost)
 PROXMOX_USER API user (default: root@pam)
 PROXMOX_TOKEN API token (format: USER@REALM!TOKENID=TOKENVALUE)
 PROXMOX_VERIFY_SSL Verify SSL certificate (default: false)
EOF
}

# Parse arguments
NAME=""
MEMORY=2048
CORES=2
DISK=30
ISO=""
BRIDGE="vmbr0"
VMID=""
STORAGE="local-lvm"
OSTYPE="l26"

while [[ $# -gt 0 ]]; do
 case $1 in
 --name) NAME="$2"; shift 2 ;;
 --memory) MEMORY="$2"; shift 2 ;;
 --cores) CORES="$2"; shift 2 ;;
 --disk) DISK="$2"; shift 2 ;;
 --iso) ISO="$2"; shift 2 ;;
 --bridge) BRIDGE="$2"; shift 2 ;;
 --vmid) VMID="$2"; shift 2 ;;
 --storage) STORAGE="$2"; shift 2 ;;
 --ostype) OSTYPE="$2"; shift 2 ;;
 --help) usage; exit 0 ;;
 *) error "Unknown option: $1" ;;
 esac
done

[[ -z "$NAME" ]] && error "VM name is required (--name)"
[[ -z "$PROXMOX_TOKEN" ]] && error "PROXMOX_TOKEN environment variable is required"

# Build API URL
BASE_URL="https://${PROXMOX_HOST}:8006/api2/json"
AUTH_HEADER="Authorization: PVEAPIToken=${PROXMOX_TOKEN}"
CURL_OPTS=(-s -H "$AUTH_HEADER")
[[ "$PROXMOX_VERIFY_SSL" == "false" ]] && CURL_OPTS+=(-k)

# Get next VMID if not specified
if [[ -z "$VMID" ]]; then
 log "Auto-assigning VMID..."
 RESPONSE=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/cluster/nextid")
 VMID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'])")
 log "Assigned VMID: $VMID"
fi

# Create VM
log "Creating VM $NAME (ID: $VMID)..."
CREATE_DATA=(
 "vmid=$VMID"
 "name=$NAME"
 "memory=$MEMORY"
 "cores=$CORES"
 "ostype=$OSTYPE"
 "net0=virtio,bridge=$BRIDGE"
 "scsi0=${STORAGE}:${DISK},iothread=1"
 "scsihw=virtio-scsi-pci"
 "boot=order=scsi0;ide2=cdrom"
 "agent=1,fstrim_cloned_disks=1"
)

if [[ -n "$ISO" ]]; then
 CREATE_DATA+=("ide2=${ISO},media=cdrom")
fi

curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/nodes/${PROXMOX_HOST}/qemu" \
 --data-urlencode "$(IFS=\&; echo "${CREATE_DATA[*]}")" > /dev/null

log "VM $NAME created successfully!"

# Start VM
log "Starting VM..."
curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/nodes/${PROXMOX_HOST}/qemu/${VMID}/status/start" > /dev/null
log "VM started!"

# Wait for agent
log "Waiting for QEMU Guest Agent..."
for i in {1..30}; do
 AGENT=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${PROXMOX_HOST}/qemu/${VMID}/agent/ping" 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('data', {}).get('result', ''))")
 [[ "$AGENT" == "pong" ]] && { log "QEMU Guest Agent is ready!"; break; }
 sleep 2
done

# Get IP
IP=$(curl "${CURL_OPTS[@]}" "${BASE_URL}/nodes/${PROXMOX_HOST}/qemu/${VMID}/agent/network-get-interfaces" 2>/dev/null | python3 -c "
import sys,json
r=json.load(sys.stdin)
for iface in r.get('data', {}).get('result', []):
 for ip in iface.get('ip-addresses', []):
 if ip['ip-address-type'] == 'ipv4' and not ip['ip-address'].startswith('127.'):
 print(ip['ip-address'])
 break
")

log "VM $NAME is ready!"
echo "VMID: $VMID"
echo "IP: $IP"