# Cloudflare マッピング

## 位置づけ

エッジファースト。世界中で低レイテンシ、無料枠が非常に大きく、**R2のエグレス（転送量）無料**が効く。CDN・WAF・DNSだけを他クラウドの前段に置く使い方と、Workersを中心にフルスタックを組む使い方の2通りがある。「エッジ・グローバル低レイテンシ・低コスト」を選んだときの第一候補。

制約を先に確認する: Workersは常駐プロセスではなくCPU時間に制限があり、Node.js完全互換ではない（nodejs_compatで主要APIはカバー）。重い計算・長時間処理・特殊なネイティブ依存があるなら、コンテナ枠（Fly.io / Cloud Run）と比較する。

前提: 検討の軸と共通アプリ基盤は `tech-stacks-architecture.md` が正。このファイルはCloudflareへのマッピングのみを持つ。

## 軸 → サービス対応表

| 軸 | 標準 | 代替 | 備考 |
|----|------|------|------|
| エッジ実行 | **Workers** | | 静的アセット配信もWorkersに統合（旧Pages） |
| フルスタックFW | **Workers**（OpenNext / @cloudflare/vite-plugin） | | Next.js/Remix/SvelteKit/Astro等をデプロイ可 |
| コンテナ常駐 | **Containers**（β） | 成熟するまではFly.io / Cloud Run併用 | Workersで足りない重い処理向け |
| RDB | **D1**（SQLite） | **Hyperdrive + 外部PostgreSQL**（Neon等） | D1は小〜中規模向け。Postgres が要るならHyperdrive経由 |
| KV | **Workers KV**（結果整合・読み特化） | Durable Objects（強整合） | セッション・設定値向け |
| オブジェクトストレージ | **R2** | | S3互換API、エグレス無料が最大の強み |
| ステートフル・調整役 | **Durable Objects** | | WebSocket・排他制御・ルーム管理の要 |
| ジョブキュー | **Queues** | | |
| 定期実行 | **Cron Triggers** | | |
| 認証 | **Better Auth / Auth.js**（FWライブラリ枠） | Clerk、Cloudflare Access（社内向けゼロトラスト） | 純正の汎用IDaaSは無い |
| メール | **Resend / SendGrid**（共通基盤） | | |
| CDN・WAF・DDoS | **標準装備**（CDN / WAF / DDoS / Turnstile） | | ここが本業。他クラウド構成の前段にも使える |
| ログ・監視 | **Workers Logs / Analytics Engine** | Sentry（エラー追跡、共通基盤） | |
| AI | **Workers AI / Vectorize / AI Gateway** | | エッジでの推論・ベクトル検索・LLMプロキシ |
| IaC | **wrangler.toml**（設定ファイル） | Terraform | wrangler中心で十分。設定がリポジトリに残る |
| CI/CD | GitHub Actions + wrangler | Workers Builds（Git連携） | |
| ローカル開発 | **wrangler dev**（Miniflare） | | 本番同等のローカル実行 |

## 通信方式の対応

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST / tRPC | Workers（Hono が定番） | 素直に動く。エッジなので世界中で速い |
| GraphQL | Workers | GraphQL Yoga等。動くが重いリゾルバはCPU制限に注意 |
| WebSocket | **Durable Objects**（Hibernation API） | Workers単体では状態を持てないためDO前提。ルーム単位にDOを1つ割り当てる設計が定石 |
| SSE | Workers（ストリーミングレスポンス） | AI応答ストリーミング等に好適 |
| gRPC | ✕（着信非対応） | WorkersはgRPCを受けられない。gRPCが要るならコンテナ枠へ。ConnectのHTTP/JSONマッピングなら可 |
| Webhook受信 | Workers | 起動が速くWebhook受け口に好適 |
| 非同期メッセージング | Queues | |

## 参考構成

### エッジフルスタック（小〜中規模、低コスト最優先）
```
[Workers (Hono / フルスタックFW)]
   ↓
[D1] [Workers KV] [R2]
   ↓
[Queues] → [Workers (consumer)]
```

### リアルタイム（チャット・共同編集）
```
[Workers] ⇄ WebSocket ⇄ [Durable Objects (ルームごと)]
                            ↓
                       [D1 / R2]
```

### 他クラウドの前段（ハイブリッド）
```
[Cloudflare CDN + WAF + DNS] → [Fly.io / Cloud Run / AWS のアプリ本体]
        ↓
      [R2]（画像・ファイル配信。エグレス無料）
```

## コスト感

- **無料枠が非常に大きい**（Workers 10万リクエスト/日、D1・KV・R2それぞれ無料枠あり）。有料でも$5/月〜で、個人開発の全構成で最安クラス
- R2のエグレス無料は、画像・動画・ファイル配信が多いサービスで他クラウドとの決定的な差になる

## 強み・弱み

- **選ぶ理由**: コスト、グローバル低レイテンシ、CDN/WAF標準装備、R2エグレス無料、Durable Objectsによる安価なリアルタイム
- **選ばない理由**: gRPC着信不可・CPU時間制限・Node互換の穴。長時間処理・重い計算・Postgresフル機能が中心のアプリはコンテナ枠（Fly.io / Cloud Run）が素直
