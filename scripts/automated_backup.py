#!/usr/bin/env python3
"""Automated Backup Manager for Proxmox - Schedules and manages backups."""

import subprocess
import datetime
import json
import os
import sys

class ProxmoxBackup:
    def __init__(self, storage="local", mode="snapshot", retention_days=7):
        self.storage = storage
        self.mode = mode
        self.retention_days = retention_days

    def list_vms(self):
        """List all VMs."""
        result = subprocess.run(["qm", "list"], capture_output=True, text=True)
        vms = []
        for line in result.stdout.split("\n")[1:]:
            if line.strip():
                vmid = line.split()[0]
                vms.append(vmid)
        return vms

    def list_containers(self):
        """List all containers."""
        result = subprocess.run(["pct", "list"], capture_output=True, text=True)
        cts = []
        for line in result.stdout.split("\n")[1:]:
            if line.strip():
                ctid = line.split()[0]
                cts.append(ctid)
        return cts

    def backup_all(self, backup_dir="/backups/proxmox"):
        """Backup all VMs and containers."""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        target_dir = f"{backup_dir}/{timestamp}"
        os.makedirs(target_dir, exist_ok=True)

        print(f"Backing up to: {target_dir}")

        # Backup VMs
        for vmid in self.list_vms():
            print(f"Backing up VM {vmid}...")
            subprocess.run([
                "vzdump", vmid,
                "--storage", self.storage,
                "--mode", self.mode,
                "--compress", "zstd",
                "--dumpdir", target_dir
            ])

        # Backup containers
        for ctid in self.list_containers():
            print(f"Backing up CT {ctid}...")
            subprocess.run([
                "vzdump", ctid,
                "--storage", self.storage,
                "--mode", self.mode,
                "--compress", "zstd",
                "--dumpdir", target_dir
            ])

        print("Backup complete")

    def cleanup_old_backups(self, backup_dir="/backups/proxmox"):
        """Remove backups older than retention period."""
        print(f"Cleaning up backups older than {self.retention_days} days...")
        subprocess.run([
            "find", backup_dir,
            "-type", "d",
            "-name", "20*",
            "-mtime", f"+{self.retention_days}",
            "-exec", "rm", "-rf", "{}", "+"
        ])

if __name__ == "__main__":
    backup = ProxmoxBackup()
    backup.backup_all()
    backup.cleanup_old_backups()
