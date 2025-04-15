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


CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-install-temp"
LOG="$TMPDIR/error.log"

echo -e "\n✨ 進入自動修復模式 ♡"

# 1. 確保 rsync 已經安裝
if ! command -v rsync &> /dev/null; then
  echo "🔧 未偵測到 rsync，正在安裝..."
  apt update && apt install -y rsync || { echo "❌ 安裝 rsync 失敗"; exit 1; }
else
  echo "✅ rsync 已安裝"
fi

# 2. 防止 bzip2 被升級壞掉，將 bzip2 標記為 hold
echo "📌 將 bzip2 標記為 hold (防止升級) ..."
apt-mark hold bzip2 || echo "⚠️ 可能無法標記 bzip2 為 hold"

# 3. 嘗試修復尚未配置完成的套件
echo -e "\n🔧 執行: dpkg --configure -a ..."
dpkg --configure -a || echo "⚠️ dpkg --configure -a 有錯，但繼續..."

# 4. 嘗試修復損壞的依賴
echo -e "\n🔧 執行: apt --fix-broken install ..."
apt --fix-broken install -y || echo "⚠️ apt --fix-broken install 有部分問題"

# 5. 掃描並修復 /var/cache/apt/archives 中的 .deb 套件
echo -e "\n🔍 掃描 $CACHE_DIR 中的 .deb 套件...\n"
mkdir -p "$TMPDIR"

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
            # 使用 rsync 複製文件，避免直接 cp -a 帶來的覆蓋問題
            rsync -a "$TMPDIR/data"/ / || echo "❌ rsync 安裝失敗：$(basename "$DEB")"
            echo "✅ 手動修復完成：$(basename "$DEB")"
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

# 6. 再次嘗試修復配置與依賴
echo -e "\n🔧 再次執行: dpkg --configure -a ..."
dpkg --configure -a || echo "⚠️ dpkg --configure -a 仍有錯誤"

echo -e "\n🔧 再次執行: apt --fix-broken install ..."
apt --fix-broken install -y || echo "⚠️ apt --fix-broken install 仍有錯誤"

# 7. 提示是否清理暫存目錄
read -p $'\n🌸 要清理修復暫存檔嗎？(y/n): ' clean
if [[ "$clean" =~ ^[Yy]$ ]]; then
  rm -rf "$TMPDIR"
  echo "🧹 已清除 $TMPDIR"
else
  echo "📦 暫存資料保留在 $TMPDIR"
fi

echo -e "\n🎉 所有修復任務完成啦♡ 謝謝使用修復工具！"
