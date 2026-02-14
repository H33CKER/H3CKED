#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FIRMWARE_DIRECTORY>"
    exit 1
fi

FIRM_DIR="$1"

if [[ ! -d "$FIRM_DIR" ]]; then
    echo "[!] Directory not found: $FIRM_DIR"
    exit 1
fi

echo "🔧 Starting Samsung firmware processing..."

# ------------------------------------------------
# Step 1 — Rename .md5
# ------------------------------------------------
rename_md5() {
    for f in "$FIRM_DIR"/*.md5; do
        [ -f "$f" ] || continue
        mv -- "$f" "${f%.md5}"
        echo "→ Renamed $(basename "$f")"
    done
}

# ------------------------------------------------
# Step 2 — Extract TAR archives
# ------------------------------------------------
extract_tar() {
    for f in "$FIRM_DIR"/*.tar; do
        [ -f "$f" ] || continue
        echo "→ Extracting $(basename "$f")"
        tar -xf "$f" -C "$FIRM_DIR"
    done
}

# ------------------------------------------------
# Step 3 — Extract super.img.lz4
# ------------------------------------------------
extract_lz4() {
    for f in "$FIRM_DIR"/*.lz4; do
        [ -f "$f" ] || continue
        echo "→ Decompressing $(basename "$f")"
        lz4 -d "$f" "${f%.lz4}"
    done
}

# ------------------------------------------------
# Step 4 — Extract super.img
# ------------------------------------------------
extract_super() {
    if [[ -f "$FIRM_DIR/super.img" ]]; then
        echo "→ Converting super.img to raw"
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"

        echo "→ Unpacking logical partitions"
        lpunpack -o "$FIRM_DIR" "$FIRM_DIR/super_raw.img"

        echo "✅ super.img unpacked"
    fi
}

# ------------------------------------------------
# Step 5 — Extract filesystem images
# ------------------------------------------------
extract_partitions() {

    for imgfile in "$FIRM_DIR"/*.img; do
        [ -f "$imgfile" ] || continue

        name="$(basename "$imgfile")"

        # Skip super and boot type images
        if [[ "$name" == super* ]] || [[ "$name" == boot* ]] || [[ "$name" == vbmeta* ]]; then
            continue
        fi

        echo ""
        echo "→ Processing $name"

        if file -b "$imgfile" | grep -qi "ext4"; then
            echo "  Detected ext4"
            python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"

        elif file -b "$imgfile" | grep -qi "erofs"; then
            echo "  Detected EROFS"
            "$(pwd)/bin/erofs-utils/extract.erofs" \
                -i "$imgfile" -x -f -o "$FIRM_DIR"

        else
            echo "  ⚠ Unknown filesystem — skipped"
        fi
    done

    echo ""
    echo "✅ Partition extraction complete"
}

# ------------------------------------------------
# Execute in strict order
# ------------------------------------------------
rename_md5
extract_tar
extract_lz4
extract_super
extract_partitions

echo ""
echo "🎉 Firmware fully processed (Samsung chain complete)"
