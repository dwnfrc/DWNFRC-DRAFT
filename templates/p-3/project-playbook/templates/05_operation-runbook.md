# Operation Runbook — {サービス名}

## 1. モニタリング・ログ設計

### ログ構成

| ソース | 出力先 | 保持期間 | 内容 |
|--------|--------|----------|------|

### ログレベル

| レベル | 用途 | 本番で出力 |
|--------|------|-----------|
| ERROR | 例外、DBエラー、認証失敗 | ✅ |
| WARN | レート制限、非推奨API利用 | ✅ |
| INFO | リクエスト概要、デプロイイベント | ✅ |
| DEBUG | 詳細なリクエスト/レスポンス | ❌ |

## 2. 監視ポイントとアラート

| 監視対象 | メトリクス | 閾値 | アラート先 |
|----------|-----------|------|-----------|

## 3. よくある障害と対処法 // これ以降のセクションは例です。構成に応じて必ず更新する。

### Cloud Run がコールドスタートで遅い

**症状:** 初回アクセスが5〜10秒かかる

**対処:**
- min-instances=1 に設定（コスト増）
- または許容する（ポートフォリオ用途なら問題なし）
- Drizzleの軽量バンドルにより、Prismaよりコールドスタートは改善されている

```bash
# Terraformで変更する場合: cloud-run.tf の min_instance_count を変更
terraform apply -var-file=environments/production.tfvars

# CLIで直接変更する場合
gcloud run services update ndays-api-prod --min-instances=1
```

### Cloud SQL 接続エラー

**症状:** `ECONNREFUSED` や `Connection timed out`

**対処:**
1. Cloud SQL インスタンスが起動しているか確認
2. Cloud Run → Cloud SQL の接続設定を確認
3. Cloud SQL Auth Proxy が正しく設定されているか確認

```bash
gcloud sql instances describe ndays-db --format="value(state)"
```

### Drizzle マイグレーションエラー

**症状:** デプロイ後にDB関連エラー

**対処:**
1. マイグレーションファイルが正しく生成されているか確認
2. `packages/db/drizzle/` 内のSQLファイルを確認
3. 必要に応じて手動でSQLを実行

```bash
# Cloud Run Jobs でマイグレーション実行
gcloud run jobs execute ndays-db-migrate --region=asia-northeast1
```

### OAuth ログイン失敗

**症状:** リダイレクト後にエラー

**対処:**
1. Secret Manager の GOOGLE_CLIENT_ID / GITHUB_CLIENT_ID を確認
2. OAuthアプリのリダイレクトURLが本番URLと一致しているか確認
3. NextAuth の NEXTAUTH_URL が正しいか確認

## 4. ログ確認方法

```bash
# Cloud Run ログ（直近1時間）
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=ndays-api-prod" \
  --limit=50 \
  --freshness=1h

# エラーのみ
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit=20

# Cloud SQL スロークエリ
gcloud logging read \
  "resource.type=cloudsql_database AND textPayload:\"duration\"" \
  --limit=20

# GCPコンソールでも確認可
# https://console.cloud.google.com/logs
```

## 5. エスカレーションフロー

1人開発のため、Sentryアラート → メール通知 で自分が対応。

重大障害（データ損失等）の場合:
1. Cloud Run のトラフィックを前リビジョンにロールバック
2. Cloud SQL の自動バックアップからリストア

## 6. 定期メンテナンス

| タスク | 頻度 | 手順 |
|--------|------|------|
| 依存パッケージ更新 | 月1回 | `pnpm update` → テスト → デプロイ |
| Cloud SQL バックアップ確認 | 月1回 | GCPコンソールでバックアップ一覧確認 |
| Sentry イシュー棚卸し | 週1回 | 未解決エラーの確認・対処 |
| Cloud Run リビジョン整理 | 月1回 | 古いリビジョンを削除（コスト最適化） |
| OAuthトークン・証明書 | 更新通知時 | GCP/GitHub の通知に従い更新 |
| Terraform state確認 | 月1回 | drift検出: `terraform plan` で差分がないか確認 |
