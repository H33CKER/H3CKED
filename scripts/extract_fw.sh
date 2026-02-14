#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

FIRM_DIR="$(realpath "$1")"

echo ""
echo "============================================"
echo "🔧 Samsung Firmware Extraction Started"
echo "📂 Working Directory: $FIRM_DIR"
echo "============================================"
echo ""

# Load config
source scripts/config.txt
# Convert comma-separated list to space-separated
IFS=',' read -ra PART_ARRAY <<< "$PORT_PARTITIONS"

archive_count=0
super_count=0
partition_count=0

cd "$FIRM_DIR"

# ------------------------------------------------
# 1️⃣ Extract ZIP
# ------------------------------------------------
if compgen -G "*.zip" > /dev/null; then
    for zip in *.zip; do
        echo "→ Extracting ZIP: $zip"
        7z x -y "$zip" >/dev/null
        rm -f "$zip"
        archive_count=$((archive_count+1))
    done
fi

# ------------------------------------------------
# 2️⃣ Rename md5 → tar
# ------------------------------------------------
for f in *.md5; do
    [ -f "$f" ] || continue
    mv "$f" "${f%.md5}"
    echo "→ Renamed: $f"
done

# ------------------------------------------------
# 3️⃣ Extract all TAR
# ------------------------------------------------
if compgen -G "*.tar" > /dev/null; then
    for tarfile in *.tar; do
        echo "→ Extracting TAR: $tarfile"
        tar -xf "$tarfile"
        rm -f "$tarfile"
        archive_count=$((archive_count+1))
    done
fi

# ------------------------------------------------
# 4️⃣ Decompress super.img.lz4
# ------------------------------------------------
if [ -f "super.img.lz4" ]; then
    echo "→ Decompressing super.img.lz4"
    lz4 -d super.img.lz4 super.img >/dev/null
    rm -f super.img.lz4
fi

# ------------------------------------------------
# 5️⃣ Process super.img
# ------------------------------------------------
if [ -f "super.img" ]; then
    echo "→ Processing super.img"
    simg2img super.img super_raw.img
    lpunpack super_raw.img
    rm -f super_raw.img
    super_count=1
fi

# ------------------------------------------------
# 6️⃣ Extract partitions
# ------------------------------------------------

for part in "${PART_ARRAY[@]}"; do
    img="${part}.img"

    [ -f "$img" ] || continue

    echo "→ Extracting partition: $img"

    if file -b "$img" | grep -qi ext4; then
        python3 "$(pwd)/../../bin/py_scripts/imgextractor.py" \
            "$img" "$(pwd)"
        partition_count=$((partition_count+1))

    elif file -b "$img" | grep -qi erofs; then
        "$(pwd)/../../bin/erofs-utils/extract.erofs" \
            -i "$img" -x -f -o "$(pwd)"
        partition_count=$((partition_count+1))
    fi
done

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "============================================"
echo "📊 EXTRACTION SUMMARY"
echo "📂 Directory: $(pwd)"
echo "📦 Archives processed: $archive_count"
echo "🧩 super.img processed: $super_count"
echo "📁 Partitions extracted: $partition_count"
echo "============================================"
echo "✅ Samsung firmware extraction complete!"
echo ""
