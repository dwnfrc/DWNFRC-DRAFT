# Deployment Procedure — {サービス名}

## 1. 環境一覧

| 環境 | URL | サービス | DB | デプロイ方法 |
|------|-----|----------|-----|-------------|

## 2. CI/CD パイプライン // これ以降のセクションは例です（GCP + Terraform + GitHub Actions構成）。実際の構成に応じて必ず更新する。

```
[GitHub Push]
    │
    ├── PR → IaC plan (infra変更時)
    │
    ├── develop ブランチ → ステージング自動デプロイ
    │
    └── main ブランチ → 本番自動デプロイ
```

### CI/CD ワークフロー

**ci.yml** — 全ブランチ:
```
lint → unit test → build check
```

**deploy.yml** — main / develop:
```
test → コンテナビルド → レジストリ → デプロイ → DB migrate
```

**infra.yml** — infra/ 配下に変更がある場合:
```
PR時: IaC plan → PRにコメント
main merge時: IaC apply
```

## 3. 初回クラウドセットアップ（IaC）

### Step 1: 手動で最低限の準備

```bash
# プロジェクト作成
gcloud projects create {GCPプロジェクトID}
gcloud config set project {GCPプロジェクトID}

# 課金有効化（コンソールから）

# Terraform state用バケット作成
gsutil mb -l {リージョン} gs://{プロジェクト名}-tfstate

# 必要なAPI有効化
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### Step 2: Terraformで残りを構築

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集

terraform init
terraform plan -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars
```

Terraformが作成するリソース:
- Cloud Run サービス（web, api）
- Cloud SQL インスタンス + データベース
- Artifact Registry リポジトリ
- Secret Manager シークレット
- IAM サービスアカウント + ロールバインディング

### Step 3: GitHub Secretsの設定

| Secret名 | 内容 |
|----------|------|
| `GCP_PROJECT_ID` | GCPプロジェクトID |
| `GCP_SA_KEY` | サービスアカウントキー（JSON） |
| `GCP_REGION` | `{リージョン}` |

## 4. リリース前チェックリスト

- [ ] 全テスト通過（CI緑）
- [ ] マイグレーションが必要な場合、マイグレーションファイル生成済み
- [ ] 新しい環境変数がある場合、シークレット管理サービスに登録済み
- [ ] infra変更がある場合、IaC planの差分を確認済み
- [ ] ステージングで動作確認済み
- [ ] PRレビュー完了（セルフレビュー可）

## 5. ロールバック手順

### アプリケーションのロールバック

```bash
# 直前のリビジョンに戻す
gcloud run services update-traffic {APIサービス名} \
  --to-revisions=<previous-revision>=100

gcloud run services update-traffic {Webサービス名} \
  --to-revisions=<previous-revision>=100

# リビジョン一覧確認
gcloud run revisions list --service={APIサービス名}
```

### インフラのロールバック

```bash
# Gitで前のコミットに戻してapply
cd infra
git checkout HEAD~1 -- .
terraform apply -var-file=environments/production.tfvars
```

### DBマイグレーションのロールバック

ORMが自動ロールバックをサポートしない場合、手動でSQLを書いてリバートする。

## 6. デプロイ後確認

- [ ] アプリケーションログにエラーがないこと
- [ ] 主要APIエンドポイントが200を返すこと
- [ ] フロントエンドのトップページが表示されること
- [ ] 認証フローが機能すること
- [ ] 主要機能が正常に動作すること（ステージングで確認済みなら省略可）

## 7. 緊急時連絡先

| 役割 | 担当 | 連絡手段 |
|------|------|----------|
| 開発者（自分） | — | — |

※ 1人開発のため、エラー監視ツールのアラート通知を設定。
