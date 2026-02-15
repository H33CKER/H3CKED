#!/usr/bin/env bash
set -e

EXTRACTED="$1"

echo "Applying device specific tweaks"

[ -d "$EXTRACTED/system/system/cameradata" ] && \
  rm -rf "$EXTRACTED/system/system/cameradata"

[ -d "$EXTRACTED/system/system/priv-app/SamsungCamera" ] && \
  rm -rf "$EXTRACTED/system/system/priv-app/SamsungCamera"

echo "Completed successfully"
