#!/usr/bin/env bash
set -e

EXTRACTED="$1"

if [ -z "$EXTRACTED" ]; then
    echo "Usage: $0 <extracted_firmware_dir>"
    exit 1
fi

echo "---------------------------------"
echo "Applying device specific tweaks"
echo "---------------------------------"
echo

remove() {
    if [ -e "$1" ]; then
        rm -rf "$1"
        echo "[REMOVED] $1"
    else
        echo "[SKIPPED] $1"
    fi
}

# =========================
# Camera
# =========================
remove "$EXTRACTED/system/system/cameradata"
remove "$EXTRACTED/system/system/priv-app/SamsungCamera"

# =========================
# eSIM Components
# =========================
remove "$EXTRACTED/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
remove "$EXTRACTED/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
remove "$EXTRACTED/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
remove "$EXTRACTED/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
remove "$EXTRACTED/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
remove "$EXTRACTED/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
remove "$EXTRACTED/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
remove "$EXTRACTED/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
remove "$EXTRACTED/system/system/priv-app/EsimClient"
remove "$EXTRACTED/system/system/priv-app/EsimKeyString"
remove "$EXTRACTED/system/system/priv-app/EuiccService"
remove "$EXTRACTED/system/system/priv-app/EuiccGoogle"

# =========================
# Fabric Crypto / Knox Keymaster
# =========================
remove "$EXTRACTED/system/system/bin/fabric_crypto"
remove "$EXTRACTED/system/system/etc/init/fabric_crypto.rc"
remove "$EXTRACTED/system/system/etc/permissions/FabricCryptoLib.xml"
remove "$EXTRACTED/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
remove "$EXTRACTED/system/system/framework/FabricCryptoLib.jar"
remove "$EXTRACTED/system/system/framework/oat/arm/FabricCryptoLib.odex"
remove "$EXTRACTED/system/system/framework/oat/arm/FabricCryptoLib.vdex"
remove "$EXTRACTED/system/system/framework/oat/arm64/FabricCryptoLib.odex"
remove "$EXTRACTED/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
remove "$EXTRACTED/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
remove "$EXTRACTED/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
remove "$EXTRACTED/system/system/priv-app/KmxService"

echo
echo "Completed successfully."