# アーキテクチャ検討の軸（クラウド中立）

## 概要
技術スタック検討の入口。特定のクラウドを前提にせず、**アプリの形 → 通信方式 → 実行モデル → データ層 → プロバイダ**の順で決める。
プロバイダ別ドキュメント（`tech-stacks-aws.md` 等）は、ここで決めた軸をそのプロバイダのサービスに対応させるマッピング表。全プロバイダ分を読む必要はなく、このドキュメントで候補を2つ程度に絞ってから該当ファイルだけを読む。

想定はtoC向けWebサービス、toB向けSaaS、社内システム・管理画面。1人の開発者+AIでも運用可能な構成を基本とする。

---

## 軸1: アプリの形

最初に決める。ここが決まると後続の軸とプロバイダ候補が大きく絞れる。

| 形 | 構成 | 適している場合 |
|----|------|---------------|
| **フルスタックFW一体型** | Next.js / Nuxt / SvelteKit / Remix にUIとAPIを同居 | 小〜中規模Web、1人開発、SEOが要る、開発速度優先 |
| **SPA + 独立API** | React/Vue + 別プロセスのバックエンド | API を複数クライアント（Web+モバイル+外部）で共有、バックエンドの言語を分けたい |
| **BaaS + フロント** | Supabase/Firebase + SPA・モバイル | 認証+CRUD+リアルタイムが中心、バックエンドコードを最小化したい |
| **モバイル + API** | ネイティブ/React Native/Flutter + API or BaaS | モバイルが主戦場 |
| **API only** | ヘッドレスAPI、外部連携、バッチ | UIを持たない、他システムから呼ばれる |
| **CLI・デスクトップ** | 配布物。ホスティング不要 | ローカルツール（クラウド選定はほぼ不要） |

**推奨**: 1人開発のWebサービスはフルスタックFW一体型（構成要素が最少）。API を複数クライアントで共有する見込みが具体的にあるときだけ SPA + 独立API に分ける。

## 軸2: 通信方式

RESTだけが選択肢ではない。クライアント・サーバー間と、サーバー・サーバー間で分けて考える。

| 方式 | 特徴 | 適している場合 | 注意 |
|------|------|---------------|------|
| **REST** | デファクト、ツール・知見が最多 | 公開API、迷ったらこれ | OpenAPIでスキーマを書くと型生成・ドキュメントが揃う |
| **tRPC** | TypeScript前提、クライアント・サーバー間で型を直接共有 | TSモノレポ、フルスタックFW一体型 | 公開API・多言語クライアントには不向き |
| **GraphQL** | クライアント主導のデータ取得、1エンドポイント | 画面ごとに必要データが大きく違う、複数クライアント | サーバー実装・キャッシュ・N+1対策のコストが高い。小規模では過剰 |
| **gRPC** | バイナリ、高速、双方向ストリーミング、多言語 | サービス間通信、マイクロサービス | ブラウザから直接呼べない（grpc-web/Connectが要る）。個人開発の外向きAPIには過剰 |
| **WebSocket** | 双方向・常時接続 | チャット、共同編集、対戦、ライブ更新 | 常駐プロセスが要る。FaaSと相性が悪い（プロバイダ別ファイル参照） |
| **SSE** | サーバー→クライアントの一方向ストリーム | 通知、進捗表示、AI応答のストリーミング | HTTPだけで済む。双方向が不要ならWebSocketよりこちら |
| **Webhook** | 外部サービスからのイベント受信（HTTP POST） | 決済・外部SaaS連携 | 受け口は冪等に作る。署名検証を必ず入れる |
| **非同期メッセージング** | キュー/Pub-Sub経由、応答を待たない | ジョブ投入、サービス間のイベント連携 | 軸5（非同期処理）とセットで検討 |

**推奨**:
- 基本は **REST（またはTSモノレポならtRPC）を土台に、リアルタイムが要る箇所だけWebSocket/SSEを足す**。全面SocketやGraphQL全面採用は運用コストに見合わないことが多い
- サーバー→クライアントの一方向で足りるなら SSE、双方向が要るときだけ WebSocket
- リアルタイム要件がDB変更の購読程度なら、自前WebSocketよりBaaSのRealtime機能（`tech-stacks-supabase.md`）が安い

## 軸3: 実行モデル

通信方式との相性がここで効く。**WebSocket・gRPCストリーミングは常駐型が前提**。

| モデル | 例 | 特徴 | 常時接続(WS等) |
|--------|----|------|---------------|
| **コンテナ常駐** | Cloud Run、ECS、Fly.io | 言語自由、ローカルと同じものが動く、長時間処理可 | ◎ |
| **FaaS** | Lambda、Cloud Functions | リクエスト単位課金、アイドル0円、実行時間上限あり | △（別サービスの助けが要る） |
| **FWマネージド** | Vercel、Netlify | フレームワークを置くだけ。実体はFaaS+エッジ+CDN | ✕（外部サービス併用） |
| **エッジ** | Cloudflare Workers | 世界中で低レイテンシ、起動高速、CPU時間制限あり | ○（Durable Objects併用） |
| **VM** | EC2、Compute Engine | フル制御 | ◎（ただし運用負担最大） |

**推奨**: フルスタックFW一体型ならFWマネージド、独立APIならコンテナ常駐が基本線。FaaSは「イベント処理・ジョブの受け皿」として併用する位置づけで考える。

## 軸4: データ層

| 種類 | 選択肢 | 適している場合 |
|------|--------|---------------|
| **RDB** | PostgreSQL（標準）、MySQL | 迷ったらPostgreSQL。リレーションと整合性が要る大半のアプリ |
| **サーバーレスRDB** | Neon、PlanetScale、Cloudflare D1 | 接続数課金を避けたい、FaaS/エッジから使う、スケールto0でコスト最小化 |
| **ドキュメントDB** | Firestore、DynamoDB、MongoDB | スキーマ可変、リアルタイム同期（Firestore）、超大規模KV（DynamoDB） |
| **KV・キャッシュ** | Redis（マネージド各種、Upstash）、Workers KV | セッション、キャッシュ、レートリミット |
| **オブジェクトストレージ** | S3、Cloud Storage、R2 | ファイル・画像・動画。R2はエグレス無料 |
| **全文検索** | PostgreSQL全文検索、Meilisearch、Algolia | まずはPostgreSQLの機能で足りるか確認してから専用品 |
| **ベクトル** | pgvector、Pinecone | AI機能（類似検索・RAG）。まずはpgvector |

**推奨**: PostgreSQL を正とし、キャッシュ・検索・ベクトルは「まずPostgreSQL内の機能（Redis無しで済むか、全文検索、pgvector）で始めて、足りなくなったら専用サービスに切り出す」。データストアの種類を増やすほど運用が重くなる。

## 軸5: 非同期処理・スケジューラ

| 要件 | 実現手段の枠 | 例 |
|------|-------------|----|
| **ジョブキュー**（重い処理をリクエストから切り離す） | マネージドキュー+ワーカー / Redisベース | SQS+ワーカー、Cloud Tasks、BullMQ、pg-boss（PostgreSQLだけで済む） |
| **イベント駆動**（サービス間をイベントで繋ぐ） | Pub/Sub | SNS/EventBridge、Cloud Pub/Sub、Cloudflare Queues |
| **定期実行** | マネージドcron | EventBridge Scheduler、Cloud Scheduler、Vercel Cron、pg_cron |

**推奨**: 個人開発規模なら pg-boss / BullMQ のようなDB・Redis相乗り型で始めるのが最安。プロバイダのマネージドキューは「ワーカーのスケールを分けたくなってから」でよい。

## 軸6: 認証

| 枠 | 例 | 適している場合 |
|----|----|---------------|
| **BaaS付属** | Supabase Auth、Firebase Auth | BaaS採用時は迷わずこれ（DB・RLSと統合済み） |
| **IDaaS** | Clerk、Auth0、Cognito、Identity Platform | UIコンポーネント込みで速い（Clerk）、エンタープライズSSO（Auth0） |
| **FWライブラリ** | Auth.js、Better Auth | フルスタックFW内で完結、外部依存を増やしたくない、コスト0 |
| **自前JWT** | — | 特殊要件・学習目的のみ。基本選ばない |

## 共通アプリ基盤（プロバイダ非依存）

どのプロバイダでも変わらない選択肢。プロバイダ別ファイルには再掲しない。

### 言語・Webフレームワーク
| 言語 | フレームワーク | 特徴 | 適している場合 |
|------|--------------|------|---------------|
| **TypeScript** | Next.js等（一体型） | UIとAPIが同居 | フルスタックFW一体型を選んだ場合 |
| **TypeScript** | Hono | 超軽量、エッジ・コンテナ・FaaSどこでも動く | 独立API、エッジ、まず迷ったらこれ |
| **TypeScript** | NestJS | 構造が強い、エンタープライズ向け | 大規模、チーム開発、DI が欲しい |
| **Python** | FastAPI | 高速、型ヒント、自動ドキュメント | API中心、ML・AI連携 |
| **Python** | Django | フルスタック、管理画面標準 | 管理画面重視、短納期 |
| **Go** | Echo / Gin | 高速、シングルバイナリ | パフォーマンス重視、gRPCサービス |

**推奨**: TypeScript統一（一体型ならNext.js等、独立APIならHono）。ML連携があるならPython + FastAPI。

### ORM・バリデーション
| 言語 | ORM | バリデーション |
|------|-----|---------------|
| TypeScript | Prisma（DX重視・標準）/ Drizzle（軽量・エッジ対応） | Zod |
| Python | SQLAlchemy | Pydantic |
| Go | GORM / sqlc | go-validator |

**推奨**: Prisma（標準）。エッジ実行やコールドスタートが効く構成ではDrizzle。

### 開発ツール
| 用途 | TypeScript | Python | Go |
|------|-----------|--------|-----|
| Linter/Formatter | Biome（高速・一体型）/ ESLint+Prettier | Ruff | golangci-lint |
| テスト | Vitest | pytest | testing + testify |

### IaC
| 選択肢 | 特徴 | 適している場合 |
|--------|------|---------------|
| **Terraform** | マルチクラウド対応、デファクト | AWS/GCPを本格利用 |
| **Pulumi** | 開発言語でインフラ記述 | TypeScript等で統一したい |
| **プロバイダ固有** | CDK（AWS）、wrangler.toml（Cloudflare）、fly.toml（Fly.io） | そのプロバイダ一本 |
| **なし** | コンソール+設定ファイルのみ | Vercel/Supabase等のPaaS・BaaS中心構成では十分 |

**推奨**: PaaS・BaaS中心構成ならIaC無しで開始してよい（設定ファイルがリポジトリに残る構成を選ぶ）。AWS/GCPを本格利用するならTerraform。

### CI/CD・横断SaaS
- **CI/CD**: GitHub Actions を標準とする（プロバイダ純正CIは、そのプロバイダのファイルに記載がある場合のみ検討）
- **エラートラッキング**: Sentry（デファクト。全構成共通）
- **メール送信**: Resend（開発体験・個人開発の標準）/ SendGrid（配信管理が本格的）/ SES（AWS採用時の最安）
- **画像・メディア**: Cloudinary / Imgix（SaaS）、または各プロバイダのストレージ+変換（プロバイダ別ファイル参照）
- **決済**: Stripe

---

## プロバイダ選定マトリクス

軸1〜3の答えから候補を絞る。詳細は各プロバイダのマッピングファイルへ。

| アプリの形・要件 | 第一候補 | 次点 | 備考 |
|-----------------|---------|------|------|
| フルスタックFW一体型 | Vercel系（`tech-stacks-vercel.md`） | Cloudflare / Fly.io系 | リアルタイム要件が強いなら次点側も比較 |
| SPA + 独立API（小〜中規模） | Fly.io系（`tech-stacks-flyio.md`） | GCP Cloud Run | コンテナ常駐が安く速い |
| BaaS + フロント | Supabase系（`tech-stacks-supabase.md`）+ Vercel/Cloudflare Pages | Firebase | 認証+CRUD+リアルタイム中心ならこれが最少構成 |
| エッジ・グローバル低レイテンシ・低コスト | Cloudflare（`tech-stacks-cloudflare.md`） | — | 制約（CPU時間・Node互換）を先に確認 |
| WebSocket常駐・リアルタイム重視 | Fly.io系 / Supabase Realtime | Cloudflare Durable Objects | 実行モデルの相性が最重要 |
| 大規模・エンタープライズ・フル制御 | AWS（`tech-stacks-aws.md`） | GCP（`tech-stacks-gcp.md`） | 実績・サービス幅ならAWS、コンテナとデータ分析ならGCP |
| ML・データ分析連携 | GCP | AWS | BigQuery / Vertex AI |

### 選外だが状況次第で検討する候補（マッピングファイル無し）
- **Azure**: 3大クラウドの一角。Microsoft環境・エンタープライズ案件なら必須だが、個人開発では優先度低
- **VPS + セルフホスト**（Hetzner / DigitalOcean + Coolify / Kamal）: 月数ドル固定で全部乗せ。コスト最重視・学習目的なら有力。運用は全て自己責任
- **Deno Deploy**: エッジ実行。Cloudflareと同枠でエコシステムが小さい
- **Heroku**: Fly.io系と同枠の元祖。現在は割高
- **国内勢**（さくらのクラウド等）: データ国内要件・請求書払いが要る場合

---

## 次のステップ

1. 軸1〜2（アプリの形・通信方式)を決める — ここが後続すべての前提
2. 軸3〜6の要件を洗い、選定マトリクスでプロバイダ候補を2つに絞る
3. 該当するプロバイダ別ファイルだけを読み、比較して確定する
4. 決定と根拠(捨てた候補とのトレードオフ)を System Design Doc の ADR に記録する
