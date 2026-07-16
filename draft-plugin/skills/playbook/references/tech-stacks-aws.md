# AWS ベースのコア技術スタック選択肢

## 概要
toC向けWebサービス、toB向けSaaS、社内システム・管理画面を想定した、AWSベースの標準技術スタック選択肢。
認証機能とデータ永続化を基本とし、5〜10人規模の開発チームで運用可能な構成。

---

## インフラ・実行環境

### コンテナ実行環境
| 選択肢 | 特徴 | 適している場合 | コスト感 |
|--------|------|---------------|---------|
| **ECS Fargate** | サーバーレス、インフラ管理不要 | 小〜中規模、運用コスト削減優先 | 中〜高 |
| **ECS EC2** | EC2インスタンス上でコンテナ実行 | コスト最適化重視、大規模 | 低〜中 |
| **EKS** | マネージドKubernetes | Kubernetes経験あり、マルチクラウド想定 | 高 |
| **App Runner** | 最もシンプル、GitHubから自動デプロイ | プロトタイプ、小規模 | 低〜中 |

**推奨**: ECS Fargate（小〜中規模）、ECS EC2（大規模・コスト重視）

### ロードバランサー
| 選択肢 | 用途 |
|--------|------|
| **ALB** | HTTP/HTTPS、標準的なWebアプリ |
| **NLB** | TCP/UDP、低レイテンシ要求がある場合 |

**推奨**: ALB

### CDN
- **CloudFront**: AWS標準、S3との統合良好

### IaC (Infrastructure as Code)
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Terraform** | マルチクラウド対応、デファクト | 将来的に他クラウドも検討 |
| **CloudFormation** | AWS専用、AWSサービスとの統合◎ | AWS一本で行く |
| **CDK** | TypeScript/Python等でインフラをコード化 | 開発者がインフラも書く |
| **Pulumi** | プログラミング言語でインフラ記述 | TypeScript等で統一したい |

**推奨**: Terraform（汎用性）、CDK（開発者フレンドリー）

### VPC設計
- パブリックサブネット: ALB、NAT Gateway
- プライベートサブネット: ECS、RDS、ElastiCache
- マルチAZ構成

---

## データ層

### RDB
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **RDS PostgreSQL** | 標準的、拡張性高い | 一般的なWebアプリ | 中 |
| **RDS MySQL** | 標準的、実績豊富 | MySQL経験者が多い | 中 |
| **Aurora PostgreSQL** | 高可用性、自動スケーリング | 高トラフィック、ミッションクリティカル | 高 |
| **Aurora MySQL** | 高可用性、自動スケーリング | 高トラフィック、MySQL互換が必要 | 高 |

**推奨**: RDS PostgreSQL（標準）、Aurora PostgreSQL（高可用性重視）

### キャッシュ
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **ElastiCache Redis** | リッチな機能、Pub/Sub、永続化可能 | セッション管理、ジョブキュー |
| **ElastiCache Memcached** | シンプル、マルチスレッド | 単純なキャッシュのみ |

**推奨**: ElastiCache Redis

### オブジェクトストレージ
- **S3**: ファイル・画像・動画などの保存
- **S3 Glacier**: 長期アーカイブ

### データベースマイグレーション
言語・フレームワークの標準ツールを使用:
- Node.js: Prisma Migrate / TypeORM Migrations
- Python: Alembic / Django Migrations
- Go: golang-migrate / GORM AutoMigrate

### バックアップ
- **RDS自動バックアップ**: ポイントインタイムリカバリ
- **AWS Backup**: 一元管理、S3/EBS等も対応

---

## アプリケーション基盤

### プログラミング言語・Webフレームワーク
| 言語 | フレームワーク | 特徴 | 適している場合 |
|------|--------------|------|---------------|
| **Node.js** | Express | シンプル、軽量 | 小〜中規模、API中心 |
| **Node.js** | NestJS | TypeScript、エンタープライズ向け | 大規模、保守性重視 |
| **Python** | FastAPI | 高速、型ヒント、自動ドキュメント生成 | API開発、ML連携 |
| **Python** | Django | フルスタック、管理画面標準 | 管理画面重視、短納期 |
| **Go** | Echo | 高速、軽量 | パフォーマンス重視 |
| **Go** | Gin | 高速、人気 | パフォーマンス重視 |

**推奨**: Node.js + NestJS（TypeScript統一、保守性）、Python + FastAPI（API中心）

### ORM/クエリビルダー
| 言語 | 選択肢 | 特徴 |
|------|--------|------|
| Node.js | Prisma | 型安全、開発体験◎、マイグレーション管理 |
| Node.js | TypeORM | デコレータベース、機能豊富 |
| Python | SQLAlchemy | デファクト、柔軟 |
| Go | GORM | 人気、機能豊富 |

**推奨**: Prisma（Node.js）、SQLAlchemy（Python）、GORM（Go）

### バリデーション
| 言語 | 選択肢 |
|------|--------|
| Node.js | Zod（型推論◎）、Joi |
| Python | Pydantic（FastAPIと相性◎） |
| Go | go-validator |

### ジョブキュー（非同期処理）
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **SQS + Lambda** | サーバーレス、小タスク向け | 15分以内の処理 |
| **SQS + ECS Worker** | 長時間処理可能 | 15分超の処理、動画変換等 |
| **Bull (Redis)** | リッチな機能、リトライ、優先度 | 複雑なジョブ管理が必要 |

**推奨**: SQS + Lambda（基本）、SQS + ECS Worker（長時間処理）

### スケジューラー（定期実行タスク）
- **EventBridge Scheduler**: cron式、Lambda/ECS起動
- **Lambda + EventBridge**: サーバーレス

**推奨**: EventBridge Scheduler + Lambda

---

## 認証・認可

### 認証サービス
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **Cognito** | AWS統合、安価 | AWS中心、基本的な認証のみ | 低 |
| **Auth0** | 機能豊富、UI良い、SSO対応 | エンタープライズ、複雑な要件 | 中〜高 |
| **自前実装 (JWT)** | 柔軟、カスタマイズ可能 | 特殊な要件、学習目的 | 開発コスト |

**推奨**: Cognito（AWS標準、コスト重視）、Auth0（機能・UX重視）

### セッション管理
- **ElastiCache Redis**: セッション保存
- **Cognito**: Cognitoを使う場合はトークンベース

### 権限管理
- **IAM**: AWSリソースへのアクセス制御
- **アプリケーションレベル**: RBAC（Role-Based Access Control）実装
  - ライブラリ例: casbin、自前実装

---

## 外部連携

### メール送信
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **SES** | AWS標準、安価 | トランザクションメール中心 | 低 |
| **SendGrid** | 配信管理機能豊富、UI良い | マーケティングメールも | 中 |
| **Postmark** | トランザクションメール特化 | 到達率重視 | 中 |

**推奨**: SES（コスト重視）、SendGrid（機能重視）

### メディア処理
#### 画像処理
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Lambda + Sharp** | 自前実装、柔軟 | カスタマイズ必要、コスト抑えたい |
| **Lambda + Pillow** | Python、自前実装 | Python環境 |
| **Cloudinary** | SaaS、機能豊富、管理画面あり | 開発速度優先、運用楽 |
| **Imgix** | SaaS、URL変換で画像加工 | リアルタイム変換 |

**推奨**: Lambda + Sharp（コスト重視、柔軟性）

#### 動画処理
- **MediaConvert**: AWS標準、動画変換・エンコーディング

---

## 監視・ログ・エラー追跡

### ログ収集
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **CloudWatch Logs** | AWS標準、統合良好 | AWS中心 |
| **Datadog** | 統合監視、UI優秀 | 本格的な監視 |
| **ELK (Elasticsearch)** | オープンソース、柔軟 | 自前で構築・運用できる |

**推奨**: CloudWatch Logs（基本）、Datadog（本格監視）

### エラートラッキング
| 選択肢 | 特徴 |
|--------|------|
| **Sentry** | デファクト、エラー詳細、ソースマップ対応 |
| **Rollbar** | シンプル、使いやすい |
| **CloudWatch Insights** | AWS内で完結 |

**推奨**: Sentry

### APM (Application Performance Monitoring)
| 選択肢 | 特徴 |
|--------|------|
| **X-Ray** | AWS標準、分散トレーシング |
| **Datadog APM** | 統合監視、リッチなダッシュボード |
| **New Relic** | 老舗、機能豊富 |

**推奨**: X-Ray（AWS標準）、Datadog（統合監視重視）

### インフラ監視
- **CloudWatch**: メトリクス、アラーム
- **Datadog**: より詳細な監視、美しいダッシュボード

### アラート通知
- **SNS + Lambda**: Slack/メール通知
- **CloudWatch Alarms**: メトリクス監視

---

## セキュリティ

### シークレット管理
| 選択肢 | 特徴 | コスト |
|--------|------|--------|
| **Secrets Manager** | 自動ローテーション、詳細な監査 | やや高 |
| **Parameter Store (SSM)** | シンプル、安価 | 低 |

**推奨**: Secrets Manager（本番環境）、Parameter Store（開発環境）

### SSL/TLS証明書
- **ACM (AWS Certificate Manager)**: 無料、自動更新

### WAF
| 選択肢 | 特徴 |
|--------|------|
| **AWS WAF** | AWS統合、カスタムルール |
| **Cloudflare** | DDoS対策強力、CDN兼用 |

**推奨**: AWS WAF（基本）

### DDoS対策
- **Shield Standard**: 無料、基本的な保護
- **Shield Advanced**: 有料、高度な保護

---

## CI/CD・開発環境

### CI/CD
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **GitHub Actions** | GitHub統合、無料枠あり | GitHubメイン |
| **GitLab CI** | GitLab統合 | GitLabメイン |
| **CodePipeline + CodeBuild** | AWS完結 | AWS一本で統一 |

**推奨**: GitHub Actions

### コンテナレジストリ
- **ECR**: AWS標準、ECSと統合

### ローカル開発環境
- **Docker Compose**: 標準的
- **LocalStack**: AWS環境をローカルで再現（開発・テスト用）

### Linter/Formatter
| 言語 | 選択肢 |
|------|--------|
| Node.js | ESLint + Prettier |
| Python | Ruff (高速) / Black + Flake8 |
| Go | golangci-lint |

### テストフレームワーク
| 言語 | 選択肢 |
|------|--------|
| Node.js | Jest / Vitest |
| Python | pytest |
| Go | testing (標準) + testify |

---

## アーキテクチャパターン例

### 小〜中規模 (MVP〜成長期)
```
[CloudFront] → [ALB] → [ECS Fargate]
                         ↓
                    [RDS PostgreSQL]
                    [ElastiCache Redis]
                    [S3]
```

### 大規模 (スケール期)
```
[CloudFront] → [ALB] → [ECS Fargate (Auto Scaling)]
                         ↓
                    [Aurora PostgreSQL (Multi-AZ)]
                    [ElastiCache Redis (Cluster)]
                    [S3]
                         ↓
                    [SQS] → [Lambda / ECS Worker]
```

---

## コスト最適化のポイント

- **Fargate vs EC2**: 小規模ならFargate、大規模ならEC2（Savings Plans/Reserved Instances活用）
- **RDS vs Aurora**: トラフィックが少ないうちはRDS
- **SES**: メール送信はSESで十分な場合が多い
- **CloudWatch Logs**: ログ保持期間を適切に設定
- **S3ライフサイクル**: 古いファイルをGlacierへ自動移行

---

## 次のステップ

1. プロジェクトの規模・要件を明確化
2. 上記の選択肢から標準スタックを決定
3. System Design Doc のテンプレートに反映
4. IaCでインフラをコード化
5. CI/CDパイプライン構築
