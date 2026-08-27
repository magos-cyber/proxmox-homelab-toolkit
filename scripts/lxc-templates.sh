#!/bin/bash
# LXC Template Management
# Download and manage LXC templates

TEMPLATE_STORAGE="${1:-local}"

echo "=== LXC Template Management ==="

# List available templates
echo "Available Templates:"
pveam available --section system 2>/dev/null | head -20

# List downloaded templates
echo ""
echo "Downloaded Templates:"
pveam list "$TEMPLATE_STORAGE" 2>/dev/null

# Update template list
echo ""
echo "Updating template list..."
pveam update 2>/dev/null
echo "Done"
