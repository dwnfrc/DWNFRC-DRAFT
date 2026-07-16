# Dev Setup — {サービス名}

## 1. 必要なツール・アカウント

### ツール

| ツール | バージョン | 用途 |
|--------|-----------|------|

### アカウント（デプロイ時に必要。ローカル開発は不要）

| サービス | 用途 |
|----------|------|

---

## 2. リポジトリ構成

```
```

---

## 3. 環境構築手順（30分以内）

## 4. {DB} コマンド一覧


---

## 5. IaC // 以下のセクション5〜8のコマンド例はGCP + Terraform + pnpm構成を前提にしています。実際の構成に応じて更新してください。

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
    bucket = "{プロジェクト名}-tfstate"
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

## 9. ブランチ戦略・リリースフロー

GitHub Flow + GitOps環境プロモーション方式。長命ブランチは `main` のみで、リリースはブランチではなく環境ごとのバージョン宣言ファイルで管理する。

```
feature/xxx ──squash──▶ main ──CI自動──▶ staging
fix/xxx    ──squash──▶   │
                         └─ promotion PR ──▶ production
```

| ブランチ | 用途 |
|----------|------|
| `main` | 唯一の長命ブランチ。直接pushしない。マージ = stagingへの自動リリース |
| `feature/xxx` | 新機能開発。例: `feature/add-search` |
| `fix/xxx` | バグ修正。例: `fix/login-error` |

### マージ方式

- コードPR（feature/fix → main）は**常にsquashマージ**。1 PR = 1コミット = 1つの意図となり、mainの履歴がPR単位で読める
- 環境ブランチ（develop等）は使わない。環境間の差分がマージ履歴に埋もれ、cherry-pickが増えるため（environment branchesアンチパターン）

### リリースフロー（環境プロモーション）

環境ごとのバージョン宣言ファイル `deploy/{環境}/version` が「その環境で動くべきバージョン」の唯一の真実。

1. mainへのsquashマージ → CIがアーティファクトをビルド（バージョン/コミットSHAタグ）し、`deploy/staging/version` を自動更新 → stagingへ自動デプロイ
2. stagingで検証後、`deploy/production/version` を検証済みバージョンに更新する **promotion PR** を作成・マージ → 本番へデプロイ
3. ロールバック = promotion PR をrevert

バージョン体系はSemVer + gitタグ（CIが付与）。パイプラインの詳細は `docs/04_deployment-procedure.md` を参照。

### PRルール

- `main` へのマージはPR必須（squash）
- CIが通ること（lint + test）
- セルフレビュー可（1人開発のため）
- コミットメッセージ: Conventional Commits（`feat:`, `fix:`, `docs:`, `chore:`）
- PRは `.github/PULL_REQUEST_TEMPLATE.md` に従って書く。promotion PRには対象バージョン・stagingでの検証結果・ロールバック手順を記載する

---

## 10. Linter / Formatter

| ツール | 設定 |
|--------|------|

---

## 11. よくあるトラブルシューティング

| 問題 | 解決策 |
|------|--------|
