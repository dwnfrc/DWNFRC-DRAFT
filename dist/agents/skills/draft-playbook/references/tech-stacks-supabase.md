# Supabase系 BaaS マッピング（Supabase / Firebase / PocketBase）

## 位置づけ

BaaS（Backend as a Service）枠。**認証 + DB + ストレージ + リアルタイムを一体で提供し、バックエンドコードを最小化する**。「BaaS + フロント」の形を選んだときの本命で、CRUDとリアルタイム購読が中心のアプリなら独立APIを書かずに成立する。リアルタイム要件（ライブ更新・プレゼンス）を最小コストで満たす経路でもある。

この枠の使い分け:

| サービス | 中身 | 選ぶ場合 |
|---------|------|---------|
| **Supabase** | **素のPostgreSQL** + Auth + Realtime + Storage | SQL・リレーションで設計したい（大半のケース）。卒業しても普通のPostgresとして持ち出せる |
| **Firebase** | Firestore（NoSQL）+ Auth + FCM + Hosting | モバイル中心、プッシュ通知（FCM）必須、オフライン同期が要る |
| **PocketBase** | SQLite一体の単一バイナリ（セルフホスト） | 超小規模・自分用ツール。VPS1台やFly.ioに置くだけ |

以下はSupabaseを主に書く。

前提: 検討の軸と共通アプリ基盤は `tech-stacks-architecture.md` が正。フロントのホスティングは別途選ぶ（Vercel / Cloudflare が定番の相方）。

## 軸 → サービス対応表

| 軸 | Supabase | Firebase での対応物 | 備考 |
|----|----------|--------------------|------|
| RDB | **PostgreSQL（そのもの）** | Firestore（NoSQL） | pgvector・PostGIS等の拡張も使える |
| 認証 | **Supabase Auth** | Firebase Auth | ソーシャルログイン・マジックリンク込み |
| 認可 | **RLS（Row Level Security）** | Security Rules | **BaaSの要。クライアント直アクセスの安全性はここで担保する** |
| API自動生成 | **PostgREST（REST）/ supabase-js** | SDK直接読み書き | テーブル定義からREST APIが自動で生える |
| リアルタイム | **Realtime**（DB変更購読 / Broadcast / Presence） | Firestoreリアルタイムリスナー | WebSocketを自前実装せずに済む |
| サーバーレス関数 | **Edge Functions**（Deno） | Cloud Functions for Firebase | Webhook受信・外部API連携・RLSで書けないロジック用 |
| オブジェクトストレージ | **Storage**（画像変換つき） | Cloud Storage for Firebase | |
| ジョブキュー | **pgmq + pg_cron** | Cloud Tasks併用 | Postgres内で完結 |
| 定期実行 | **pg_cron** | Cloud Scheduler併用 | |
| プッシュ通知 | 外部（FCM等を併用） | **FCM（最強）** | プッシュ通知が主要件ならFirebase優位 |
| メール | 認証メールは内蔵。その他は **Resend**（共通基盤） | | |
| フロントのホスティング | **Vercel / Cloudflare**（別途） | Firebase Hosting / App Hosting | |
| ログ・監視 | ダッシュボード + Logs | Firebaseコンソール | エラー追跡はSentry（共通基盤） |
| IaC | **マイグレーションSQL + supabase CLI**（config.toml） | firebase.json | スキーマ・RLSをリポジトリで管理できる。ローカル開発も `supabase start` で完結 |
| CI/CD | GitHub Actions + supabase CLI（マイグレーション適用） | firebase deploy | |

## 通信方式の対応

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST | **自動生成（PostgREST）** + Edge Functions | CRUDはコードを書かずに済む |
| リアルタイム購読 | **Realtime（WebSocket）** | 自前WSサーバー不要。DB変更購読・チャンネルBroadcast・Presence |
| WebSocket（自前ロジック） | ✕（Realtimeの枠を超えるもの） | 対戦ロジック等サーバー側の状態機械が要るならFly.io等の常駐を併設 |
| SSE | Edge Functions（ストリーミング） | |
| GraphQL | pg_graphql（拡張） | 必要なら有効化できる程度の位置づけ |
| gRPC | ✕ | この枠ではない |
| Webhook受信 | Edge Functions | |
| DB→外部への通知 | Database Webhooks | 行変更をトリガに外部URLへPOST |

## 参考構成

### 標準（BaaS + フロント）
```
[Vercel / Cloudflare (SPA・Next.js)]
   ↓ supabase-js（RLSで認可）
[Supabase: Auth + PostgreSQL + Storage]
   ↓
[Edge Functions]（Webhook受信・外部API連携）
```

### リアルタイムアプリ（チャット・ライブ更新）
```
[フロント] ⇄ [Supabase Realtime (WS)] ⇄ [PostgreSQL]
    ↓
[Supabase Auth]（Presence＝オンライン表示もRealtimeで）
```

### ハイブリッド（独立APIと併用）
```
[フロント] → [独立API (Fly.io等)] → [Supabase PostgreSQL（DBとして利用）]
    ↓                                   ↑
[Supabase Auth]（トークンをAPIで検証） [Realtime]（購読だけBaaS経由）
```

## コスト感

- 無料枠で開発〜小規模運用は十分（一時停止に注意）。Pro **$25/月〜**で本番運用
- Firebaseは従量課金（Firestoreの読み書き課金はアクセスパターン次第で跳ねる）。PocketBaseはホスト代のみ

## 強み・弱み

- **選ぶ理由**: バックエンド開発量が最小、認証・リアルタイム・ストレージが即戦力、素のPostgresなのでロックインが緩い（最悪DBごと移設できる）
- **選ばない理由**: 複雑なドメインロジックはRLS+自動生成APIに収まらず、結局独立APIを書くことになる（その場合はDB+Authだけ使うハイブリッドに寄せる）。gRPC・自前WSサーバーが要る構成には不向き。**RLSの設計を疎かにするとクライアント直アクセスがそのまま脆弱性になる**（権限マトリクスをSystem Design Docに必ず書く）
