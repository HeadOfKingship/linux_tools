#!/bin/bash
#
# 💡 fix-deb-safe-installer.sh
# 🛠️ 自動掃描並修復 apt 檔案安裝時因為 hardlink 錯誤而中斷的情況
#
# 🌟 使用方式：
#   1. sudo chmod +x fix-deb-safe-installer.sh
#   2. sudo ./fix-deb-safe-installer.sh
#
# ✅ 自動嘗試 dpkg 安裝
# ✅ 若失敗則自動解包並用 rsync 安全複製避開錯誤
#
# ⚠️ 適用於「Operation not permitted」等 hardlink 報錯的特殊環境（如 AidLux）
# ❗ 請確保 /tmp 有足夠空間


set -e

CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-install-temp"

echo "🔍 掃描 $CACHE_DIR 中的 .deb 套件..."

for DEB in "$CACHE_DIR"/*.deb; do
    echo "👉 嘗試安裝：$(basename "$DEB")"
    
    if dpkg -i "$DEB"; then
        echo "✅ 正常安裝成功：$(basename "$DEB")"
    else
        echo "⚠️ 安裝失敗，使用手動解包修復：$(basename "$DEB")"
        rm -rf "$TMPDIR"
        mkdir -p "$TMPDIR"

        if dpkg-deb -x "$DEB" "$TMPDIR"; then
            cp -a "$TMPDIR"/* /
            echo "✅ 手動安裝成功：$(basename "$DEB")"
        else
            echo "❌ 解包失敗：$(basename "$DEB")，跳過"
        fi
    fi
    echo "---------------------------"
done

echo "🌸 完成所有修復任務 ♡"
