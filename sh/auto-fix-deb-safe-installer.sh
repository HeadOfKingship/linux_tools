#!/bin/bash
#
# 💡 fix-deb-safe-installer.sh
# 🛠️ 自動修復 apt 套件損壞與安裝失敗情況（支援手動解包）
#
# 🌟 使用方式：
#   1. sudo chmod +x fix-deb-safe-installer.sh
#   2. sudo ./fix-deb-safe-installer.sh
#
# ✅ 先跑 apt --fix-broken install 修理套件關聯
# ✅ 嘗試安裝 .deb 套件，失敗則自動解包並手動複製
# ✅ 避開 hard link 問題，例如 bzcat 等錯誤
# 🌟適用於 各種精簡版Debian/ubuntu 等環境,
#







set -e

CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-install-temp"

echo "🔧 第一步：嘗試修復 broken 套件依賴..."
apt --fix-broken install -y || echo "⚠️ fix-broken 無法自動完成，進入手動修復流程"

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
            rsync -a "$TMPDIR"/ /  # 更安全的替代 cp -a
            echo "✅ 手動安裝成功：$(basename "$DEB")"
        else
            echo "❌ 解包失敗：$(basename "$DEB")，跳過"
        fi
    fi
    echo "---------------------------"
done

echo "✨ 再次嘗試 apt --fix-broken install 檢查依賴..."
apt --fix-broken install -y || echo "⚠️ 某些問題可能仍需要手動處理"

echo "🌸 完成所有修復任務 ♡"
