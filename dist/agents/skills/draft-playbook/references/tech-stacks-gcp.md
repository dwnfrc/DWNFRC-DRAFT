# GCP マッピング

## 位置づけ

**Cloud Run（サーバーレスコンテナ）が個人開発と相性抜群**。コンテナを置くだけでスケールto0・WebSocket・gRPCまで動く。データ分析（BigQuery）・ML（Vertex AI）・Firebaseエコシステムも強い。「SPA + 独立API」「API only」でコンテナ常駐を選んだときの第一候補群。

前提: 検討の軸と共通アプリ基盤（言語・FW・ORM・CI/CD等）は `tech-stacks-architecture.md` が正。このファイルは軸をGCPサービスへ対応させるマッピングのみを持つ。

## 軸 → サービス対応表

| 軸 | 標準 | 代替 | 備考 |
|----|------|------|------|
| コンテナ常駐 | **Cloud Run** | GKE Autopilot（k8sが必要な場合のみ） | スケールto0対応。個人開発の本命 |
| FaaS | **Cloud Run functions** | | Cloud Runに統合された（旧Cloud Functions） |
| RDB | **Cloud SQL PostgreSQL** | AlloyDB（高性能）、Neon等サーバーレスRDB（コスト最小化） | Cloud SQLは止めても課金される点に注意 |
| NoSQL | **Firestore** | Bigtable（時系列・超大規模） | リアルタイム同期はFirestoreの強み |
| KV・キャッシュ | **Memorystore Redis** | Upstash（従量課金で安い） | Memorystoreは固定費が重め |
| オブジェクトストレージ | **Cloud Storage** | | ストレージクラスで長期保存も |
| ジョブキュー | **Cloud Tasks** | Pub/Sub + Cloud Run | |
| イベント駆動 | **Pub/Sub** | Eventarc | |
| 定期実行 | **Cloud Scheduler** | | |
| 認証 | **Firebase Authentication** | Identity Platform（SAML/OIDC）、Clerk / Auth0 | |
| メール | **Resend / SendGrid**（共通基盤） | | GCPに純正メールサービスは無い |
| CDN | **Cloud CDN** | Cloudflare（前段に置く構成も一般的） | |
| LB | **Cloud Load Balancing** | | Cloud Runは小規模ならLB無し（直接URL）でも運用可 |
| WAF・DDoS | **Cloud Armor** | | |
| シークレット | **Secret Manager** | | |
| 証明書 | **Google-managed SSL** | | LB経由なら無料・自動更新 |
| ログ・監視 | **Cloud Logging / Monitoring** | Datadog（本格監視） | エラー追跡はSentry（共通基盤） |
| APM | **Cloud Trace** | | |
| IaC | **Terraform** | Pulumi | |
| コンテナレジストリ | **Artifact Registry** | | |
| CI/CD | GitHub Actions（共通基盤） | Cloud Build（GCP完結にしたい場合） | |

## 通信方式の対応

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST / tRPC / GraphQL | Cloud Run | 素直に動く |
| WebSocket | **Cloud Run**（ネイティブ対応） | リクエストタイムアウト（最大60分）で切断→クライアント再接続を実装。インスタンス間の状態共有はRedis等のPub/Sub |
| SSE | Cloud Run | 同上（タイムアウトと再接続） |
| gRPC | **Cloud Run**（ネイティブ対応、ストリーミング含む） | HTTP/2をエンドツーエンドで有効化する設定を忘れない |
| Webhook受信 | Cloud Run / Cloud Run functions | |
| 非同期メッセージング | Pub/Sub（Pub/Sub）/ Cloud Tasks（キュー） | pushサブスクリプションでCloud Runを叩く構成が楽 |

## 参考構成

### 標準（SPA + 独立API、小〜中規模）
```
[Cloud CDN / Cloudflare] → [Cloud Run]
                             ↓
                        [Cloud SQL PostgreSQL]
                        [Cloud Storage]
```

### スケール期（+非同期処理）
```
[Cloud CDN] → [Cloud Load Balancing] → [Cloud Run (Auto Scaling)]
                                          ↓
                                    [AlloyDB / Cloud SQL]
                                    [Memorystore Redis]
                                    [Cloud Storage]
                                          ↓
                                    [Pub/Sub] → [Cloud Run Worker]
```

### Firebaseベース（モバイル・リアルタイム中心）
```
[Firebase Hosting] → [Firebase Auth] → [Firestore] ← [Cloud Run functions]
                                            ↓
                                      [Cloud Storage]
```
※ この構成に寄せるなら `tech-stacks-supabase.md`（BaaS枠）とも比較する

## コスト感

- **Cloud Runはスケールto0**なのでアイドル時ほぼ0円。個人開発の最小構成はAWSよりだいぶ安い
- 固定費の主因はCloud SQL（止めても課金）とMemorystore。コスト最小化ならDBをNeon等のサーバーレスRDB、RedisをUpstashに置き換える構成も成立する
- 無料枠: Cloud Run・Firestore・Cloud Storageの無料枠が大きい

## 強み・弱み

- **選ぶ理由**: Cloud Runの手軽さと通信方式の対応幅（WS/gRPCネイティブ）、BigQuery・Vertex AI、Firebase統合
- **選ばない理由**: エンタープライズ実績・サービス幅はAWSに劣る。フルスタックFW一体型ならVercel系の方が速い。Cloud SQLの固定費が気になる規模ならFly.io + Neon等も比較
