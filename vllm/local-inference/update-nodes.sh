#!/bin/bash
# Make sure this file uses LF line endings when copied to Linux
# Script to update inference nodes with Ansible

set -e

cd "$(dirname "$0")/ansible"

# Default values
PLAYBOOK="site.yml"
INVENTORY="inventory.yml"
CHECK_MODE=false
TAGS=""
LIMIT=""
SKIP_GPG=false

# Function to display help message
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --check             Run in check mode (no changes)"
    echo "  -t, --tags TAGS         Only run specific tags (comma-separated)"
    echo "  -l, --limit HOSTS       Limit to specific hosts"
    echo "  -s, --skip-gpg          Skip NVIDIA GPG key import (use if hanging)"
    echo "  -v, --vllm-only         Update only vLLM components (shortcut for -t vllm)"
    echo "  -o, --optimize          Run vLLM parameter optimization"
    echo ""
    echo "Examples:"
    echo "  $0                      Run all playbooks on all hosts"
    echo "  $0 -t nvidia            Only run NVIDIA setup tasks"
    echo "  $0 -t docker,vllm       Run Docker and vLLM setup tasks"
    echo "  $0 -v                   Update only vLLM components"
    echo "  $0 -o                   Run vLLM parameter optimization"
    echo "  $0 -s                   Skip NVIDIA GPG key import (if task hangs)"
    echo "  $0 -c                   Check mode (no changes)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            CHECK_MODE=true
            shift
            ;;
        -t|--tags)
            TAGS="$2"
            shift
            shift
            ;;
        -l|--limit)
            LIMIT="$2"
            shift
            shift
            ;;
        -s|--skip-gpg)
            SKIP_GPG=true
            shift
            ;;
        -v|--vllm-only)
            TAGS="vllm"
            PLAYBOOK="site.yml"
            shift
            ;;
        -o|--optimize)
            PLAYBOOK="playbooks/optimize-vllm.yml"
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
CMD="ansible-playbook $PLAYBOOK -i $INVENTORY"

if $CHECK_MODE; then
    CMD="$CMD --check"
fi

if [ -n "$TAGS" ]; then
    CMD="$CMD --tags $TAGS"
fi

if [ -n "$LIMIT" ]; then
    CMD="$CMD --limit $LIMIT"
fi

if $SKIP_GPG; then
    CMD="$CMD -e skip_nvidia_gpg=true"
fi

# Run Ansible
echo "Running: $CMD"
echo "-----------------------------------"

eval $CMD

echo "-----------------------------------"
echo "Done!"