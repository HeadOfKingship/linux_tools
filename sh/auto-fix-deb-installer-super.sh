#!/bin/bash
#
# 🛠️ 自動修復 apt 套件損壞與安裝失敗情況（支援手動解包）
#
# 🌟 使用方式：
#   1. sudo chmod +x fix-deb-safe-installer.sh
#   2. sudo ./fix-deb-safe-installer.sh
#
# 🌟適用於 各種精簡版Debian/ubuntu 無法 dpkg 安裝、bzip2 壞掉等場景,
# ✅ 套件來源：/var/cache/apt/archives/*.deb
# ✅可選擇自動修復所有，支援 apt --fix-broken


set -e

CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-install-temp"
LOG="$TMPDIR/error.log"

# 🛠️ 初始化
mkdir -p "$TMPDIR"
echo -e "\n✨ 進入自動修復模式 ♡"

# ✨ 試試 apt 自動修復
echo -e "\n🔧 正在執行 apt --fix-broken install..."
apt --fix-broken install -y || echo "⚠️ fix-broken 無法修復全部錯誤"

# 🔍 開始掃描 .deb 套件
echo -e "\n🔍 掃描 $CACHE_DIR 中的 .deb 套件...\n"

for DEB in "$CACHE_DIR"/*.deb; do
    echo "👉 嘗試安裝：$(basename "$DEB")"

    # 清空錯誤日誌
    > "$LOG"

    # 嘗試安裝並記錄錯誤
    if dpkg -i "$DEB" 2> "$LOG"; then
        echo "✅ 成功安裝：$(basename "$DEB")"
    elif grep -qE "hard link.*Operation not permitted" "$LOG"; then
        echo "⚠️ 偵測 hardlink 錯誤，執行手動解包修復..."

        rm -rf "$TMPDIR/data"
        mkdir -p "$TMPDIR/data"

        if dpkg-deb -x "$DEB" "$TMPDIR/data"; then
            rsync -a "$TMPDIR/data"/ / || echo "❌ rsync 遇到錯誤"
            echo "✅ 手動解包修復完成：$(basename "$DEB")"
        else
            echo "❌ 解包失敗：$(basename "$DEB")，跳過"
        fi
    else
        echo "❌ 無法自動修復：$(basename "$DEB")"
        echo "💡 錯誤摘要如下："
        cat "$LOG"
    fi
    echo "-------------------------------"
done

echo -e "\n🌸 所有自動修復流程已完成 ♡"
