#!/bin/bash
#自動修復缺失,損壞的套件



echo -e "\n🌸 開始一鍵修復系統損壞套件 "

CACHE_DIR="/var/cache/apt/archives"
TMPDIR="/tmp/safe-fix-all"
LOG="$TMPDIR/error.log"

mkdir -p "$TMPDIR"

echo "🔧 Step 1: 配置殘留套件..."
dpkg --configure -a || echo "⚠️ configure 有殘留錯誤"

echo "🔧 Step 2: 修復 broken 套件..."
apt --fix-broken install -y || echo "⚠️ fix-broken 有問題"

echo "🔍 Step 3: 掃描並逐一嘗試修復 .deb 套件..."
for DEB in "$CACHE_DIR"/*.deb; do
  echo "👉 嘗試安裝 $(basename "$DEB")"
  > "$LOG"

  if dpkg -i "$DEB" 2> "$LOG"; then
    echo "✅ 成功安裝 $(basename "$DEB")"
  elif grep -qE "hard link.*Operation not permitted" "$LOG"; then
    echo "⚠️ 偵測到 hardlink 錯誤，手動修復：$(basename "$DEB")"
    rm -rf "$TMPDIR/data"
    mkdir -p "$TMPDIR/data"
    if dpkg-deb -x "$DEB" "$TMPDIR/data"; then
      rsync -a "$TMPDIR/data"/ / || echo "❌ rsync 同步失敗：$(basename "$DEB")"
      echo "✅ 手動修復完成：$(basename "$DEB")"
    else
      echo "❌ 解包失敗：$(basename "$DEB")"
    fi
  else
    echo "❌ 其他錯誤：$(basename "$DEB")"
    echo "📝 錯誤摘要如下："
    cat "$LOG"
  fi
  echo "-----------------------------"
done

echo "🔧 Step 4: 最後再修一次 dpkg/apt ..."
dpkg --configure -a
apt --fix-broken install -y

echo -e "\n🎉 一鍵修復完成～ 系統應該已經恢復健康啦～"

read -p "🌷 要清理暫存修復資料嗎？(y/n): " clean
if [[ "$clean" =~ ^[Yy]$ ]]; then
  rm -rf "$TMPDIR"
  echo "🧹 暫存資料已刪除"
else
  echo "📦 保留暫存資料在 $TMPDIR"
fi
