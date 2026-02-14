#!/bin/bash
set -e

# 🛠 Update package lists
echo "🔧 Updating package lists..."
sudo apt update -y

# 📦 Install system packages
echo "📦 Installing system packages..."
sudo apt install -y \
    p7zip-full \
    android-sdk-libsparse-utils \
    python3 \
    python3-pip \
    zipalign \
    unzip \
    e2fsprogs \
    openjdk-17-jdk

# 🐍 Upgrade pip
echo "🐍 Upgrading pip..."
python3 -m pip install --upgrade --user pip

# 🐍 Install Python packages
echo "🐍 Installing Python packages..."
python3 -m pip install --user \
    liblp \
    tgcrypto \
    pyrogram \
    pysocks \
    git+https://github.com/martinetd/samloader.git \
    tqdm \
    pycryptodomex

# 🔐 Make binaries executable
echo "🔐 Making binaries executable..."
for f in bin/ext4/make_ext4fs bin/erofs-utils/extract.erofs bin/erofs-utils/mkfs.erofs; do
    if [ -f "$f" ]; then
        chmod +x "$f"
    else
        echo "[!] Warning: $f not found"
    fi
done

echo "✅ Dependencies installed successfully!"
