#!/bin/bash
# LXC Container Provisioning Script
# Creates and configures LXC containers on Proxmox VE

set -euo pipefail

PVE_HOST="${PVE_HOST:-10.0.0.10}"
NODE="${NODE:-pve}"
CTID="${1:?Usage: $0 <ctid> [template] [hostname] [memory] [storage]}"
TEMPLATE="${2:-local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst}"
HOSTNAME="${3:-lxc-$CTID}"
MEMORY="${4:-512}"
STORAGE="${5:-local-lvm}"

echo "=== LXC Container Provisioning ==="
echo "CTID: $CTID"
echo "Template: $TEMPLATE"
echo "Hostname: $HOSTNAME"
echo "Memory: ${MEMORY}MB"
echo "Storage: $STORAGE"
echo ""

# Create container
echo "Creating container..."
pct create "$CTID" "$TEMPLATE"     --hostname "$HOSTNAME"     --memory "$MEMORY"     --storage "$STORAGE"     --rootfs "${STORAGE}:8"     --net0 "name=eth0,bridge=vmbr0,ip=dhcp"     --unprivileged 1     --features "nesting=1"

# Start container
echo "Starting container..."
pct start "$CTID"

# Wait for network
sleep 5

# Get IP
IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')
echo "Container IP: $IP"

echo ""
echo "Container $CTID provisioned successfully!"
echo "SSH: ssh root@$IP"
