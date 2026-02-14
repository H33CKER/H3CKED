#!/bin/bash
set -e

# --------------------------------------------
# extract_fw.sh
# Extracts firmware files and prepares partitions
# Fully configurable via 'config' file
# Usage: ./extract_fw.sh <FIRMWARE_DIRECTORY>
# --------------------------------------------

# Check input
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FIRMWARE_DIRECTORY>"
    exit 1
fi
FIRM_DIR="$1"

# --------------------------------------------
# Load configuration
# --------------------------------------------
CONFIG_FILE="config"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "🔧 Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "[!] No config file found. Please create a 'config' file."
    exit 1
fi

# Validate partitions
if [[ -z "$PORT_PARTITIONS" ]]; then
    echo "[!] PORT_PARTITIONS is not set in config. Exiting."
    exit 1
fi

# Default super.img behavior if not set
if [[ -z "$EXTRACT_SUPER" ]]; then
    EXTRACT_SUPER="yes"
fi

# --------------------------------------------
# Function: Extract firmware archives
# --------------------------------------------
extract_firmware() {
    echo "🔧 Extracting downloaded firmware from $FIRM_DIR"

    # Zip
    echo "- Extracting zip files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.zip" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -f "$FIRM_DIR"/*.zip

    # XZ
    echo "- Extracting xz files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.xz" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -f "$FIRM_DIR"/*.xz

    # MD5 rename
    echo "- Renaming .md5 files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.md5" \
        -exec sh -c 'mv -- "$1" "${1%.md5}"' _ {} \;

    # Tar
    echo "- Extracting tar files..."
    for file in "$FIRM_DIR"/*.tar; do
        [ -f "$file" ] || continue
        tar -xvf "$file" -C "$FIRM_DIR" >/dev/null 2>&1
        rm -f "$file"
    done

    # LZ4
    echo "- Extracting lz4 files..."
    for file in "$FIRM_DIR"/*.lz4; do
        [ -f "$file" ] || continue
        lz4 -d "$file" "${file%.lz4}" >/dev/null 2>&
