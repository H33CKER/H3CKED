#!/bin/bash
set -e

echo "🔧 Updating package lists..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq

echo "📦 Installing system packages..."
sudo apt-get install -y -qq \
    p7zip-full \
    lz4 \
    android-sdk-libsparse-utils \
    python3 \
    python3-pip \
    zipalign \
    unzip \
    e2fsprogs \
    openjdk-17-jdk

echo "🐍 Upgrading pip..."
python3 -m pip install --upgrade pip

echo "🐍 Installing Python packages..."
pip3 install --no-cache-dir --upgrade liblp tgcrypto pyrogram
pip3 install --no-cache-dir --upgrade git+https://github.com/martinetd/samloader.git

echo "🔐 Making binaries executable..."
for f in bin/ext4/make_ext4fs bin/erofs-utils/extract.erofs bin/erofs-utils/mkfs.erofs; do
    [ -f "$f" ] && chmod +x "$f"
done

echo "✅ Dependency installation complete."
