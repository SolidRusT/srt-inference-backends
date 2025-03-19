#!/bin/bash
# Make sure this file uses LF line endings when copied to Linux
# Script to check vLLM logs from all nodes

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
    echo "  -n, --lines LINES       Number of log lines to show (default: 50)"
    echo "  -t, --type TYPE         Log type (vllm, docker, system, all)"
    echo ""
    echo "Examples:"
    echo "  $0                      Check vLLM logs from all nodes (last 50 lines)"
    echo "  $0 -l node1             Only check node1 logs"
    echo "  $0 -n 100               Show last 100 lines"
    echo "  $0 -t docker            Show Docker container logs"
    echo "  $0 -t system            Show system journal logs"
    echo "  $0 -t all               Show all logs"
}

# Default values
LIMIT=""
LINES=50
LOG_TYPE="vllm"

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
        -n|--lines)
            LINES="$2"
            shift
            shift
            ;;
        -t|--type)
            LOG_TYPE="$2"
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

# Function to check logs
function check_logs {
    local LOG_CMD=""
    
    case $LOG_TYPE in
        vllm)
            echo -e "${YELLOW}=== vLLM Service Logs ===${NC}"
            LOG_CMD="journalctl -u vllm.service -n $LINES --no-pager"
            ;;
        docker)
            echo -e "${YELLOW}=== Docker Container Logs ===${NC}"
            LOG_CMD="docker logs --tail=$LINES vllm-server"
            ;;
        system)
            echo -e "${YELLOW}=== System Logs ===${NC}"
            LOG_CMD="journalctl -n $LINES --no-pager"
            ;;
        all)
            echo -e "${YELLOW}=== vLLM Service Logs ===${NC}"
            VLLM_CMD="journalctl -u vllm.service -n $LINES --no-pager"
            ansible inference_nodes -i inventory.yml -m shell -a "$VLLM_CMD" ${LIMIT_OPT}
            
            echo -e "\n${YELLOW}=== Docker Container Logs ===${NC}"
            DOCKER_CMD="docker logs --tail=$LINES vllm-server"
            ansible inference_nodes -i inventory.yml -m shell -a "$DOCKER_CMD" ${LIMIT_OPT}
            
            echo -e "\n${YELLOW}=== System Logs ===${NC}"
            SYS_CMD="journalctl -n $LINES --no-pager | grep -i 'nvidia\|cuda\|docker\|vllm'"
            ansible inference_nodes -i inventory.yml -m shell -a "$SYS_CMD" ${LIMIT_OPT}
            return
            ;;
        *)
            echo "Invalid log type: $LOG_TYPE"
            show_help
            exit 1
            ;;
    esac
    
    # Build command
    LIMIT_OPT=""
    if [ -n "$LIMIT" ]; then
        LIMIT_OPT="--limit $LIMIT"
    fi
    
    # Run the command
    ansible inference_nodes -i inventory.yml -m shell -a "$LOG_CMD" ${LIMIT_OPT}
}

# Run log check
echo "=== Inference Nodes Log Check ==="
echo "Log type: $LOG_TYPE"
echo "Lines: $LINES"
if [ -n "$LIMIT" ]; then
    echo "Limited to: $LIMIT"
fi
echo "-----------------------------------"

check_logs

echo "-----------------------------------"
echo "Log check completed!"
