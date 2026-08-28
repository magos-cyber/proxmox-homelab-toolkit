# Proxmox Homelab Toolkit

Python tools for managing Proxmox VE clusters, VMs, and backups.

## Features

- Cluster health monitoring
- VM template management
- Automated backup scheduling
- Snapshot management
- VM replication setup

## Scripts

### Cluster
- `cluster_health.py` - Check cluster, VM, and storage status

### VM Management
- `vm_templates.py` - Create and manage VM templates
- `snapshot_manager.py` - Create/list/delete/rollback snapshots

### Backup
- `backup_manager.py` - Manual backup of VMs/containers
- `automated_backup.py` - Scheduled backups with retention
- `replication_setup.py` - Configure cross-node replication

## Requirements

- Proxmox VE node
- Python 3.8+
- `qm`, `pct`, `vzdump`, `pvesr` commands

## Usage

```bash
python cluster_health.py
python vm_templates.py create 100 my-template
python snapshot_manager.py create 100 pre-update
python automated_backup.py
```

## License

MIT
