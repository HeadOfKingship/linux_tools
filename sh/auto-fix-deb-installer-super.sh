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

echo -e "\n✨ 進入 ♡ 自動修復模式 ♡"

# 🧩 1. 確保 rsync 已安裝
if ! command -v rsync &> /dev/null; then
  echo "🔧 未偵測到 rsync，正在安裝..."
  apt update && apt install -y rsync
else
  echo "✅ rsync 已安裝"
fi

# 🧷 2. 防止 bzip2 被升級壞掉
echo "📌 bzip2 將被標記為 hold（防止升級）..."
apt-mark hold bzip2 || true

# 🧼 3. 嘗試修復損壞依賴
echo -e "\n🔧 執行 apt --fix-broken install..."
apt --fix-broken install -y || echo "⚠️ fix-broken 沒有完全成功"

# 📦 4. 掃描 .deb 套件
echo -e "\n🔍 掃描 $CACHE_DIR 中的 .deb 套件...\n"
mkdir -p "$TMPDIR"

for DEB in "$CACHE_DIR"/*.deb; do
    echo "👉 嘗試安裝：$(basename "$DEB")"
    > "$LOG"

    if dpkg -i "$DEB" 2> "$LOG"; then
        echo "✅ 安裝成功：$(basename "$DEB")"
    elif grep -qE "hard link.*Operation not permitted" "$LOG"; then
        echo "⚠️ 偵測 hardlink 錯誤，進行手動解包修復..."

        rm -rf "$TMPDIR/data"
        mkdir -p "$TMPDIR/data"

        if dpkg-deb -x "$DEB" "$TMPDIR/data"; then
            rsync -a "$TMPDIR/data"/ / || echo "❌ rsync 安裝失敗"
            echo "✅ 手動修復完成：$(basename "$DEB")"
        else
            echo "❌ 解包失敗：$(basename "$DEB")，跳過"
        fi
    else
        echo "❌ 其他錯誤無法修復：$(basename "$DEB")"
        echo "📝 錯誤摘要如下："
        cat "$LOG"
    fi
    echo "------------------------------"
done

# 🧼 ask要不要清除 tmp
read -p $'\n🌸 要清理修復暫存檔嗎？(y/n): ' clean
if [[ "$clean" =~ ^[Yy]$ ]]; then
  rm -rf "$TMPDIR"
  echo "🧹 已清理 $TMPDIR"
else
  echo "📦 暫存資料保留在 $TMPDIR"
fi

echo -e "\n🎉 所有任務完成啦~"

