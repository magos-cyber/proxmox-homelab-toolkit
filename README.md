# Proxmox Homelab Toolkit

Proxmox VE automation toolkit — API scripts, LXC templates, backup automation, VM provisioning, and management utilities.

## 📁 Structure

```
proxmox-homelab-toolkit/
├── scripts/
│   ├── vm-create.sh       # Create VMs via Proxmox API
│   ├── vm-backup.sh       # Automated VM/LXC backup with retention
│   ├── lxc-create.sh      # Create LXC containers
│   ├── proxmox_api.py     # Python Proxmox API wrapper
│   └── lxc-template.yml   # Cloud-init LXC template
├── templates/
│   └── lxc-template.yml   # Documented LXC cloud-init template
├── backup/
│   └── backup-script.sh   # Automated vzdump backup script
└── docs/
    └── api-reference.md   # API reference documentation
```

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/magos-cyber/proxmox-homelab-toolkit.git
cd proxmox-homelab-toolkit

# Make scripts executable
chmod +x scripts/*.sh

# Set environment variables
export PROXMOX_HOST="your-proxmox-host"
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN="USER@REALM!TOKENID=TOKENVALUE"
export PROXMOX_VERIFY_SSL=false
```

## 📝 Contents

### Bash Scripts
- **`scripts/vm-create.sh`** — Create VMs via Proxmox API with customizable specs (memory, cores, disk, ISO, network)
- **`scripts/vm-backup.sh`** — Automated VM/LXC backup with retention policy and Telegram notifications
- **`scripts/lxc-create.sh`** — Create LXC containers with cloud-init
- **`backup/backup-script.sh`** — Automated vzdump backup script with retention and Telegram alerts

### Python Scripts
- **`scripts/proxmox_api.py`** — Full Python wrapper for Proxmox VE API (VMs, LXC, storage, backups, nodes)

### Templates
- **`templates/lxc-template.yml`** — Documented LXC cloud-init template with example `pct create` command

## 🔧 Configuration

All scripts use environment variables for authentication:

```bash
export PROXMOX_HOST="proxmox.example.com"
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN="root@pam!token-name=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export PROXMOX_VERIFY_SSL=false  # Set to true for valid certs
```

## 🔑 Getting a Proxmox API Token

1. Log into Proxmox Web UI
2. Go to **Datacenter → Permissions → API Tokens**
3. Click **Add** → Enter token name → Set privileges
4. Copy the token (format: `USER@REALM!TOKENID=TOKENVALUE`)

## 📝 Examples

### Create a new VM
```bash
./scripts/vm-create.sh \
  --name ubuntu-vm \
  --memory 4096 \
  --cores 4 \
  --disk 50 \
  --iso local:iso/ubuntu-22.04-server-amd64.iso \
  --bridge vmbr0
```

### Create an LXC container
```bash
./scripts/lxc-create.sh \
  --name web-server \
  --memory 1024 \
  --cores 2 \
  --disk 10 \
  --template debian-12-standard
```

### Run automated backups
```bash
# Add to cron for daily backups at 2 AM
0 2 * * * /path/to/scripts/vm-backup.sh --storage backup-storage --retention 7
```

### Use Python API
```python
from scripts.proxmox_api import ProxmoxAPI

api = ProxmoxAPI("proxmox.example.com", "root@pam", "TOKEN")
nodes = api.get_nodes()
for node in nodes:
    vms = api.get_vms(node["node"])
    for vm in vms:
        print(f"{vm['name']}: {vm['status']}")
```

## 🤝 Contributing

Contributions are welcome! Please:
- Keep scripts in English
- Add proper error handling
- Document all parameters
- Test before submitting

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.