#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# -----------------------------
# Argument Validation
# -----------------------------
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <extracted_dir> <stock_device>"
    exit 1
fi

STOCK_DEVICE="$2"
export EXTRACTED="$1"
export DEVICE_DIR="H3CKED/Devices/$STOCK_DEVICE"
export APKTOOL="$(pwd)/bin/apktool/apktool.jar"

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
    echo "❌ Device script not found: $DEVICE_SCRIPT"
    exit 1
fi

echo "▶ Running device script: $DEVICE_SCRIPT"
chmod +x "$DEVICE_SCRIPT"
bash "$DEVICE_SCRIPT" "$EXTRACTED"
echo "✅ Device script executed"

echo "--------------------------------------------"

# -----------------------------
# Apply H3CKED Mods
# -----------------------------
H3CKED_OVERLAY="H3CKED/Mods"

if [ -d "$H3CKED_OVERLAY" ]; then
    echo "📦 Applying H3CKED Mods..."

    for MOD in "$H3CKED_OVERLAY"/*; do
        MOD_NAME=$(basename "$MOD")
        echo "🧩 Applying Mod: $MOD_NAME"
        rsync -av "$MOD"/ "$EXTRACTED"/
        echo "✅ Finished: $MOD_NAME"
        echo "--------------------------------------------"
    done

    echo "🎉 All H3CKED mods applied successfully"
else
    echo "ℹ️ No H3CKED overlay found, skipping..."
fi

# -----------------------------
# Install Framework
# -----------------------------
echo "Installing Framework..."
java -jar "$APKTOOL" install-framework \
"$EXTRACTED/system/system/framework/framework-res.apk"

echo "============================================"
echo "✅ H3CKED Port Finished Successfully"
echo "============================================"