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
CONFIG_FILE="scripts/config.txt"
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
        lz4 -d "$file" "${file%.lz4}" >/dev/null 2>&1
    done
    rm -f "$FIRM_DIR"/*.lz4

    # Remove unwanted files
    echo "- Removing unwanted files..."
    rm -f "$FIRM_DIR"/*.txt
    rm -f "$FIRM_DIR"/*.pit
    rm -f "$FIRM_DIR"/*.bin
    rm -rf "$FIRM_DIR"/meta-data

    # Optional super.img extraction
    if [[ "$EXTRACT_SUPER" == "yes" && -f "$FIRM_DIR/super.img" ]]; then
        echo "- Extracting super.img..."
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super.img"
        lpunpack -o "$FIRM_DIR" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super_raw.img"
        echo "✅ super.img extraction complete"
    fi

    echo "✅ Firmware archive extraction complete!"
}

# --------------------------------------------
# Function: Prepare partitions based on config
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
            rm -rf -- "$item"
        else
            echo "- Keeping: $item"
        fi
    done
    shopt -u nullglob dotglob
}

# --------------------------------------------
# Function: Extract firmware images
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

        case "$fstype" in
            ext4)
                echo "$imgfile detected $fstype. Size: $IMG_SIZE bytes."
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"
                echo "✅ Finished extracting $partition"
                ;;
            EROFS)
                echo "$imgfile detected $fstype. Size: $IMG_SIZE bytes."
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
                echo "✅ Finished extracting $partition"
                ;;
            *)
                echo "[!] Unknown filesystem type ($fstype) for $imgfile, skipping"
                ;;
        esac
    done

    # Remove all original .img files
    rm -f "$FIRM_DIR"/*.img
}

# --------------------------------------------
# Execute all steps
# --------------------------------------------
extract_firmware
prepare_partitions
extract_firmware_img

echo "✅ All firmware extraction and preparation steps complete!"
