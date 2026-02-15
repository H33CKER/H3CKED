#!/usr/bin/env bash
set -euo pipefail

EXTRACTED="$1"
DEVICE_DIR="$2"

# -----------------------------
# Argument Validation
# -----------------------------
if [ -z "${EXTRACTED:-}" ]; then
    echo "❌ Missing extracted directory"
    exit 1
fi

if [ -z "${DEVICE_DIR:-}" ]; then
    echo "❌ Missing device directory"
    exit 1
fi

if [ ! -d "$EXTRACTED" ]; then
    echo "❌ Extracted firmware not found: $EXTRACTED"
    exit 1
fi

if [ ! -d "$DEVICE_DIR" ]; then
    echo "❌ Device directory not found: $DEVICE_DIR"
    exit 1
fi

echo "============================================"
echo "🔧 Starting H3CKED Port"
echo "📂 Extracted Dir : $EXTRACTED"
echo "📱 Device Dir    : $DEVICE_DIR"
echo "============================================"

# -----------------------------
# Apply Stock Overlay
# -----------------------------
STOCK_OVERLAY="$DEVICE_DIR/Stock"

if [ -d "$STOCK_OVERLAY" ]; then
    echo "📦 Applying Stock Overlay..."
    echo "   Source: $STOCK_OVERLAY"
    echo "   Target: $EXTRACTED"

    rsync -a --progress "$STOCK_OVERLAY"/ "$EXTRACTED"/

    echo "✅ Stock overlay applied"
else
    echo "ℹ️ No Stock overlay found, skipping..."
fi

echo "--------------------------------------------"

# -----------------------------
# Run Device Script
# -----------------------------
DEVICE_NAME="$(basename "$DEVICE_DIR")"
DEVICE_SCRIPT="$DEVICE_DIR/${DEVICE_NAME}.sh"

if [ ! -f "$DEVICE_SCRIPT" ]; then
    echo "❌ Device script not found:"
    echo "   Expected: $DEVICE_SCRIPT"
    exit 1
fi

echo "▶ Running device script: $DEVICE_SCRIPT"
echo "--------------------------------------------"

chmod +x "$DEVICE_SCRIPT"
bash "$DEVICE_SCRIPT" "$EXTRACTED"

echo "--------------------------------------------"
echo "✅ H3CKED Port Finished Successfully"
echo "============================================"