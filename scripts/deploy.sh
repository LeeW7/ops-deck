#!/bin/bash
# Deploy Ops Deck to Android device via wireless debugging
# Usage: ./scripts/deploy.sh [IP:PORT]
#
# First time setup:
#   1. On phone: Settings → Developer options → Wireless debugging → Enable
#   2. Tap "Wireless debugging" to see IP:PORT
#   3. Run: ./scripts/deploy.sh 192.168.1.100:5555
#
# After pairing once, just run: ./scripts/deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/.wireless-debug-device"

cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Get device address from argument or saved config
DEVICE_ADDR="$1"

if [ -z "$DEVICE_ADDR" ] && [ -f "$CONFIG_FILE" ]; then
    DEVICE_ADDR=$(cat "$CONFIG_FILE")
    log_info "Using saved device: $DEVICE_ADDR"
fi

if [ -z "$DEVICE_ADDR" ]; then
    log_error "No device address provided."
    echo ""
    echo "Usage: $0 <IP:PORT>"
    echo ""
    echo "To find your device address:"
    echo "  1. On phone: Settings → Developer options → Wireless debugging"
    echo "  2. Tap 'Wireless debugging' to see IP address & Port"
    echo ""
    echo "Example: $0 192.168.1.100:5555"
    exit 1
fi

# Save device address for future use
echo "$DEVICE_ADDR" > "$CONFIG_FILE"

# Check if already connected
log_info "Checking device connection..."
if adb devices | grep -q "$DEVICE_ADDR"; then
    log_success "Already connected to $DEVICE_ADDR"
else
    log_info "Connecting to $DEVICE_ADDR..."
    if adb connect "$DEVICE_ADDR" 2>&1 | grep -q "connected"; then
        log_success "Connected to $DEVICE_ADDR"
    else
        log_error "Failed to connect. Make sure:"
        echo "  - Wireless debugging is enabled on your phone"
        echo "  - Phone and computer are on the same network"
        echo "  - The IP:PORT is correct"
        echo ""
        echo "If this is a new device, you may need to pair first:"
        echo "  adb pair <IP>:<PAIRING_PORT> <PAIRING_CODE>"
        exit 1
    fi
fi

# Verify device is available to Flutter
log_info "Verifying Flutter can see device..."

# Use the device address directly since we already connected via adb
DEVICE_ID="$DEVICE_ADDR"

if [ -z "$DEVICE_ID" ]; then
    log_error "Device not found by Flutter. Try running 'flutter doctor' for diagnostics."
    exit 1
fi

log_success "Device ready: $DEVICE_ID"

# Build and deploy
echo ""
log_info "Building and deploying to device..."
echo ""

# Check if we're on a feature branch that needs merging first
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warn "On branch '$CURRENT_BRANCH' (not main)"
fi

# Run flutter with the device
flutter run -d "$DEVICE_ID" --release

log_success "Deployment complete!"
