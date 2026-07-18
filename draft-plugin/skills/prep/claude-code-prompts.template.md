# {プロジェクト名} — Claude Code プロンプト集

Claude Code のチャットに **1つずつ** コピペして使う。
前のステップが完了・動作確認できてから次を投げること。
このファイルは派生物。docs/ のソース層から再生成でき、docs/ と食い違ったら docs/ が正。

**チャット分割の目安:**
- Step 1〜2 → Chat 1
- Step 3 → Chat 2
- Step 4 → Chat 3
- Step 5〜6 → Chat 4
- Step 7〜8 → Chat 5
- Step 9 → Chat 6

---

## Step 1: モノレポ骨格

```
docs/03_dev-setup.md のリポジトリ構成に従って、モノレポの骨格をセットアップしてください。

やること:
1. {パッケージマネージャー}のワークスペース設定 + ルート package.json
2. apps/web: {フロントエンドフレームワーク} 初期化 + {UIライブラリ}
3. apps/api: {バックエンドフレームワーク} 初期化
4. packages/db: {ORM} + 設定ファイル（スキーマはまだ空でOK）
5. packages/shared: package.json のみ
6. docker-compose.yml ({DB} コンテナ)
7. .env.example
8. .gitignore
9. Makefile — docs/03_dev-setup.md の標準ターゲット（setup/dev/build/test/lint/format/db-*）を
   実コマンドへの薄い委譲として定義する。以後の操作は全てmake経由で行う

まだ画面やAPIの実装はしない。
make dev で両方のdev serverが起動し、
docker compose up -d + make db-push が通る状態をゴールとする。
```

---

## Step 2: DB スキーマ + シード

```
docs/02-01_system-design-doc.md の「データモデル」セクションにあるスキーマを実装してください。

やること:
1. packages/db/src/schema.{ts|prisma} に全テーブル定義
2. packages/db の設定ファイル
3. packages/db/src/seed.ts にデモデータ（docs/{設計仕様書}のデモデータ仕様に基づく）
4. make db-push + make db-seed が通ることを確認

make db-push でテーブル作成、make db-seed でデータ投入、
make db-studio でデータが確認できる状態をゴールとする。
```

---

## Step 3: バックエンド API（CRUD）

```
docs/02-01_system-design-doc.md の「API設計」に従って、バックエンドのAPIを実装してください。

やること:
1. {ORM}のDB接続モジュール
2. {各リソースのCRUDエンドポイント — API設計から列挙する}
3. 入力バリデーション（{バリデーションライブラリ}）
4. 認証ガードはモックで実装（ヘッダーからuser-idを読む簡易版。後で差し替える）

シードデータに対してcurlで各エンドポイントを叩いて動作確認できる状態をゴールとする。
```

---

## Step 4: 認証

```
{認証ライブラリ}で認証を実装してください。

やること:
1. 認証設定ファイル
2. {OAuthプロバイダー} の設定
3. ログインページ
4. バックエンド側の認証ガード実装（Step 3のモックを差し替え）
5. middleware でprotected routesを設定
6. ヘッダーにユーザー情報表示

.envにOAuthキーを入れればログインが動く状態をゴールとする。
OAuthキー未設定でもアプリがクラッシュしないこと。
```

---

## Step 5: 共通UIコンポーネント

```
docs/{設計仕様書} のレイアウト設計システムに従って、
再利用可能なレイアウトコンポーネントを実装してください。

やること:
{レイアウトパターンを列挙する}

各コンポーネントが確認できる状態をゴールとする。
```

---

## Step 6: コア画面

```
docs/{設計仕様書} の「コア画面詳細仕様」に従って、
最も重要な画面を実装してください。

やること:
{コア画面の実装内容を列挙する}

バックエンドAPIと接続し、コアフローが一通り動く状態をゴールとする。
```

---

## Step 7: 残り画面

```
残りの画面を実装してください。

やること:
{残り画面の実装内容を列挙する}

全画面間の遷移が動く状態をゴールとする。
```

---

## Step 8: インフラ + CI/CD

```
docs/04_deployment-procedure.md と docs/03_dev-setup.md に従って、
インフラとCI/CDを実装してください。

やること:
{Terraform, GitHub Actions, Dockerfileの内容を列挙する}

{terraform plan / ビルド確認} が通る状態をゴールとする。
```

---

## Step 9: テスト + 仕上げ

```
テストとコード品質の仕上げをしてください。

やること:
1. テストフレームワーク設定
2. バックエンドのユニットテスト（主要サービスのCRUD）
3. フロントエンドのユニットテスト（ユーティリティ関数、コアロジック）
4. E2Eテスト1本（コアフローのHappy Path）
5. Husky + lint-staged（コミット時にlint + format自動実行）
6. README.md

make test が全パス、make lint がエラー0の状態をゴールとする。
```
