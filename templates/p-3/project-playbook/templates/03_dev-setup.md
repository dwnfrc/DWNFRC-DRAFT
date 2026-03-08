# Dev Setup — ndays

## 1. 必要なツール・アカウント

### ツール

| ツール | バージョン | 用途 |
|--------|-----------|------|

### アカウント（デプロイ時に必要。ローカル開発は不要）

| サービス | 用途 |
|----------|------|

---

## 2. リポジトリ構成（モノレポ）

```
```

---

## 3. 環境構築手順（30分以内）

## 4. {DB} コマンド一覧


---

## 5. Terraform（IaC）

### ローカルでの使用

```bash
cd infra

# 初期化
terraform init

# 差分確認
terraform plan -var-file=environments/staging.tfvars

# 適用
terraform apply -var-file=environments/staging.tfvars
```

### CI/CD連携

GitHub Actionsの `infra.yml` で自動化:
- PRオープン時: `terraform plan` を実行しコメントに差分を表示
- `main` マージ時: `terraform apply` を自動実行

### tfstateの管理

```hcl
# main.tf
terraform {
  backend "gcs" {
    bucket = "ndays-tfstate"
    prefix = "terraform/state"
  }
}
```

---

## 6. OAuth開発用セットアップ

### Google OAuth

1. [Google Cloud Console](https://console.cloud.google.com/) → APIとサービス → 認証情報
2. OAuth 2.0 クライアントIDを作成
3. 承認済みリダイレクトURI: `http://localhost:3000/api/auth/callback/google`
4. クライアントID/シークレットを `.env` に設定

### GitHub OAuth

1. [GitHub Settings > Developer settings > OAuth Apps](https://github.com/settings/developers) → New OAuth App
2. Authorization callback URL: `http://localhost:3000/api/auth/callback/github`
3. クライアントID/シークレットを `.env` に設定

---

## 7. テスト実行

```bash
# 全テスト
pnpm test

# フロントエンドのみ
pnpm --filter web test

# バックエンドのみ
pnpm --filter api test

# E2E（Playwright）
pnpm --filter web test:e2e
```

---

## 8. 主要スクリプト

| コマンド | 説明 |
|----------|------|
| `pnpm dev` | フロント + バック同時起動 |
| `pnpm build` | 全パッケージビルド |
| `pnpm test` | 全テスト実行 |
| `pnpm lint` | ESLint実行 |
| `pnpm format` | Prettier実行 |
| `pnpm db:push` | スキーマ反映（開発用） |
| `pnpm db:generate` | マイグレーション生成 |
| `pnpm db:migrate` | マイグレーション適用 |
| `pnpm db:seed` | デモデータ投入 |
| `pnpm db:studio` | Drizzle Studio（DB GUI） |

---

## 9. ブランチ戦略

```
main ← develop ← feature/xxx
                ← fix/xxx
```

| ブランチ | 用途 |
|----------|------|
| `main` | 本番反映。直接pushしない。 |
| `develop` | 開発統合。feature/fixのマージ先。 |
| `feature/xxx` | 新機能開発。例: `feature/trace-execution` |
| `fix/xxx` | バグ修正。例: `fix/accuracy-calculation` |

### PRルール

- `develop` へのマージはPR必須
- CIが通ること（lint + test）
- セルフレビュー可（1人開発のため）
- コミットメッセージ: Conventional Commits（`feat:`, `fix:`, `docs:`, `chore:`）

---

## 10. Linter / Formatter

| ツール | 設定 |
|--------|------|

---

## 11. よくあるトラブルシューティング

| 問題 | 解決策 |
|------|--------|
