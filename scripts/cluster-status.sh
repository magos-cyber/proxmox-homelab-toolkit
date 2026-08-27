#!/bin/bash
# Proxmox Cluster Status
# Shows cluster health and resource usage

echo "=== Proxmox Cluster Status ==="

# Check cluster status
echo "Cluster Nodes:"
pvecm status 2>/dev/null || echo "Not in a cluster"

# List all nodes and their status
echo ""
echo "Node Resources:"
pvesh get /cluster/resources --output-format json 2>/dev/null | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    if item.get('type') == 'node':
        print(f"  {item['name']}: {item.get('status', 'unknown')}")
    elif item.get('type') == 'qemu':
        print(f"  VM {item['vmid']}: {item.get('name', 'unknown')} ({item.get('status', 'unknown')})")
    elif item.get('type') == 'lxc':
        print(f"  CT {item['vmid']}: {item.get('name', 'unknown')} ({item.get('status', 'unknown')})")
" 2>/dev/null || echo "Could not fetch resources"
