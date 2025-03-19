#!/bin/bash
# Interactive test script for vLLM inference
# Shaun - March 2025

# Default settings
HOST="localhost"
PORT="8081"
MODE="default"

# ANSI colors
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Help message
usage() {
    echo -e "${BLUE}vLLM Inference Test Script${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST      Server hostname (default: $HOST)"
    echo "  -p, --port PORT      Server port (default: $PORT)"
    echo "  -m, --model MODEL    Model name"
    echo "  -i, --interactive    Start in interactive mode"
    echo "  -c, --chat           Start in interactive chat mode"
    echo "  -s, --simple         Run a simple test prompt"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Run a simple test with default settings"
    echo "  $0 -i                Start interactive mode"
    echo "  $0 -c                Start interactive chat mode"
    echo "  $0 -h remote.server -p 8080  Test remote server"
    echo ""
}

# Check if Python is available
check_python() {
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        echo -e "${RED}Error: Python not found. Please install Python 3.${NC}"
        exit 1
    fi
}

# Run the Python script
run_test_script() {
    local python_cmd
    local script_args="$@"
    
    # Choose the available Python command
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    else
        python_cmd="python"
    fi
    
    echo -e "${GREEN}Running vLLM test with:${NC} $python_cmd test-inference.py $script_args"
    $python_cmd test-inference.py $script_args
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -i|--interactive)
            MODE="interactive"
            shift
            ;;
        -c|--chat)
            MODE="chat"
            shift
            ;;
        -s|--simple)
            MODE="simple"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Main execution
check_python

SCRIPT_ARGS="--host $HOST --port $PORT"

if [ -n "$MODEL" ]; then
    SCRIPT_ARGS="$SCRIPT_ARGS --model $MODEL"
fi

case $MODE in
    interactive)
        run_test_script $SCRIPT_ARGS -i
        ;;
    chat)
        run_test_script $SCRIPT_ARGS -i
        echo "2" # Automatically select chat mode
        ;;
    simple)
        run_test_script $SCRIPT_ARGS
        ;;
    *)
        # Default mode - run simple test
        run_test_script $SCRIPT_ARGS
        ;;
esac
