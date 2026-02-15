#!/usr/bin/env bash
set -e

EXTRACTED="$1"
DEVICE_DIR="$2"

[ -z "$EXTRACTED" ] && { echo "Missing extracted directory"; exit 1; }
[ -z "$DEVICE_DIR" ] && { echo "Missing device directory"; exit 1; }

[ ! -d "$EXTRACTED" ] && { echo "Extracted firmware not found!"; exit 1; }
[ ! -d "$DEVICE_DIR" ] && { echo "Device directory not found!"; exit 1; }

echo "🔧 Starting H3CKED Port"
echo "Working directory: $EXTRACTED"
echo "Device directory: $DEVICE_DIR"

DEVICE_NAME="$(basename "$DEVICE_DIR")"
DEVICE_SCRIPT="$DEVICE_DIR/${DEVICE_NAME}.sh"

if [ ! -f "$DEVICE_SCRIPT" ]; then
    echo "❌ Device script not found: $DEVICE_SCRIPT"
    exit 1
fi

echo "▶ Running $DEVICE_SCRIPT"

chmod +x "$DEVICE_SCRIPT"
bash "$DEVICE_SCRIPT" "$EXTRACTED"

echo "✅ Port finished"
