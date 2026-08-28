#!/usr/bin/env python3
"""Proxmox Backup Manager - Automates VM/LXC backups."""

import subprocess
import datetime
import sys

def backup_vms(vmid=None, storage="local", compress="zstd"):
    """Backup VMs or containers."""
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    if vmid:
        # Backup specific VM
        result = subprocess.run([
            "vzdump", str(vmid),
            "--storage", storage,
            "--compress", compress,
            "--mode", "snapshot"
        ], capture_output=True, text=True)
        print(f"Backup VM {vmid}: {result.returncode == 0}")
    else:
        # Backup all VMs
        result = subprocess.run([
            "vzdump", "all",
            "--storage", storage,
            "--compress", compress,
            "--mode", "snapshot"
        ], capture_output=True, text=True)
        print(f"Full backup: {result.returncode == 0}")

def list_backups(storage="local"):
    """List available backups."""
    result = subprocess.run(
        ["pvesm", "list", storage],
        capture_output=True, text=True
    )
    for line in result.stdout.split("\n"):
        if "vzdump" in line:
            print(line)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python backup_manager.py <backup|list> [vmid]")
        sys.exit(1)
    
    if sys.argv[1] == "backup":
        vmid = int(sys.argv[2]) if len(sys.argv) > 2 else None
        backup_vms(vmid)
    elif sys.argv[1] == "list":
        list_backups()
