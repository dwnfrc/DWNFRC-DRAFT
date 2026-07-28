# GCP ベースのコア技術スタック選択肢

## 概要
toC向けWebサービス、toB向けSaaS、社内システム・管理画面を想定した、GCPベースの標準技術スタック選択肢。
認証機能とデータ永続化を基本とし、5〜10人規模の開発チームで運用可能な構成。

---

## インフラ・実行環境

### コンテナ実行環境
| 選択肢 | 特徴 | 適している場合 | コスト感 |
|--------|------|---------------|---------|
| **Cloud Run** | サーバーレス、自動スケール、最もシンプル | 小〜中規模、運用楽 | 低〜中 |
| **GKE Autopilot** | マネージドKubernetes、ノード管理不要 | Kubernetes必要、中〜大規模 | 中〜高 |
| **GKE Standard** | フルコントロールKubernetes | Kubernetes経験あり、細かい制御必要 | 中〜高 |
| **Compute Engine** | VM、最も柔軟 | 既存システム移行、特殊な要件 | 低〜中 |

**推奨**: Cloud Run（小〜中規模、シンプル）、GKE Autopilot（Kubernetes必要な場合）

### ロードバランサー
| 選択肢 | 用途 |
|--------|------|
| **Cloud Load Balancing (HTTP(S))** | Webアプリケーション、グローバル |
| **Cloud Load Balancing (TCP/UDP)** | 非HTTP、低レイテンシ |

**推奨**: Cloud Load Balancing (HTTP(S))

### CDN
- **Cloud CDN**: GCP標準、Cloud Storage/Cloud Runとの統合良好

### IaC (Infrastructure as Code)
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Terraform** | マルチクラウド対応、デファクト | 将来的に他クラウドも検討 |
| **Deployment Manager** | GCP専用、GCPサービスとの統合◎ | GCP一本で行く |
| **Pulumi** | TypeScript/Python等でインフラ記述 | 開発言語で統一したい |

**推奨**: Terraform（汎用性）、Pulumi（開発者フレンドリー）

### VPC設計
- VPCネットワーク
- サブネット（リージョン単位）
- Cloud NAT
- Cloud Armor (WAF)

---

## データ層

### RDB
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **Cloud SQL PostgreSQL** | マネージドPostgreSQL | 一般的なWebアプリ | 中 |
| **Cloud SQL MySQL** | マネージドMySQL | MySQL経験者が多い | 中 |
| **Cloud Spanner** | グローバル分散、水平スケール | グローバル展開、超大規模 | 高 |
| **AlloyDB** | PostgreSQL互換、高性能 | 高トラフィック、分析ワークロード | 高 |

**推奨**: Cloud SQL PostgreSQL（標準）、AlloyDB（高性能重視）

### NoSQL
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Firestore** | ドキュメントDB、リアルタイム同期 | モバイルアプリ、リアルタイム |
| **Datastore** | NoSQL、スケーラブル | Key-Value、大規模 |
| **Bigtable** | 大規模時系列データ | IoT、ログ、分析 |

### キャッシュ
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Memorystore Redis** | マネージドRedis | セッション管理、キャッシュ、ジョブキュー |
| **Memorystore Memcached** | マネージドMemcached | 単純なキャッシュ |

**推奨**: Memorystore Redis

### オブジェクトストレージ
- **Cloud Storage**: ファイル・画像・動画などの保存
  - Standard: 頻繁アクセス
  - Nearline: 月1回程度アクセス
  - Coldline: 年数回アクセス
  - Archive: 長期保存

### データベースマイグレーション
言語・フレームワークの標準ツールを使用（AWS版と同様）

### バックアップ
- **Cloud SQL自動バックアップ**: ポイントインタイムリカバリ
- **Cloud Storage**: バックアップ保存先

---

## アプリケーション基盤

### プログラミング言語・Webフレームワーク
AWS版と同様の選択肢（GCPは言語・FWに依存しない）

| 言語 | フレームワーク | 特徴 | 適している場合 |
|------|--------------|------|---------------|
| **Node.js** | Express | シンプル、軽量 | 小〜中規模、API中心 |
| **Node.js** | NestJS | TypeScript、エンタープライズ向け | 大規模、保守性重視 |
| **Python** | FastAPI | 高速、型ヒント、自動ドキュメント生成 | API開発、ML連携 |
| **Python** | Django | フルスタック、管理画面標準 | 管理画面重視、短納期 |
| **Go** | Echo | 高速、軽量 | パフォーマンス重視 |
| **Go** | Gin | 高速、人気 | パフォーマンス重視 |

**推奨**: Node.js + NestJS（TypeScript統一）、Python + FastAPI（API中心）

### ORM/クエリビルダー
AWS版と同様

### バリデーション
AWS版と同様

### ジョブキュー（非同期処理）
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Cloud Tasks** | タスクキュー、HTTP/gRPC呼び出し | 非同期処理、リトライ必要 |
| **Pub/Sub + Cloud Run** | メッセージング、スケーラブル | イベント駆動、マイクロサービス |
| **Pub/Sub + Cloud Functions** | サーバーレス | 小タスク、イベント処理 |
| **Bull (Redis)** | リッチな機能 | 複雑なジョブ管理 |

**推奨**: Cloud Tasks（基本）、Pub/Sub（イベント駆動）

### スケジューラー（定期実行タスク）
- **Cloud Scheduler**: cron式、Cloud Run/Cloud Functions起動
- **Cloud Functions + Cloud Scheduler**: サーバーレス

**推奨**: Cloud Scheduler + Cloud Run

---

## 認証・認可

### 認証サービス
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **Firebase Authentication** | モバイル・Web両対応、簡単 | 小〜中規模、クイックスタート | 低 |
| **Identity Platform** | Firebase Auth + エンタープライズ機能 | SAML/OIDC、大規模 | 中 |
| **Auth0** | 機能豊富、UI良い | エンタープライズ、複雑な要件 | 中〜高 |
| **自前実装 (JWT)** | 柔軟 | 特殊な要件 | 開発コスト |

**推奨**: Firebase Authentication（標準）、Identity Platform（エンタープライズ）

### セッション管理
- **Memorystore Redis**: セッション保存
- **Firebase Auth**: トークンベース

### 権限管理
- **IAM**: GCPリソースへのアクセス制御
- **アプリケーションレベル**: RBAC実装

---

## 外部連携

### メール送信
| 選択肢 | 特徴 | 適している場合 | コスト |
|--------|------|---------------|--------|
| **SendGrid** | GCP推奨パートナー、機能豊富 | トランザクション・マーケティング | 中 |
| **Mailgun** | 開発者向け、API優秀 | API中心の送信 | 中 |
| **Gmail API** | Gmail経由、小規模向け | 小規模、簡易用途 | 低 |

**推奨**: SendGrid

### メディア処理
#### 画像処理
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Cloud Functions + Sharp** | サーバーレス、自前実装 | カスタマイズ必要 |
| **Cloud Run + Sharp** | より長い実行時間可能 | 複雑な処理 |
| **Cloudinary** | SaaS、機能豊富 | 開発速度優先 |
| **Imgix** | SaaS、URL変換 | リアルタイム変換 |

**推奨**: Cloud Functions + Sharp（基本）、Cloud Run（複雑な処理）

#### 動画処理
- **Transcoder API**: 動画変換・エンコーディング

---

## 監視・ログ・エラー追跡

### ログ収集
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Cloud Logging** | GCP標準、統合良好 | GCP中心 |
| **Datadog** | 統合監視、UI優秀 | 本格的な監視 |
| **ELK (Elasticsearch)** | オープンソース | 自前構築 |

**推奨**: Cloud Logging（基本）、Datadog（本格監視）

### エラートラッキング
| 選択肢 | 特徴 |
|--------|------|
| **Sentry** | デファクト、詳細なエラー情報 |
| **Error Reporting** | GCP標準、シンプル |

**推奨**: Sentry（詳細分析）、Error Reporting（シンプル）

### APM (Application Performance Monitoring)
| 選択肢 | 特徴 |
|--------|------|
| **Cloud Trace** | GCP標準、分散トレーシング |
| **Cloud Profiler** | パフォーマンスプロファイリング |
| **Datadog APM** | 統合監視、リッチ |

**推奨**: Cloud Trace + Cloud Profiler（GCP標準）、Datadog（統合監視）

### インフラ監視
- **Cloud Monitoring**: メトリクス、アラート、ダッシュボード
- **Datadog**: より詳細、美しいUI

### アラート通知
- **Cloud Monitoring + Pub/Sub**: Slack/メール通知
- **Cloud Functions**: カスタム通知ロジック

---

## セキュリティ

### シークレット管理
- **Secret Manager**: シークレット管理、バージョニング、自動ローテーション

### SSL/TLS証明書
- **Google-managed SSL certificates**: 無料、自動更新（Cloud Load Balancing経由）
- **Let's Encrypt**: 自己管理の場合

### WAF
- **Cloud Armor**: WAF、DDoS対策、カスタムルール

### DDoS対策
- **Cloud Armor**: 標準で基本的な保護、ルールでカスタマイズ可能

---

## CI/CD・開発環境

### CI/CD
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Cloud Build** | GCP標準、Cloud Run/GKEとの統合◎ | GCP中心 |
| **GitHub Actions** | GitHub統合、無料枠あり | GitHubメイン |
| **GitLab CI** | GitLab統合 | GitLabメイン |

**推奨**: Cloud Build（GCP統合）、GitHub Actions（GitHub中心）

### コンテナレジストリ
- **Artifact Registry**: GCP標準、Docker/Maven/npm等対応
- **Container Registry**: 旧サービス（Artifact Registryへの移行推奨）

### ローカル開発環境
- **Docker Compose**: 標準的
- **Cloud Code**: IDE統合（VS Code/IntelliJ）、Cloud Run/GKEローカル開発

### Linter/Formatter
AWS版と同様

### テストフレームワーク
AWS版と同様

---

## GCP特有の便利サービス

### Firebaseエコシステム
- **Firebase Authentication**: 認証
- **Cloud Firestore**: NoSQL、リアルタイム同期
- **Firebase Hosting**: 静的サイトホスティング
- **Firebase Cloud Messaging**: プッシュ通知
- **Firebase Remote Config**: アプリ設定の動的変更

→ モバイルアプリ開発時に特に有効

### BigQuery
- データウェアハウス
- 大規模データ分析
- ログ分析、アクセス解析

### Vertex AI
- 機械学習プラットフォーム
- AutoML、カスタムモデル

---

## アーキテクチャパターン例

### 小〜中規模 (MVP〜成長期)
```
[Cloud CDN] → [Cloud Load Balancing] → [Cloud Run]
                                          ↓
                                    [Cloud SQL PostgreSQL]
                                    [Memorystore Redis]
                                    [Cloud Storage]
```

### 大規模 (スケール期)
```
[Cloud CDN] → [Cloud Load Balancing] → [Cloud Run (Auto Scaling)]
                                          ↓
                                    [AlloyDB / Cloud Spanner]
                                    [Memorystore Redis (HA)]
                                    [Cloud Storage]
                                          ↓
                                    [Pub/Sub] → [Cloud Functions / Cloud Run]
```

### Firebaseベース（モバイルアプリ中心）
```
[Firebase Hosting]
       ↓
[Firebase Authentication]
       ↓
[Cloud Firestore] ← [Cloud Functions]
       ↓
[Cloud Storage]
```

---

## コスト最適化のポイント

- **Cloud Run**: 使った分だけ課金、アイドル時0円
- **Cloud SQL**: 必要に応じて自動スケール
- **Cloud Storage**: ライフサイクル管理で古いファイルを安いストレージクラスへ
- **Committed Use Discounts**: 長期利用割引（1年/3年）
- **Preemptible VM**: Compute Engine使う場合、最大80%割引

---

## GCP vs AWS 主要な違い

| 項目 | GCP | AWS |
|------|-----|-----|
| **コンテナ実行** | Cloud Run（より簡単） | ECS Fargate |
| **Kubernetes** | GKE（評価高い） | EKS |
| **RDB** | Cloud SQL / AlloyDB | RDS / Aurora |
| **認証** | Firebase Auth | Cognito |
| **ジョブキュー** | Cloud Tasks / Pub/Sub | SQS |
| **ログ・監視** | Cloud Logging/Monitoring | CloudWatch |
| **CDN** | Cloud CDN | CloudFront |
| **ML** | Vertex AI | SageMaker |

### GCPが優れている点
- Cloud Runのシンプルさ（サーバーレスコンテナ）
- BigQueryの高速・使いやすさ
- GKEの評価・安定性
- Firebaseのモバイル統合

### AWSが優れている点
- サービスの幅広さ
- 実績・事例の多さ
- ドキュメント・コミュニティ
- エンタープライズ機能

---

## 次のステップ

1. プロジェクトの規模・要件を明確化
2. GCPの無料枠を活用してプロトタイプ作成
3. 上記の選択肢から標準スタックを決定
4. System Design Doc のテンプレートに反映
5. IaCでインフラをコード化
6. Cloud Buildでパイプライン構築
