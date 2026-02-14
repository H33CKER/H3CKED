#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ===================================================================
# Samsung Firmware Downloader
# ===================================================================
# Usage:
#   ./download_fw.sh <MODEL> <CSC> <IMEI> <DOWNLOAD_DIR>
# ===================================================================

DOWNLOAD_FIRMWARE() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/${MODEL}"

    # --- Validate IMEI format ---
    if ! [[ "$IMEI" =~ ^[0-9]{15}$ ]]; then
        echo "❌ Invalid IMEI format (must be 15 digits)."
        return 1
    fi

    # --- Check samloader installed ---
    if ! python3 -m samloader --help >/dev/null 2>&1; then
        echo "❌ samloader not installed."
        echo "Install with: pip install samloader"
        return 1
    fi

    # --- Create download dir ---
    mkdir -p "$DOWN_DIR"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      H3CKED Samsung Firmware Downloader"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MODEL: $MODEL | CSC: $CSC | IMEI: ************${IMEI: -4}"
    echo "Fetching latest firmware..."
    echo

    # --- Step 1: Check update ---
    local version
    version=$(python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" checkupdate 2>/dev/null | tail -n 1) || {
        echo "❌ MODEL/CSC/IMEI not valid or no update found."
        return 1
    }
    echo "✅ Update found: $version"

    # --- Step 2: Download firmware with multi-threading & resume ---
    echo "Downloading firmware (multi-threaded, resuming if interrupted)..."
    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download \
        -v "$version" \
        -O "$DOWN_DIR" \
        --workers 8 \
        --resume || {
        echo "❌ Download failed. Check IMEI/MODEL/CSC or your internet connection."
        return 1
    }

    # --- Step 3: Decrypt firmware ---
    local enc_file
    enc_file=$(find "$DOWN_DIR" -name "*.enc*" | head -n 1)

    if [ -z "$enc_file" ]; then
        echo "❌ No encrypted firmware file found!"
        return 1
    fi

    echo "Decrypting firmware..."
    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" decrypt \
        -v "$version" \
        -i "$enc_file" \
        -o "${DOWN_DIR}/${MODEL}.zip" || {
        echo "❌ Decryption failed."
        return 1
    }

    # --- Step 4: Show info ---
    local file_size
    file_size=$(du -m "${DOWN_DIR}/${MODEL}.zip" | cut -f1)
    echo
    echo "✅ Firmware decrypted successfully!"
    echo "Firmware Size: ${file_size} MB"
    echo "Saved to: ${DOWN_DIR}/${MODEL}.zip"

    # --- Step 5: Cleanup ---
    rm -f "$enc_file"
}

# ===================================================================
# Main entrypoint for script execution
# ===================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    DOWNLOAD_FIRMWARE "$@"
fi