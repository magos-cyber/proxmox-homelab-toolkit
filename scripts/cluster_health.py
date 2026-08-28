#!/usr/bin/env python3
"""Proxmox Cluster Health Checker - Monitors cluster status and alerts on issues."""

import subprocess
import json
import sys

def check_cluster_status():
    """Check Proxmox cluster status."""
    try:
        result = subprocess.run(["pvecm", "status"], capture_output=True, text=True)
        print("=== Cluster Status ===")
        print(result.stdout)
        return result.returncode == 0
    except FileNotFoundError:
        print("pvecm not found - not a Proxmox node")
        return False

def check_vm_status():
    """Check status of all VMs and containers."""
    try:
        result = subprocess.run(["qm", "list"], capture_output=True, text=True)
        print("=== VM Status ===")
        print(result.stdout)
        
        result = subprocess.run(["pct", "list"], capture_output=True, text=True)
        print("=== Container Status ===")
        print(result.stdout)
        return True
    except FileNotFoundError:
        print("qm/pct not found")
        return False

def check_storage():
    """Check storage usage across nodes."""
    try:
        result = subprocess.run(["pvesm", "status"], capture_output=True, text=True)
        print("=== Storage Status ===")
        print(result.stdout)
        return True
    except FileNotFoundError:
        print("pvesm not found")
        return False

if __name__ == "__main__":
    check_cluster_status()
    check_vm_status()
    check_storage()
