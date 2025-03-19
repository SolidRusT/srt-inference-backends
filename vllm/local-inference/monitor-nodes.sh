#!/bin/bash
# Make sure this file uses LF line endings when copied to Linux
# Script to monitor the status of all inference nodes

set -e

cd "$(dirname "$0")/ansible"

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display help message
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -l, --limit HOSTS       Limit to specific hosts"
    echo ""
    echo "Examples:"
    echo "  $0                      Check all nodes"
    echo "  $0 -l node1             Only check node1"
}

# Default values
LIMIT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--limit)
            LIMIT="$2"
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

# Build command
CMD="ansible inference_nodes -i inventory.yml -m shell -a 'uptime && echo && nvidia-smi && echo && docker ps && echo && systemctl status vllm --no-pager'"

if [ -n "$LIMIT" ]; then
    CMD="$CMD --limit $LIMIT"
fi

# Run the command
echo "=== Inference Nodes Status Check ==="
echo "Running: $CMD"
echo "-----------------------------------"

eval $CMD

echo "-----------------------------------"
echo "Status check completed!"