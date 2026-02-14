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
echo "🔧 Samsung Firmware Extraction Started"
echo "📂 Working Directory: $FIRM_DIR"
echo "============================================"
echo ""

archive_count=0
super_count=0
partition_count=0

# ------------------------------------------------
# 1️⃣ Rename .md5
# ------------------------------------------------
while read -r f; do
    mv -- "$f" "${f%.md5}"
    echo "→ Renamed: $(basename "$f")"
done < <(find "$FIRM_DIR" -type f -name "*.md5")

# ------------------------------------------------
# 2️⃣ Extract ZIP (once)
# ------------------------------------------------
while read -r f; do
    echo "→ Extracting ZIP: $(basename "$f")"
    7z x -y -bd -o"$(dirname "$f")" "$f" >/dev/null
    rm -f "$f"
    archive_count=$((archive_count+1))
done < <(find "$FIRM_DIR" -type f -name "*.zip")

# ------------------------------------------------
# 3️⃣ Extract TAR (once)
# ------------------------------------------------
while read -r f; do
    echo "→ Extracting TAR: $(basename "$f")"
    tar -xf "$f" -C "$(dirname "$f")"
    rm -f "$f"
    archive_count=$((archive_count+1))
done < <(find "$FIRM_DIR" -type f -name "*.tar")

# ------------------------------------------------
# 4️⃣ Decompress super.img.lz4
# ------------------------------------------------
while read -r f; do
    echo "→ Decompressing LZ4: $(basename "$f")"
    lz4 -d "$f" "${f%.lz4}" >/dev/null
    rm -f "$f"
    archive_count=$((archive_count+1))
done < <(find "$FIRM_DIR" -type f -name "super.img.lz4")

# ------------------------------------------------
# 5️⃣ Extract super.img
# ------------------------------------------------
while read -r f; do
    dir="$(dirname "$f")"
    echo ""
    echo "→ Processing super.img in: $dir"

    simg2img "$f" "$dir/super_raw.img"
    lpunpack -o "$dir" "$dir/super_raw.img"
    rm -f "$dir/super_raw.img"

    super_count=$((super_count+1))
done < <(find "$FIRM_DIR" -type f -name "super.img")

# ------------------------------------------------
# 6️⃣ Extract logical partitions
# ------------------------------------------------
while read -r imgfile; do
    name="$(basename "$imgfile")"

    # Skip non-system partitions
    if [[ "$name" == super* ]] || \
       [[ "$name" == boot* ]] || \
       [[ "$name" == vbmeta* ]] || \
       [[ "$name" == dtbo* ]]; then
        continue
    fi

    echo ""
    echo "→ Extracting partition: $name"

    if file -b "$imgfile" | grep -qi "ext4"; then
        echo "  Detected ext4"
        python3 "$(pwd)/bin/py_scripts/imgextractor.py" \
            "$imgfile" "$(dirname "$imgfile")"
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
echo "📦 Archives processed: $archive_count"
echo "🧩 super.img processed: $super_count"
echo "📁 Partitions extracted: $partition_count"
echo "============================================"
echo "✅ Samsung firmware extraction complete!"
echo ""
