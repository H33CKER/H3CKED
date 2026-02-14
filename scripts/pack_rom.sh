#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------
# pack_rom.sh
# Builds partition images (ext4 or erofs) from extracted firmware
# Usage: ./pack_rom.sh <EXTRACTED_FIRM_DIR> <FILE_SYSTEM> <OUT_DIR>
# --------------------------------------------

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <EXTRACTED_FIRM_DIR> <FILE_SYSTEM: ext4|erofs> <OUT_DIR>"
    exit 1
fi

EXTRACTED_FIRM_DIR="$1"
FILE_SYSTEM="$2"
OUT_DIR="$3"

[ ! -d "$EXTRACTED_FIRM_DIR" ] && { echo "[ERROR] $EXTRACTED_FIRM_DIR not found"; exit 1; }
mkdir -p "$OUT_DIR"

CONFIG_DIR="$EXTRACTED_FIRM_DIR/config"
mkdir -p "$CONFIG_DIR"

# --------------------------------------------
# Generate FS Config
# --------------------------------------------
generate_fs_config() {
    echo "🔧 Generating fs_config files..."
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue
        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue

        FS_CONFIG="$CONFIG_DIR/${PARTITION}_fs_config"
        TMP_EXISTING=$(mktemp)
        touch "$FS_CONFIG"

        echo ""
        echo "  ➤ Partition: $PARTITION"

        awk '{print $1}' "$FS_CONFIG" | sort -u > "$TMP_EXISTING"

        find "$ROOT" -mindepth 1 \( -type f -o -type d \) | while IFS= read -r item; do
            REL_PATH="${item#$ROOT/}"
            PATH_ENTRY="$PARTITION/$REL_PATH"
            grep -qxF "$PATH_ENTRY" "$TMP_EXISTING" && continue

            if [ -d "$item" ]; then
                printf "%s 0 0 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            else
                printf "%s 0 0 0644\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            fi
        done

        rm -f "$TMP_EXISTING"
        echo "    ✅ fs_config generated for $PARTITION"
    done
}

# --------------------------------------------
# Generate file_contexts
# --------------------------------------------
generate_file_contexts() {
    echo "🔧 Generating file_contexts..."
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue
        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue

        FILE_CONTEXTS="$CONFIG_DIR/${PARTITION}_file_contexts"
        touch "$FILE_CONTEXTS"

        echo ""
        echo "  ➤ Partition: $PARTITION"

        declare -A EXISTING=()
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            PATH_ONLY=$(echo "$line" | awk '{print $1}')
            EXISTING["$PATH_ONLY"]=1
        done < "$FILE_CONTEXTS"

        find "$ROOT" -mindepth 1 \( -type f -o -type d \) | while IFS= read -r item; do
            REL_PATH="${item#$ROOT}"
            PATH_ENTRY="/$PARTITION$REL_PATH"
            ESCAPED_PATH=$(echo "$PATH_ENTRY" | sed -e 's/[.+]/\\&/g')

            [ "${EXISTING[$ESCAPED_PATH]+exists}" ] && continue

            printf "%s u:object_r:system_file:s0\n" "$ESCAPED_PATH" >> "$FILE_CONTEXTS"
            EXISTING["$ESCAPED_PATH"]=1
        done

        echo "    ✅ file_contexts generated for $PARTITION"
        unset EXISTING
    done
}

# --------------------------------------------
# Build partition images
# --------------------------------------------
build_images() {
    echo "🔧 Building images ($FILE_SYSTEM)..."
    generate_fs_config
    generate_file_contexts

    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$PART" ]] || continue
        PARTITION="$(basename "$PART")"
        [[ "$PARTITION" == "config" ]] && continue

        SRC_DIR="$EXTRACTED_FIRM_DIR/$PARTITION"
        OUT_IMG="$OUT_DIR/${PARTITION}.img"
        FS_CONFIG="$CONFIG_DIR/${PARTITION}_fs_config"
        FILE_CONTEXTS="$CONFIG_DIR/${PARTITION}_file_contexts"

        [[ -f "$FS_CONFIG" ]] || { echo "[WARNING] $FS_CONFIG missing, skipping $PARTITION"; continue; }
        [[ -f "$FILE_CONTEXTS" ]] || { echo_]()]()
