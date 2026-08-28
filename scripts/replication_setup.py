#!/usr/bin/env python3
"""Replication Setup for Proxmox - Configure VM replication between nodes."""

import subprocess
import sys

def setup_replication(vmid, target_node, schedule="*/15"):
    """Setup replication job for a VM."""
    cmd = [
        "qm", "replicate", str(vmid),
        target_node,
        "--schedule", schedule,
        "--enabled", "1"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"Replication configured: VM {vmid} -> {target_node}")
        return True
    else:
        print(f"Failed: {result.stderr}")
        return False

def list_replications():
    """List all replication jobs."""
    result = subprocess.run(
        ["pvesr", "list"],
        capture_output=True, text=True
    )
    print("Replication jobs:")
    print(result.stdout)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python replication_setup.py <setup|list> [vmid target_node]")
        sys.exit(1)
    
    if sys.argv[1] == "setup":
        setup_replication(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "list":
        list_replications()
