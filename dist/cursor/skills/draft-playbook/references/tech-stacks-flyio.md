# Fly.io系PaaS マッピング（Fly.io / Railway / Render）

## 位置づけ

「**コンテナをそのまま安く世界に置く**」枠。Dockerfileがあれば数分でデプロイでき、常駐プロセスなのでWebSocket・gRPC・長時間処理が何の工夫もなく動く。「SPA + 独立API」「WebSocket常駐・リアルタイム重視」を選んだときの第一候補。AWS/GCPのようなサービスの網羅性はなく、DB以外のマネージドサービス（キュー・認証等）はほぼ無いので、足りないものは外部SaaSで補う。

この枠の使い分け:

| サービス | 特徴 | 選ぶ場合 |
|---------|------|---------|
| **Fly.io** | マルチリージョン、Machines（マイクロVM）、CLI中心 | グローバル配置・WebSocket・柔軟な構成が欲しい |
| **Railway** | DXが良い、ダッシュボード中心、使用量課金 | とにかく速く置きたい、DB込みで1画面で管理したい |
| **Render** | マネージドPostgres・cron・ワーカーが揃う、Heroku代替の本命 | Herokuライクな安定運用が欲しい |

以下のマッピングはFly.ioを主に書く（Railway/Renderは概ね同型で、対応物を併記）。

前提: 検討の軸と共通アプリ基盤は `tech-stacks-architecture.md` が正。

## 軸 → サービス対応表

| 軸 | Fly.io | Railway / Render での対応物 | 備考 |
|----|--------|---------------------------|------|
| コンテナ常駐 | **Machines**（Fly Launch） | Railway Service / Render Web Service | スケールto0可（autostop/autostart） |
| ワーカー | **Machines**（別プロセス） | Railway Service / Render Background Worker | |
| RDB | **Fly Postgres（非マネージド）** または **Neon / Supabase**（外部） | Railway Postgres / Render Postgres（マネージド） | Fly Postgresは自動フェイルオーバー等を自分で面倒みる。**運用を任せたいなら外部のNeon/Supabase推奨** |
| KV・キャッシュ | **Upstash Redis**（統合） | Railway Redis / Render Key Value | |
| オブジェクトストレージ | **Tigris**（統合、S3互換） | 外部のR2 / S3 | R2併用も定番（エグレス無料） |
| ジョブキュー | アプリ内で **BullMQ / pg-boss** | 同左 | マネージドキューは無い。共通基盤の推奨どおりDB/Redis相乗り型 |
| 定期実行 | Machines のスケジュール起動 | Railway Cron / Render Cron Job | |
| 認証 | **Better Auth / Auth.js / Clerk**（外部） | 同左 | 純正認証は無い |
| メール | **Resend / SendGrid**（共通基盤） | 同左 | |
| CDN・WAF | **Cloudflareを前段に**（定番） | 同左 | Fly単体はAnycast+証明書のみ。WAFが要るならCF前段 |
| シークレット | **fly secrets** | Railway/Render の環境変数管理 | |
| ログ・監視 | **fly logs + Grafana（標準装備）** | 各ダッシュボード | エラー追跡はSentry（共通基盤） |
| IaC | **fly.toml**（設定ファイル） | railway.json / render.yaml | 設定ファイルがリポジトリに残る。Terraform不要 |
| CI/CD | GitHub Actions + flyctl | Git push連携（Railway/Renderは標準） | |

## 通信方式の対応

常駐プロセスなので**全方式が素直に動く**。この枠の最大の強み。

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST / tRPC / GraphQL | そのまま | |
| WebSocket | **そのまま**（制限なし） | 複数インスタンス時の状態共有はRedis Pub/Sub等で（どのプロバイダでも同じ） |
| SSE | そのまま | |
| gRPC | そのまま | Fly ProxyはHTTP/2対応。サービス間もFlycast（内部ネットワーク）で直結 |
| Webhook受信 | そのまま | |
| 非同期メッセージング | BullMQ / pg-boss（アプリ内） | マネージドPub/Subが要る規模ならAWS/GCPを検討 |

## 参考構成

### 標準（SPA + 独立API / API only）
```
[Cloudflare CDN/WAF] → [Fly.io Machines (Hono/FastAPI等)]
                          ↓
                     [Neon PostgreSQL（外部）]
                     [Upstash Redis]
                     [Tigris / R2]
```

### リアルタイム（WebSocket常駐）
```
[クライアント] ⇄ WebSocket ⇄ [Fly.io Machines (常駐、マルチリージョン)]
                                ↓
                           [Upstash Redis (Pub/Sub)]
                           [Neon PostgreSQL]
```

### ワーカー分離（重い処理あり）
```
[Fly.io Machines (API)] → [pg-boss / BullMQ] → [Fly.io Machines (Worker)]
                               ↓
                          [PostgreSQL / Redis]
```

## コスト感

- 使用量課金 + スケールto0で、**小規模なら月$5〜10程度**から。AWSの最小構成より一桁安い
- DBを外部（Neon無料枠等）にすればさらに下がる。Railway/Renderも同水準（Renderは無料プランあり、スリープに注意）

## 強み・弱み

- **選ぶ理由**: コンテナがそのまま動く自由度、全通信方式ネイティブ対応、低コスト、fly.toml だけで完結する運用
- **選ばない理由**: マネージドサービスの網羅性が無い（キュー・高度なDB運用・コンプライアンス）。組織要件・大規模になったらAWS/GCPへ。フルスタックFW一体型で リアルタイム不要ならVercel系の方が手数が少ない
