#!/bin/bash
# Deploy Ops Deck to Android device via wireless debugging
# Usage: ./scripts/deploy.sh [IP:PORT]
#
# The script will auto-discover wireless debugging devices.
# If multiple devices are found, specify one manually.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

# Function to discover wireless devices via mDNS
discover_device() {
    # Check if mDNS is available
    if ! adb mdns check &>/dev/null; then
        return 1
    fi

    # Get list of discovered devices
    local services
    services=$(adb mdns services 2>/dev/null | grep "_adb-tls-connect._tcp" | head -1)

    if [ -z "$services" ]; then
        return 1
    fi

    # Extract IP:PORT from the service line
    # Format: adb-SERIAL-ID    _adb-tls-connect._tcp    192.168.x.x:PORT
    echo "$services" | awk '{print $NF}'
}

# Function to find already-connected wireless device
find_connected_device() {
    adb devices 2>/dev/null | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+" | head -1 | awk '{print $1}'
}

# Try to get device address
DEVICE_ADDR="$1"

if [ -z "$DEVICE_ADDR" ]; then
    # First check if already connected
    log_info "Checking for connected devices..."
    DEVICE_ADDR=$(find_connected_device)

    if [ -n "$DEVICE_ADDR" ]; then
        log_success "Found connected device: $DEVICE_ADDR"
    else
        # Try auto-discovery
        log_info "Discovering wireless debugging devices..."
        DEVICE_ADDR=$(discover_device)

        if [ -n "$DEVICE_ADDR" ]; then
            log_success "Discovered device: $DEVICE_ADDR"
        fi
    fi
fi

if [ -z "$DEVICE_ADDR" ]; then
    log_error "No device found."
    echo ""
    echo "Make sure wireless debugging is enabled on your phone:"
    echo "  Settings → Developer options → Wireless debugging → Enable"
    echo ""
    echo "Or specify manually: $0 <IP:PORT>"
    exit 1
fi

# Connect if not already connected
if ! adb devices | grep -q "$DEVICE_ADDR.*device$"; then
    log_info "Connecting to $DEVICE_ADDR..."
    if adb connect "$DEVICE_ADDR" 2>&1 | grep -q "connected"; then
        log_success "Connected to $DEVICE_ADDR"
    else
        log_error "Failed to connect. The device may need to be paired first."
        echo ""
        echo "To pair a new device:"
        echo "  1. On phone: Wireless debugging → Pair device with pairing code"
        echo "  2. Run: adb pair <IP>:<PAIRING_PORT> <CODE>"
        echo "  3. Then run this script again"
        exit 1
    fi
else
    log_success "Already connected to $DEVICE_ADDR"
fi

# Check if we're on a feature branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warn "On branch '$CURRENT_BRANCH' (not main)"
fi

# Build and run
echo ""
log_info "Building and deploying to device..."
echo ""

flutter run -d "$DEVICE_ADDR" --release

log_success "Deployment complete!"
