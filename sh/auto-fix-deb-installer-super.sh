#!/bin/bash
#
# fix-deb-safe-installer.sh
#
# 自動修復 apt 安裝錯誤，特別針對因硬連結操作導致
# bzip2 (及相關依賴) 安裝失敗的情況。
#
# 使用方式：
#   1. sudo chmod +x fix-deb-safe-installer.sh
#   2. sudo ./fix-deb-safe-installer.sh
#
# 適用於各種精簡版 Debian/Ubuntu
# 無法正常 dpkg 安裝、bzip2 壞掉等場景。
#



# 提高腳本錯誤處理強度
set -euo pipefail

CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-install-temp"
LOG="$TMPDIR/error.log"
BACKUP_DIR="/var/backups/installer_backup_$(date +%Y%m%d%H%M%S)"

echo -e "\n✨ 進入安全升級修復模式 "

# 建立臨時目錄與備份目錄
mkdir -p "$TMPDIR"
mkdir -p "$BACKUP_DIR"

echo "📝 正在備份系統文件到 $BACKUP_DIR ..."
rsync -a --exclude="$TMPDIR" / "$BACKUP_DIR/" || { echo "❌ 備份失敗，請先確認系統狀態"; exit 1; }

#  確保 rsync 已經安裝
if ! command -v rsync &> /dev/null; then
  echo "🔧 未偵測到 rsync，正在安裝..."
  apt update && apt install -y rsync || { echo "❌ 安裝 rsync 失敗"; exit 1; }
else
  echo "✅ rsync 已安裝"
fi

#  防止 bzip2 被升級壞掉，將 bzip2 標記為 hold
echo "📌 將 bzip2 標記為 hold (防止升級) ..."
apt-mark hold bzip2 || echo "⚠️ 可能無法標記 bzip2 為 hold"

#  嘗試修復尚未配置完成的套件
echo -e "\n🔧 執行: dpkg --configure -a ..."
dpkg --configure -a || echo "⚠️ dpkg --configure -a 發生錯誤，但繼續..."

#  嘗試修復損壞的依賴
echo -e "\n🔧 執行: apt --fix-broken install ..."
apt --fix-broken install -y || echo "⚠️ apt --fix-broken install 有部分問題"

# 掃描並修復 $CACHE_DIR 中的 .deb 套件
echo -e "\n🔍 掃描 $CACHE_DIR 中的 .deb 套件...\n"

for DEB in "$CACHE_DIR"/*.deb; do
    echo "👉 嘗試安裝：$(basename "$DEB")"
    > "$LOG"
    
    if dpkg -i "$DEB" 2> "$LOG"; then
        echo "✅ 安裝成功：$(basename "$DEB")"
    elif grep -qE "hard link.*Operation not permitted" "$LOG"; then
        echo "⚠️ 偵測到 hardlink 錯誤，進行手動解包修復：$(basename "$DEB")"
        rm -rf "$TMPDIR/data"
        mkdir -p "$TMPDIR/data"
        
        if dpkg-deb -x "$DEB" "$TMPDIR/data"; then
            echo "📝 準備模擬同步檢查 (dry-run)："
            rsync -a --backup --dry-run "$TMPDIR/data"/ / || { echo "❌ rsync 模擬運行失敗，跳過 $(basename "$DEB")"; continue; }
            
            read -p "⚠️ 上述同步將覆蓋部分系統文件，確認是否進行實際同步? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rsync -a --backup "$TMPDIR/data"/ / || { echo "❌ rsync 實際運行失敗：$(basename "$DEB")"; continue; }
                echo "✅ 手動修復完成：$(basename "$DEB")"
            else
                echo "⏩ 跳過 $(basename "$DEB") 的修復"
            fi
        else
            echo "❌ 解包失敗：$(basename "$DEB")，跳過"
        fi
    else
        echo "❌ 其他錯誤無法自動修復：$(basename "$DEB")"
        echo "📝 錯誤摘要如下："
        cat "$LOG"
    fi
    echo "------------------------------"
done

#  再次嘗試修復配置與依賴
echo -e "\n🔧 再次執行: dpkg --configure -a ..."
dpkg --configure -a || echo "⚠️ dpkg --configure -a 仍有錯誤"

echo -e "\n🔧 再次執行: apt --fix-broken install ..."
apt --fix-broken install -y || echo "⚠️ apt --fix-broken install 仍有錯誤"

#  提示是否清理暫存目錄，保留備份以便出錯時回滾
read -p $'\n🌸 要清理修復暫存檔嗎？(y/n): ' clean
if [[ "$clean" =~ ^[Yy]$ ]]; then
  rm -rf "$TMPDIR"
  echo "🧹 已清除暫存目錄 $TMPDIR"
else
  echo "📦 暫存資料保留在 $TMPDIR"
fi

echo -e "\n🎉 所有修復任務完成啦 ！"

