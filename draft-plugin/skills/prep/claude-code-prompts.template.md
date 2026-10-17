# {プロジェクト名} — Claude Code プロンプト集

Claude Code のチャットに **1つずつ** コピペして使う。
前のステップが完了・動作確認できてから次を投げること。
このファイルは派生物。docs/ のソース層から再生成でき、docs/ と食い違ったら docs/ が正。

**チャット分割の目安:**
- Step 1〜2 → Chat 1
- Step 3 → Chat 2
- Step 4 → Chat 3
- Step 5〜6 → Chat 4
- Step 7 → Chat 5
- Step 8〜9 → Chat 6

---

各Stepの見出し直下の `Status:` 行が進捗の記録先。値は次の3つで、無人ループの停止判定にも使われる:

- 空欄: 未着手
- `done YYYY-MM-DD`: 動作確認まで完了
- `blocked YYYY-MM-DD`: 着手したが、人の判断なしには閉じられない。直後の1行に閉じられない理由を具体的に書く

/draft:prep を再実行して作り直すときは、この行（とブロッカーの理由行）と追記されたステップを新版へ移送する。

## Step 1: モノレポ骨格

Status:

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
9. `.git` が無ければ `git init` を実行する
10. Makefile — docs/03_dev-setup.md の標準ターゲット（setup/dev/build/test/lint/format/db-*/doc-lint）を
   実コマンドへの薄い委譲として定義する。以後の操作は全てmake経由で行う。
   doc-lint は scripts/doc-lint.sh --docs を呼び、setup は git config core.hooksPath .githooks を含める
   （scripts/doc-lint.sh と .githooks/pre-commit はPhase 4で配置済み）

まだ画面やAPIの実装はしない。
make dev で両方のdev serverが起動し、
docker compose up -d + make db-push が通り、make doc-lint も通る状態をゴールとする。
```

---

## Step 2: DB スキーマ + シード

Status:

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

Status:

```
docs/02-01_system-design-doc.md の「API設計」に従って、バックエンドのAPIを実装してください。

やること:
1. {ORM}のDB接続モジュール
2. {各リソースのCRUDエンドポイント。API設計から列挙する}
3. 入力バリデーション（{バリデーションライブラリ}）
4. 認証ガードはモックで実装（ヘッダーからuser-idを読む簡易版。後で差し替える）

シードデータに対してcurlで各エンドポイントを叩いて動作確認できる状態をゴールとする。
```

---

## Step 4: 認証

Status:

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

Status:

```
docs/{設計仕様書} のデザインシステム章に従って、
再利用可能なレイアウトコンポーネントを実装してください。
{UIモックがある場合: 見た目は docs/mocks/ の {レイアウトパターンの代表画面}.png に合わせる。
 docs に書いてあることはそちらが優先し、docs に書いていない見た目はモックに合わせる}

やること:
1. docs/06_design-tokens.json のセマンティック層からCSS変数（またはテーマ設定）を
   生成し、以降のスタイリングはそれだけを参照する（値の直書き・プリミティブ直参照は禁止）
{レイアウトパターンを列挙する}

各コンポーネントが確認できる状態をゴールとする。
{UIモックがある場合: スクリーンショットをモックと見比べ、食い違いが無いこと}
```

---

## Step 6: コア画面

Status:

```
docs/{設計仕様書} の「コア画面詳細仕様」に従って、
最も重要な画面を実装してください。
{UIモックがある場合: 見た目は docs/mocks/ の {コア画面}.png に合わせる。
 docs に書いてあることはそちらが優先し、docs に書いていない見た目はモックに合わせる}

やること:
{コア画面の実装内容を列挙する}

バックエンドAPIと接続し、コアフローが一通り動く状態をゴールとする。
{UIモックがある場合: スクリーンショットをモックと見比べ、食い違いが無いこと}
```

---

## Step 7: 残り画面

Status:

```
残りの画面を実装してください。
{UIモックがある場合: 見た目は docs/mocks/ の {各画面。モックの無い画面は、属するレイアウトパターンの代表画面}.png に合わせる。
 docs に書いてあることはそちらが優先し、docs に書いていない見た目はモックに合わせる}

やること:
{残り画面の実装内容を列挙する}

全画面間の遷移が動く状態をゴールとする。
{UIモックがある場合: スクリーンショットをモックと見比べ、食い違いが無いこと}
```

---

## Step 8: インフラ + CI/CD

Status:

```
docs/04_deployment-procedure.md と docs/03_dev-setup.md に従って、
インフラとCI/CDを実装してください。

やること:
{Terraform, GitHub Actions, Dockerfileの内容を列挙する}

{terraform plan / ビルド確認} が通る状態をゴールとする。
```

---

## Step 9: テスト + 仕上げ

Status:

```
テストとコード品質の仕上げをしてください。

やること:
1. テストフレームワーク設定
2. バックエンドのユニットテスト（主要サービスのCRUD）
3. フロントエンドのユニットテスト（ユーティリティ関数、コアロジック）
4. E2Eテスト: コアフローのHappy Path 1本 + 異常系の最低ライン（不正入力のエラー形式・
   未認証アクセスの拒否・空状態の表示）。コアフローのE2Eは**受入スイート**を兼ねる。
   「同じことができる」の判定基準になるため、実装の内部でなく仕様の振る舞いで書く
5. Husky + lint-staged（コミット時にlint + format自動実行）
6. KPI計測: docs/01_prd.md の成功指標(KPI)を計測できる最小限の仕組みを導入する
   （アナリティクスまたは計測ログ。何を使うかは 02-01_system-design-doc.md の
   モニタリング・ログ方針に従う）
7. README.md

make test が全パス、make lint がエラー0の状態をゴールとする。
```
