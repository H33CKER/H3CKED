#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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
CONFIG_FILE="scripts/config.txt"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "🔧 Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "[!] No config file found. Please create a 'config' file."
    exit 1
fi

# Validate partitions
if [[ -z "${PORT_PARTITIONS:-}" ]]; then
    echo "[!] PORT_PARTITIONS is not set in config. Exiting."
    exit 1
fi

# Default super.img behavior if not set
EXTRACT_SUPER="${EXTRACT_SUPER:-yes}"

# --------------------------------------------
# Function: Extract firmware archives
# --------------------------------------------
extract_firmware() {
    echo "🔧 Extracting downloaded firmware from $FIRM_DIR"

    # --- Zip ---
    zip_count=$(find "$FIRM_DIR" -maxdepth 1 -name "*.zip" | wc -l)
    echo "- Found $zip_count zip files"
    if [ "$zip_count" -gt 0 ]; then
        for f in "$FIRM_DIR"/*.zip; do
            echo "  → Extracting $f ..."
            7z x -y -bd -o"$FIRM_DIR" "$f" >/dev/null 2>&1
            rm -f "$f"
        done
    fi

    # --- XZ ---
    xz_count=$(find "$FIRM_DIR" -maxdepth 1 -name "*.xz" | wc -l)
    echo "- Found $xz_count xz files"
    if [ "$xz_count" -gt 0 ]; then
        for f in "$FIRM_DIR"/*.xz; do
            echo "  → Extracting $f ..."
            7z x -y -bd -o"$FIRM_DIR" "$f" >/dev/null 2>&1
            rm -f "$f"
        done
    fi

    # --- MD5 rename ---
    md5_count=$(find "$FIRM_DIR" -maxdepth 1 -name "*.md5" | wc -l)
    echo "- Found $md5_count .md5 files, renaming..."
    for f in "$FIRM_DIR"/*.md5; do
        [ -f "$f" ] || continue
        mv -- "$f" "${f%.md5}"
        echo "  → Renamed $f"
    done

    # --- Tar ---
    tar_count=$(find "$FIRM_DIR" -maxdepth 1 -name "*.tar" | wc -l)
    echo "- Found $tar_count tar files"
    for f in "$FIRM_DIR"/*.tar; do
        [ -f "$f" ] || continue
        echo "  → Extracting $f ..."
        tar -xvf "$f" -C "$FIRM_DIR" >/dev/null 2>&1
        rm -f "$f"
    done

    # --- LZ4 ---
    lz4_count=$(find "$FIRM_DIR" -maxdepth 1 -name "*.lz4" | wc -l)
    echo "- Found $lz4_count lz4 files"
    for f in "$FIRM_DIR"/*.lz4; do
        [ -f "$f" ] || continue
        echo "  → Decompressing $f ..."
        lz4 -d "$f" "${f%.lz4}" >/dev/null 2>&1
        rm -f "$f"
    done

    # --- Remove unwanted files ---
    echo "- Cleaning up unnecessary files..."
    rm -f "$FIRM_DIR"/*.txt "$FIRM_DIR"/*.pit "$FIRM_DIR"/*.bin
    rm -rf "$FIRM_DIR/meta-data"

    # --- Optional super.img extraction ---
    if [[ "$EXTRACT_SUPER" == "yes" && -f "$FIRM_DIR/super.img" ]]; then
        echo "- Extracting super.img ..."
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        lpunpack -o "$FIRM_DIR" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        echo "✅ super.img extraction complete"
    fi

    echo "✅ Firmware archive extraction complete!"
}

# --------------------------------------------
# Function: Prepare partitions
# --------------------------------------------
prepare_partitions() {
    IFS=',' read -r -a KEEP <<< "$PORT_PARTITIONS"
    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo "${KEEP[$i]}" | xargs)
    done

    echo "🔧 Preparing partitions: ${KEEP[*]}"

    shopt -s nullglob dotglob
    for item in "$FIRM_DIR"/*; do
        base=$(basename "$item")
        [[ "$base" == *.img ]] && base="${base%.img}"

        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done

        if [[ $keep_this -eq 0 ]]; then
            echo "  → Removing: $item"
            rm -rf -- "$item"
        else
            echo "  → Keeping: $item"
        fi
    done
    shopt -u nullglob dotglob
}

# --------------------------------------------
# Function: Extract images from firmware
# --------------------------------------------
extract_firmware_img() {
    echo ""
    echo "🔧 Extracting images from $FIRM_DIR"

    for imgfile in "$FIRM_DIR"/*.img; do
        [ -e "$imgfile" ] || continue
        [[ "$(basename "$imgfile")" == "boot.img" ]] && continue

        partition="$(basename "${imgfile%.img}")"
        fstype=$(file -b "$imgfile" | awk '{print $1}')
        IMG_SIZE=$(stat -c%s -- "$imgfile")

        echo "- Processing $partition ($fstype), size: $IMG_SIZE bytes"

        case "$fstype" in
            ext4)
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"
                echo "✅ Finished extracting $partition"
                ;;
            EROFS)
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
                echo "✅ Finished extracting $partition"
                ;;
            *)
                echo "[!] Unknown filesystem type ($fstype) for $imgfile, skipping"
                ;;
        esac
    done

    echo "- Removing original .img files..."
    rm -f "$FIRM_DIR"/*.img
}

# --------------------------------------------
# Execute all steps
# --------------------------------------------
echo "🔧 Starting firmware extraction process..."
extract_firmware
prepare_partitions
extract_firmware_img
echo "✅ All firmware extraction and preparation steps complete!"
