#!/usr/bin/env bash
# Firebase 自動セットアップスクリプト
# 事前に `firebase login` を一度だけ実行してください
#
# 使い方:
#   ./configure.sh

set -e
cd "$(dirname "$0")"

PROJECT_ID="voyage-hearing-growup"
LOCATION="asia-northeast1"
APP_DISPLAY="VOYAGE Hearing Web"

echo "================================================"
echo "  VOYAGE デザインヒアリング — Firebase セットアップ"
echo "================================================"
echo ""

# ----- 1. login確認 -----
if ! firebase projects:list >/dev/null 2>&1; then
  echo "❌ firebase にログインしていません。先に以下を実行してください："
  echo "   firebase login"
  exit 1
fi
echo "✅ firebase login OK"

# ----- 2. プロジェクトを確保（存在＋作成＋既存許容） -----
echo ""
echo "📦 Firebase プロジェクトを確保中: $PROJECT_ID"
if firebase projects:get "$PROJECT_ID" >/dev/null 2>&1; then
  echo "   ✅ 既に存在します"
else
  CREATE_OUTPUT=$(firebase projects:create "$PROJECT_ID" --display-name "VOYAGE Design Hearing" 2>&1 || true)
  if echo "$CREATE_OUTPUT" | grep -qi "ready\|created"; then
    echo "   ✅ 作成しました"
  elif echo "$CREATE_OUTPUT" | grep -qi "already"; then
    echo "   ✅ 既に他のセッションで作成済み"
  else
    echo "$CREATE_OUTPUT"
    echo ""
    echo "❌ プロジェクト作成に失敗。ブラウザで手動作成してください:"
    echo "    https://console.firebase.google.com/  → プロジェクトID: $PROJECT_ID"
    exit 1
  fi
fi

# ----- 3. Firestore データベース作成（既存許容） -----
echo ""
echo "🗄  Firestore データベースを作成中…"
DB_OUTPUT=$(firebase firestore:databases:create '(default)' \
  --project "$PROJECT_ID" --location "$LOCATION" 2>&1 || true)
if echo "$DB_OUTPUT" | grep -qi "successfully\|created"; then
  echo "   ✅ 作成しました"
elif echo "$DB_OUTPUT" | grep -qi "already exists"; then
  echo "   ✅ 既存を利用"
else
  echo "$DB_OUTPUT" | tail -5
  echo "   （既存の可能性が高いので続行）"
fi

# APIの伝播待ち
sleep 5

# ----- 4. ルールデプロイ（403対策で最大3回リトライ） -----
echo ""
echo "🔒 Firestore ルールをデプロイ中…"
for i in 1 2 3; do
  RULES_OUT=$(firebase deploy --project "$PROJECT_ID" --only firestore:rules 2>&1)
  if echo "$RULES_OUT" | grep -q "Deploy complete"; then
    echo "   ✅ デプロイ完了"
    break
  fi
  echo "   ⏳ リトライ $i/3（API有効化待ち）…"
  sleep 8
  if [ "$i" = "3" ]; then
    echo "$RULES_OUT" | tail -10
    echo "❌ ルールデプロイに失敗しました"
    exit 1
  fi
done

# ----- 5. Web App を確保 -----
echo ""
echo "🌐 Web App を確保中…"
APPS_LIST=$(firebase apps:list web --project "$PROJECT_ID" 2>/dev/null || true)
APP_ID=$(echo "$APPS_LIST" | grep -oE '1:[0-9]+:web:[a-f0-9]+' | head -1)

if [ -z "$APP_ID" ]; then
  echo "   Web App を新規作成…"
  CREATE_APP=$(firebase apps:create web "$APP_DISPLAY" --project "$PROJECT_ID" 2>&1)
  APP_ID=$(echo "$CREATE_APP" | grep -oE '1:[0-9]+:web:[a-f0-9]+' | head -1)
fi

if [ -z "$APP_ID" ]; then
  echo "❌ Web App ID を取得できませんでした"
  exit 1
fi
echo "   ✅ App ID: $APP_ID"

# ----- 6. SDK config を取得 -----
echo ""
echo "📋 SDK config を取得中…"
SDK_OUT=$(firebase apps:sdkconfig WEB "$APP_ID" --project "$PROJECT_ID" 2>&1)
# 末尾のJSONブロックを抜き出す（{ から } まで）
CONFIG_JSON=$(echo "$SDK_OUT" | python3 -c '
import sys, json, re
text = sys.stdin.read()
# {で始まって}で終わる最大の塊を取り出す
m = re.search(r"\{[\s\S]*\}", text)
if not m:
    print("ERR_NO_JSON", file=sys.stderr); sys.exit(1)
raw = m.group(0)
cfg = json.loads(raw)
# projectNumber/version は不要なので除去
for k in ["projectNumber","version"]:
    cfg.pop(k, None)
# キー順を安定化
order = ["apiKey","authDomain","projectId","storageBucket","messagingSenderId","appId"]
sorted_cfg = {k: cfg[k] for k in order if k in cfg}
print(json.dumps(sorted_cfg, ensure_ascii=False, indent=2))
')

if [ -z "$CONFIG_JSON" ]; then
  echo "❌ SDK config のパースに失敗"
  echo "$SDK_OUT" | tail -20
  exit 1
fi

echo ""
echo "$CONFIG_JSON"
echo ""

# ----- 7. index.html に config を埋め込む -----
echo "✏️  index.html を更新中…"
python3 <<PY
import re, pathlib
p = pathlib.Path("index.html")
html = p.read_text(encoding="utf-8")
cfg = '''$CONFIG_JSON'''
new_line = f"window.FIREBASE_CONFIG = {cfg};"
html_new, n = re.subn(
    r"window\.FIREBASE_CONFIG\s*=\s*[^;]+;",
    new_line,
    html,
    count=1
)
if n == 0:
    print("❌ FIREBASE_CONFIG 行が見つからず更新できませんでした")
    raise SystemExit(1)
p.write_text(html_new, encoding="utf-8")
print("   ✅ index.html を更新しました")
PY

# ----- 8. git push -----
echo ""
echo "📤 GitHub に push 中…"
git add index.html
if git diff --cached --quiet; then
  echo "   （差分なし）"
else
  git commit -m "Firebase config 埋め込み (configure.sh)"
  git push
fi

echo ""
echo "================================================"
echo "  ✅ セットアップ完了！"
echo "================================================"
echo ""
echo "クライアント用URL:"
echo "   https://growup-do.github.io/voyage-design-hearing/"
echo ""
echo "GROW UP 閲覧用URL（記入内容を確認）:"
echo "   https://growup-do.github.io/voyage-design-hearing/?admin=growup2026voyage"
echo ""
echo "GitHub Pages への反映まで30秒〜1分お待ちください。"
