#!/usr/bin/env bash
# Firebase 自動セットアップスクリプト
# 事前に `firebase login` を一度だけ実行してください
#
# 使い方:
#   ./configure.sh

set -e
cd "$(dirname "$0")"

PROJECT_ID="voyage-hearing-growup"

echo "================================================"
echo "  VOYAGE デザインヒアリング — Firebase セットアップ"
echo "================================================"
echo ""

# 1. login確認
if ! firebase projects:list >/dev/null 2>&1; then
  echo "❌ firebase にログインしていません。先に以下を実行してください："
  echo "   firebase login"
  exit 1
fi
echo "✅ firebase login OK"

# 2. プロジェクト作成（存在しなければ）
if firebase projects:list 2>/dev/null | grep -q "$PROJECT_ID"; then
  echo "✅ プロジェクト '$PROJECT_ID' は既に存在します"
else
  echo "📦 Firebase プロジェクトを作成中: $PROJECT_ID"
  firebase projects:create "$PROJECT_ID" --display-name "VOYAGE Design Hearing" || {
    echo "⚠️  プロジェクト作成に失敗。手動でブラウザから作成してください:"
    echo "    https://console.firebase.google.com/"
    echo "    プロジェクトID を '$PROJECT_ID' に設定"
    exit 1
  }
fi

# 3. Firestore データベース作成
echo "🗄  Firestore データベースを作成中…"
firebase firestore:databases:create '(default)' \
  --project "$PROJECT_ID" \
  --location asia-northeast1 \
  --type firestore-native 2>/dev/null \
  || echo "    （既に作成済み）"

# 4. ルールデプロイ
echo "🔒 Firestore ルールをデプロイ中…"
firebase deploy --project "$PROJECT_ID" --only firestore:rules

# 5. Web App を作成（存在しなければ）して config を取得
echo "🌐 Web App を作成して config を取得中…"
APP_DISPLAY="VOYAGE Hearing Web"

# 既存アプリ確認
APPS=$(firebase apps:list web --project "$PROJECT_ID" 2>/dev/null || true)
APP_ID=$(echo "$APPS" | grep -i "$APP_DISPLAY" | awk -F '│' '{print $3}' | head -1 | xargs)

if [ -z "$APP_ID" ]; then
  echo "    Web App を新規作成…"
  firebase apps:create web "$APP_DISPLAY" --project "$PROJECT_ID"
  APPS=$(firebase apps:list web --project "$PROJECT_ID" 2>/dev/null)
  APP_ID=$(echo "$APPS" | grep -i "$APP_DISPLAY" | awk -F '│' '{print $3}' | head -1 | xargs)
fi

if [ -z "$APP_ID" ]; then
  echo "❌ Web App ID を取得できませんでした"
  exit 1
fi

echo "    App ID: $APP_ID"

# 6. SDK config を取得
SDK_CONFIG=$(firebase apps:sdkconfig WEB "$APP_ID" --project "$PROJECT_ID" --json 2>/dev/null)
if [ -z "$SDK_CONFIG" ]; then
  echo "❌ SDK config を取得できませんでした"
  exit 1
fi

# JSON から config 部分を抽出
CONFIG_JSON=$(echo "$SDK_CONFIG" | python3 -c '
import json,sys
data = json.load(sys.stdin)
cfg = data.get("result", {}).get("sdkConfig", data)
print(json.dumps(cfg, ensure_ascii=False, indent=2))
')

echo ""
echo "📋 取得した Firebase config:"
echo "$CONFIG_JSON"
echo ""

# 7. index.html に config を埋め込む
echo "✏️  index.html を更新中…"
python3 <<PY
import re
with open("index.html","r",encoding="utf-8") as f:
    html = f.read()
cfg = '''$CONFIG_JSON'''
new_line = f'window.FIREBASE_CONFIG = {cfg};'
html = re.sub(
    r'window\.FIREBASE_CONFIG\s*=\s*[^;]+;',
    new_line,
    html,
    count=1
)
with open("index.html","w",encoding="utf-8") as f:
    f.write(html)
print("    index.html updated.")
PY

# 8. git push
echo ""
echo "📤 GitHub に push 中…"
git add -A
git commit -m "Firebase config 埋め込み (自動)" || echo "    (差分なし)"
git push

echo ""
echo "================================================"
echo "  ✅ セットアップ完了！"
echo "================================================"
echo ""
echo "クライアント用URL:"
echo "   https://growup-do.github.io/voyage-design-hearing/"
echo ""
echo "GROW UP 閲覧用URL（記入内容を見るだけ・編集不可）:"
echo "   https://growup-do.github.io/voyage-design-hearing/?admin=growup2026voyage"
echo ""
echo "GitHub Pages の反映まで30秒〜1分かかります。"
