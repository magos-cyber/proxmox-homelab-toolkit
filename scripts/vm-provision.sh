#!/bin/bash
# VM Provisioning Script
# Creates and configures VMs on Proxmox VE

set -euo pipefail

NODE="${NODE:-pve}"
VMID="${1:?Usage: $0 <vmid> [name] [memory] [cores] [disk] [iso]}"
NAME="${2:-vm-$VMID}"
MEMORY="${3:-2048}"
CORES="${4:-2}"
DISK="${5:-32}"
ISO="${6:-local:iso/ubuntu-22.04-server-amd64.iso}"

echo "=== VM Provisioning ==="
echo "VMID: $VMID"
echo "Name: $NAME"
echo "Memory: ${MEMORY}MB"
echo "Cores: $CORES"
echo "Disk: ${DISK}GB"
echo "ISO: $ISO"
echo ""

# Create VM
echo "Creating VM..."
qm create "$VMID"     --name "$NAME"     --memory "$MEMORY"     --cores "$CORES"     --cpu host     --net0 virtio,bridge=vmbr0     --scsihw virtio-scsi-single     --scsi0 "local-lvm:${DISK},ssd=1"     --ide2 "$ISO,media=cdrom"     --boot order=ide2     --ostype l26     --agent enabled=1

# Start VM
echo "Starting VM..."
qm start "$VMID"

echo ""
echo "VM $VMID provisioned successfully!"
echo "Console: qm terminal $VMID"
