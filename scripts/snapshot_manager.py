#!/usr/bin/env python3
"""Snapshot Manager for Proxmox - Create and manage VM snapshots."""

import subprocess
import datetime
import sys

def create_snapshot(vmid, name=None, description=""):
    """Create a snapshot of a VM."""
    if not name:
        name = f"snap-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}"
    
    cmd = ["qm", "snapshot", str(vmid), name]
    if description:
        cmd.extend(["--description", description])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"Snapshot '{name}' created for VM {vmid}")
        return True
    else:
        print(f"Failed to create snapshot: {result.stderr}")
        return False

def list_snapshots(vmid):
    """List snapshots for a VM."""
    result = subprocess.run(
        ["qm", "listsnapshot", str(vmid)],
        capture_output=True, text=True
    )
    print(f"Snapshots for VM {vmid}:")
    print(result.stdout)

def delete_snapshot(vmid, name):
    """Delete a snapshot."""
    result = subprocess.run(
        ["qm", "delsnapshot", str(vmid), name],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"Snapshot '{name}' deleted from VM {vmid}")
    else:
        print(f"Failed to delete: {result.stderr}")

def rollback_snapshot(vmid, name):
    """Rollback to a snapshot."""
    result = subprocess.run(
        ["qm", "rollback", str(vmid), name],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"Rolled back VM {vmid} to '{name}'")
    else:
        print(f"Failed to rollback: {result.stderr}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python snapshot_manager.py <create|list|delete|rollback> <vmid> [name]")
        sys.exit(1)
    
    action = sys.argv[1]
    vmid = sys.argv[2]
    
    if action == "create":
        name = sys.argv[3] if len(sys.argv) > 3 else None
        create_snapshot(vmid, name)
    elif action == "list":
        list_snapshots(vmid)
    elif action == "delete" and len(sys.argv) > 3:
        delete_snapshot(vmid, sys.argv[3])
    elif action == "rollback" and len(sys.argv) > 3:
        rollback_snapshot(vmid, sys.argv[3])
