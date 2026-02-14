#!/bin/bash
set -e

# --------------------------------------------
# extract_fw.sh
# Extracts firmware files and prepares partitions
# Usage: ./extract_fw.sh <FIRMWARE_DIRECTORY>
# --------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FIRMWARE_DIRECTORY>"
    exit 1
fi

FIRM_DIR="$1"

# --------------------------------------------
# Function: Extract firmware archives
# --------------------------------------------
extract_firmware() {
    echo "🔧 Extracting downloaded firmware from $FIRM_DIR"

    # ---- Extract zip files ----
    echo "- Extracting zip files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.zip" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -f "$FIRM_DIR"/*.zip

    # ---- Extract xz files ----
    echo "- Extracting xz files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.xz" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -f "$FIRM_DIR"/*.xz

    # ---- Rename MD5 files ----
    echo "- Renaming .md5 files..."
    find "$FIRM_DIR" -maxdepth 1 -name "*.md5" \
        -exec sh -c 'mv -- "$1" "${1%.md5}"' _ {} \;

    # ---- Extract tar files ----
    echo "- Extracting tar files..."
    for file in "$FIRM_DIR"/*.tar; do
        [ -f "$file" ] || continue
        tar -xvf "$file" -C "$FIRM_DIR" >/dev/null 2>&1
        rm -f "$file"
    done

    # ---- Extract lz4 files ----
    echo "- Extracting lz4 files..."
    for file in "$FIRM_DIR"/*.lz4; do
        [ -f "$file" ] || continue
        lz4 -d "$file" "${file%.lz4}" >/dev/null 2>&1
    done
    rm -f "$FIRM_DIR"/*.lz4

    # ---- Remove unwanted files ----
    echo "- Removing unwanted files..."
    rm -f "$FIRM_DIR"/*.txt
    rm -f "$FIRM_DIR"/*.pit
    rm -f "$FIRM_DIR"/*.bin
    rm -rf "$FIRM_DIR"/meta-data

    # ---- Extract super.img if exists ----
    if [ -f "$FIRM_DIR/super.img" ]; then
        echo "- Extracting super.img..."
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super.img"
        lpunpack -o "$FIRM_DIR" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super_raw.img"
        echo "- super.img extraction complete"
    fi

    echo "✅ Firmware extraction complete!"
}

# --------------------------------------------
# Function: Prepare partitions
# --------------------------------------------
prepare_partitions() {
    echo ""
    if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,product,system_ext,system,vendor"
    fi

    local EXTRACTED_FIRM_DIR="$1"
    [[ -z "$EXTRACTED_FIRM_DIR" || ! -d "$EXTRACTED_FIRM_DIR" ]] && {
        echo "[!] Invalid directory: $EXTRACTED_FIRM_DIR"
        exit 1
    }

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"

    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo "${KEEP[$i]}" | xargs)
    done

    echo "🔧 Preparing partitions..."

    shopt -s nullglob dotglob

    for item in "$EXTRACTED_FIRM_DIR"/*; do
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
    local FIRM_DIR="$1"

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
                echo "Extracting $imgfile in $FIRM_DIR/$partition"
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"
                ;;
            EROFS)
                echo "$imgfile detected $fstype. Size: $IMG_SIZE bytes."
                echo "Extracting $imgfile in $FIRM_DIR/$partition"
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
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
extract_firmware "$FIRM_DIR"
prepare_partitions "$FIRM_DIR"
extract_firmware_img "$FIRM_DIR"
echo "✅ All firmware extraction and preparation steps complete!"
