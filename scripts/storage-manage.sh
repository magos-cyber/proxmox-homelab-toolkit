#!/bin/bash
# Proxmox Storage Management
# Manage storage pools and cleanup

STORAGE="${1:-local}"

echo "=== Storage Management: $STORAGE ==="

# Show storage status
echo "Storage Status:"
pvesh get /storage --output-format json 2>/dev/null | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    if item.get('storage') == '$STORAGE':
        print(f"  Type: {item.get('type')}")
        print(f"  Total: {item.get('total', 0) / (1024**3):.1f} GB")
        print(f"  Used: {item.get('used', 0) / (1024**3):.1f} GB")
        print(f"  Available: {item.get('avail', 0) / (1024**3):.1f} GB")
" 2>/dev/null

# Cleanup old backups
echo ""
echo "Cleaning up old backups..."
find /var/lib/vz/dump -name "vzdump-*" -mtime +7 -delete 2>/dev/null
echo "Cleanup complete"
