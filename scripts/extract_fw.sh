#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FIRMWARE_DIRECTORY>"
    exit 1
fi

FIRM_DIR="$(realpath "$1")"

if [[ ! -d "$FIRM_DIR" ]]; then
    echo "[!] Directory not found: $FIRM_DIR"
    exit 1
fi

echo ""
echo "============================================"
echo "🔧 Firmware Extraction Started"
echo "📂 Working Directory: $FIRM_DIR"
echo "============================================"
echo ""

archive_count=0
super_count=0
partition_count=0

# ------------------------------------------------
# Rename .md5
# ------------------------------------------------
find "$FIRM_DIR" -type f -name "*.md5" | while read -r f; do
    mv -- "$f" "${f%.md5}"
    echo "→ Renamed: $(basename "$f")"
done

# ------------------------------------------------
# Extract archives recursively
# ------------------------------------------------
while true; do
    extracted_this_round=0

    while read -r f; do
        echo "→ Extracting TAR: $(basename "$f")"
        tar -xf "$f" -C "$(dirname "$f")"
        archive_count=$((archive_count+1))
        extracted_this_round=1
    done < <(find "$FIRM_DIR" -type f -name "*.tar")

    while read -r f; do
        echo "→ Decompressing LZ4: $(basename "$f")"
        lz4 -d "$f" "${f%.lz4}" >/dev/null
        archive_count=$((archive_count+1))
        extracted_this_round=1
    done < <(find "$FIRM_DIR" -type f -name "*.lz4")

    if [[ "$extracted_this_round" -eq 0 ]]; then
        break
    fi
done

# ------------------------------------------------
# Extract super.img
# ------------------------------------------------
while read -r f; do
    dir="$(dirname "$f")"
    echo ""
    echo "→ Processing super.img in: $dir"

    simg2img "$f" "$dir/super_raw.img"
    lpunpack -o "$dir" "$dir/super_raw.img"

    super_count=$((super_count+1))
done < <(find "$FIRM_DIR" -type f -name "super.img")

# ------------------------------------------------
# Extract partitions
# ------------------------------------------------
while read -r imgfile; do
    name="$(basename "$imgfile")"

    # Skip boot / vbmeta / super
    if [[ "$name" == super* ]] || [[ "$name" == boot* ]] || [[ "$name" == vbmeta* ]]; then
        continue
    fi

    echo ""
    echo "→ Extracting partition: $name"

    if file -b "$imgfile" | grep -qi "ext4"; then
        echo "  Detected ext4"
        python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$(dirname "$imgfile")"
        partition_count=$((partition_count+1))

    elif file -b "$imgfile" | grep -qi "erofs"; then
        echo "  Detected EROFS"
        "$(pwd)/bin/erofs-utils/extract.erofs" \
            -i "$imgfile" -x -f -o "$(dirname "$imgfile")"
        partition_count=$((partition_count+1))

    else
        echo "  ⚠ Unknown filesystem — skipped"
    fi

done < <(find "$FIRM_DIR" -type f -name "*.img")

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "============================================"
echo "📊 EXTRACTION SUMMARY"
echo "📂 Directory: $FIRM_DIR"
echo "📦 Archives extracted: $archive_count"
echo "🧩 super.img processed: $super_count"
echo "📁 Partitions extracted: $partition_count"
echo "============================================"
echo "✅ Firmware extraction complete!"
