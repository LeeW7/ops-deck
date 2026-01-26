#!/bin/bash
# Build and install Ops Deck APK to Android device
# Usage: ./scripts/install.sh [IP:PORT]
#
# This installs a standalone APK that persists after disconnecting.
# Use deploy.sh instead if you want hot reload during development.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/.wireless-debug-device"
APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"

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
        exit 1
    fi
fi

# Check if we're on a feature branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warn "On branch '$CURRENT_BRANCH' (not main)"
fi

# Build release APK
echo ""
log_info "Building release APK..."
flutter build apk --release

if [ ! -f "$APK_PATH" ]; then
    log_error "APK not found at $APK_PATH"
    exit 1
fi

log_success "APK built successfully"

# Get APK size
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
log_info "APK size: $APK_SIZE"

# Install APK
echo ""
log_info "Installing APK to device..."
adb -s "$DEVICE_ADDR" install -r "$APK_PATH"

log_success "Installation complete!"
echo ""
echo -e "${GREEN}The app is now installed on your device.${NC}"
echo -e "You can disconnect wireless debugging - the app will persist."
echo ""
echo "To launch: Open 'Ops Deck' from your app drawer"
