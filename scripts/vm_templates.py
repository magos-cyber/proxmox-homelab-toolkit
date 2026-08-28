#!/usr/bin/env python3
"""Proxmox VM Template Manager - Creates and manages VM templates."""

import subprocess
import sys

def create_template(vmid, name, memory=2048, cores=2):
    """Create a VM template."""
    # Create VM
    subprocess.run([
        "qm", "create", str(vmid),
        "--name", name,
        "--memory", str(memory),
        "--cores", str(cores),
        "--net0", "virtio,bridge=vmbr0",
        "--scsihw", "virtio-scsi-single",
        "--scsi0", "local-lvm:32",
        "--ide2", "local/cloudinit",
        "--boot", "order=scsi0",
        "--serial0", "socket",
        "--vga", "serial0"
    ], check=True)
    
    # Convert to template
    subprocess.run(["qm", "template", str(vmid)], check=True)
    print(f"Template {name} (ID: {vid}) created")

def list_templates():
    """List all VM templates."""
    result = subprocess.run(["qm", "list"], capture_output=True, text=True)
    for line in result.stdout.split("\n"):
        if "template" in line.lower():
            print(line)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python vm_templates.py <create|list>")
        sys.exit(1)
    
    if sys.argv[1] == "list":
        list_templates()
    elif sys.argv[1] == "create" and len(sys.argv) >= 4:
        create_template(int(sys.argv[2]), sys.argv[3])
