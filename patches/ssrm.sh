#!/bin/bash
CONFIG_FILE="$DEVICE_DIR/config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Device config not found: $CONFIG_FILE"
    exit 1
fi

echo "📦 Loading device config for $STOCK_DEVICE"
source "$CONFIG_FILE"

echo "SIOP: $STOCK_SIOP_FILENAME"
echo "DVFS: $STOCK_DVFS_FILENAME"

echo ""
echo "📦 Decompiling ssrm.jar..."

SSR_JAR="$EXTRACTED/system/system/framework/ssrm.jar"
SSR_OUT="$EXTRACTED/system/system/framework/ssrm.jar.out"

rm -rf "$SSR_OUT"
apktool d -f "$SSR_JAR" -o "$SSR_OUT"

echo "✅ ssrm.jar decompiled → $SSR_OUT"
echo "--------------------------------------------"

echo ""
echo "🔧 Patching SSRM..."

FILE="$SSR_OUT/smali/com/android/server/ssrm/Feature.smali"

echo "- Updating SIOP → $STOCK_SIOP_FILENAME"
echo "- Updating DVFS → $STOCK_DVFS_FILENAME"

sed -i "s/\(const-string v[0-9]\+,\s*\"\)siop_[^\"]*\"/\1$STOCK_SIOP_FILENAME\"/g" "$FILE"
sed -i "/dvfs_policy_default/! s/\(const-string v[0-9]\+,\s*\"\)dvfs_policy_[^\"]*\"/\1$STOCK_DVFS_FILENAME\"/g" "$FILE"

echo "✅ SSRM patched"
echo "--------------------------------------------"

echo "🔨 Recompiling ssrm.jar..."

apktool b "$SSR_OUT" -o "$SSR_JAR" || { echo "❌ Rebuild failed"; exit 1; }

echo "✅ ssrm.jar rebuilt successfully → $SSR_JAR"
echo "--------------------------------------------"
