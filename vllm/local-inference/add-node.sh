#!/bin/bash
# Make sure this file uses LF line endings when copied to Linux
# Script to add a new node to the Ansible inventory

set -e

INVENTORY_FILE="$(dirname "$0")/ansible/inventory.yml"

# Function to display help message
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --name NAME         Node name (required)"
    echo "  -i, --ip IP             IP address (required)"
    echo "  -u, --user USER         SSH user (default: shaun)"
    echo ""
    echo "Example:"
    echo "  $0 -n node3 -i 192.168.1.103 -u shaun"
}

# Default values
NODE_NAME=""
IP_ADDRESS=""
SSH_USER="shaun"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--name)
            NODE_NAME="$2"
            shift
            shift
            ;;
        -i|--ip)
            IP_ADDRESS="$2"
            shift
            shift
            ;;
        -u|--user)
            SSH_USER="$2"
            shift
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$NODE_NAME" ] || [ -z "$IP_ADDRESS" ]; then
    echo "Error: Node name and IP address are required."
    show_help
    exit 1
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file not found at $INVENTORY_FILE"
    exit 1
fi

# Check if node already exists
if grep -q "^ *$NODE_NAME:" "$INVENTORY_FILE"; then
    echo "Error: Node $NODE_NAME already exists in inventory."
    exit 1
fi

# Add the node to the inventory
# Find the hosts section and add the new node
sed -i "/hosts:/a\\        $NODE_NAME:\\n          ansible_host: $IP_ADDRESS\\n          ansible_user: $SSH_USER" "$INVENTORY_FILE"

echo "Node $NODE_NAME added to inventory with IP $IP_ADDRESS and user $SSH_USER"
echo "You can now deploy to this node using:"
echo "./update-nodes.sh -l $NODE_NAME"