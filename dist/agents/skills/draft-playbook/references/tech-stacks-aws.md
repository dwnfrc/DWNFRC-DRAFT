# AWS マッピング

## 位置づけ

サービスの幅・実績・エンタープライズ機能で最有力。構成要素が多く運用の学習コストは最大なので、「大規模前提」「業務要件（VPC内接続・監査・コンプライアンス）」「AWS経験がある」のいずれかがないなら、まずPaaS系（Fly.io / Vercel）やGCPと比較してから選ぶ。

前提: 検討の軸と共通アプリ基盤（言語・FW・ORM・CI/CD等）は `tech-stacks-architecture.md` が正。このファイルは軸をAWSサービスへ対応させるマッピングのみを持つ。

## 軸 → サービス対応表

| 軸 | 標準 | 代替 | 備考 |
|----|------|------|------|
| コンテナ常駐 | **ECS Fargate** | ECS EC2（コスト最適化）、App Runner（最小構成）、EKS（k8s経験者のみ） | 小〜中規模はFargate、大規模でEC2+Savings Plans |
| FaaS | **Lambda** | — | 15分上限。ジョブ・イベント処理の受け皿 |
| RDB | **RDS PostgreSQL** | Aurora PostgreSQL（高可用・高トラフィック） | Aurora Serverless v2でスケールto低 |
| KV・キャッシュ | **ElastiCache Redis** | DynamoDB（大規模KV） | |
| オブジェクトストレージ | **S3** | +Glacier（アーカイブ） | |
| ジョブキュー | **SQS + Lambda**（〜15分） | SQS + ECSワーカー（長時間） | |
| イベント駆動 | **EventBridge / SNS** | | |
| 定期実行 | **EventBridge Scheduler** | | |
| 認証 | **Cognito** | Clerk / Auth0（UX・機能重視の外部IDaaS） | Cognitoは安いがUI・DXは弱い |
| メール | **SES**（最安） | Resend / SendGrid | |
| CDN | **CloudFront** | | |
| LB | **ALB** | NLB（TCP/UDP・低レイテンシ） | |
| WAF・DDoS | **AWS WAF + Shield Standard** | | |
| シークレット | **Secrets Manager**（本番） | Parameter Store（開発・低コスト） | |
| 証明書 | **ACM**（無料・自動更新） | | |
| ログ・監視 | **CloudWatch** | Datadog（本格監視） | エラー追跡はSentry（共通基盤） |
| APM | **X-Ray** | Datadog APM | |
| IaC | **Terraform** | CDK（TypeScriptで書きたい場合） | |
| コンテナレジストリ | **ECR** | | |
| ローカル開発 | Docker Compose | +LocalStack（AWSサービスのモック） | |

## 通信方式の対応

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST / tRPC / GraphQL | ALB + ECS、または API Gateway + Lambda | HTTPベースは全て素直に動く |
| WebSocket | **ALB + ECS常駐**（推奨）/ API Gateway WebSocket API + Lambda | Lambda経路は接続管理（コネクションID保存）を自前実装することになり複雑。常駐が素直 |
| SSE | ALB + ECS常駐 | Lambdaはレスポンスストリーミング対応だが常駐が素直 |
| gRPC | ALB（HTTP/2対応）+ ECS | サービス間通信で採用する場合。ブラウザ向けはgrpc-web/Connect併用 |
| Webhook受信 | API Gateway + Lambda、または通常のAPIエンドポイント | 冪等化・署名検証は共通（軸2参照） |
| 非同期メッセージング | SQS（キュー）/ SNS・EventBridge（Pub/Sub） | |

## 参考構成

### 標準（SPA + 独立API、小〜中規模）
```
[CloudFront] → [ALB] → [ECS Fargate]
                         ↓
                    [RDS PostgreSQL]
                    [ElastiCache Redis]
                    [S3]
```

### スケール期（+非同期処理）
```
[CloudFront] → [ALB] → [ECS Fargate (Auto Scaling)]
                         ↓
                    [Aurora PostgreSQL (Multi-AZ)]
                    [ElastiCache Redis (Cluster)]
                    [S3]
                         ↓
                    [SQS] → [Lambda / ECS Worker]
```

## コスト感

- 最小でもALB（月約$20〜）+ Fargate + RDS で**月$50〜100程度から**。スケールto0の構成が作りにくく、個人開発の固定費としては重い
- 削減手段: Fargate→EC2 + Savings Plans（大規模）、RDS→Aurora Serverless v2、S3ライフサイクルでGlacierへ、CloudWatch Logsの保持期間設定

## 強み・弱み

- **選ぶ理由**: サービスの幅と実績、エンタープライズ要件（監査・ネットワーク制御）、既存AWS資産との統合
- **選ばない理由**: 固定費とインフラ構成の重さ。同じコンテナ常駐ならCloud Run（GCP）やFly.ioの方が安く簡単。フルスタックFW一体型ならVercel系が速い
