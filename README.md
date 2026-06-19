# 愛沢えみり 様 公式サイト デザインヒアリングシート

愛沢えみり様の個人公式サイト制作プロジェクトにおける、デザインフェーズ用のクライアント記入ヒアリングフォーム。
**Firebase Firestore で記入内容をクラウド保存**。GROW UP は同じURLに `?admin=...` を付けて閲覧。

**公開URL（クライアント記入用）:** https://growup-do.github.io/voyage-design-hearing/
**閲覧用（GROW UP）:** https://growup-do.github.io/voyage-design-hearing/?admin=growup2026voyage

## 特長

- 全12セクション・約60項目のデザインヒアリング
- **クラウド自動保存**（Firebase Firestore）：クライアント入力 → 即時に GROW UP 側で閲覧可能
- ローカルフォールバック（オフライン時は localStorage に退避）
- PDF保存対応（長文も見切れずに保存可能）
- スマートフォン対応

## セットアップ（初回のみ）

GROW UPメンバーが一度だけ実行：

```bash
# 1. Firebase にログイン（ブラウザが開きます。Googleアカウントでログイン）
firebase login

# 2. リポジトリで自動セットアップを実行
cd voyage-design-hearing
./configure.sh
```

`configure.sh` が以下を自動実行します：
- Firebase プロジェクト作成（`voyage-hearing-growup`）
- Firestore データベース作成（asia-northeast1）
- セキュリティルールのデプロイ
- Web アプリ作成 → SDK config 取得
- `index.html` の `FIREBASE_CONFIG` を自動上書き
- GitHub に push（→ GitHub Pages が約30秒で更新）

## ローカルでの確認

```bash
open index.html
```

## ファイル構成

| ファイル | 役割 |
|---|---|
| `index.html` | ヒアリングフォーム本体 |
| `firestore.rules` | Firestore セキュリティルール |
| `firebase.json` | Firebase 設定 |
| `.firebaserc` | プロジェクトID |
| `configure.sh` | 初回セットアップスクリプト |

## データ構造

Firestore: `hearings/voyage`

```json
{
  "data": {
    "b_oneline": "...",
    "b_called1": "...",
    "_radio_b_temp": "温かい",
    "_check_c_main": ["白＋黒のモノクロ系"],
    ...
  },
  "updatedAt": <Timestamp>
}
```

## 制作

GROW UP / 株式会社グロウアップ
