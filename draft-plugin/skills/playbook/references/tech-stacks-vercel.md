# Vercel系 マッピング（Vercel / Netlify）

## 位置づけ

フロントエンドクラウド。**フルスタックFW一体型（Next.js等）を選んだときの第一候補**。Gitにpushすればビルド・CDN・プレビュー環境まで自動で揃い、インフラ作業がほぼ消える。DB等のバックエンドリソースはVercel Marketplaceで外部サービス（Neon / Upstash等）を紐付けて補う。

Netlifyは同型の代替(Astro等との相性・フォーム機能)。以下はVercelを主に書く。

前提: 検討の軸と共通アプリ基盤は `tech-stacks-architecture.md` が正。このファイルはVercel系へのマッピングのみを持つ。

## 軸 → サービス対応表

| 軸 | 標準 | 備考 |
|----|------|------|
| フルスタックFW | **Vercel（Next.js最適化）** | Nuxt/SvelteKit/Remix/Astroも対応 |
| FaaS | **Vercel Functions**（Fluid Compute） | FWのAPIルートがそのままFunctionsになる。ストリーミング対応・実行時間も伸びた |
| エッジ | **Edge Network / Routing Middleware** | 認証チェック・A/B等の前段処理 |
| RDB | **Neon PostgreSQL**（Marketplace） | サーバーレスPostgres、スケールto0。Prisma Postgres / PlanetScale も同枠 |
| KV・キャッシュ | **Upstash Redis**（Marketplace） | 従量課金 |
| オブジェクトストレージ | **Vercel Blob** | 大容量・配信量が多いならR2併用 |
| ジョブキュー・長時間処理 | **Vercel Workflow / Queues** | リクエスト時間を超える処理の受け皿。重いワーカーが常駐で要るならFly.io併用 |
| 定期実行 | **Vercel Cron Jobs** | |
| 認証 | **Auth.js / Better Auth**（FWライブラリ枠） | UIコンポーネント込みで速くしたいなら Clerk |
| メール | **Resend**（共通基盤。Next.js/React Emailと相性◎） | |
| CDN・WAF | **標準装備**（Edge Network / Vercel Firewall） | 前段にCloudflareを重ねる構成も可 |
| ログ・監視 | **Vercel Observability / Analytics** | エラー追跡はSentry（共通基盤） |
| AI | **AI SDK / AI Gateway** | AIチャット等のストリーミングUIの定番 |
| IaC | **不要**（vercel.json + ダッシュボード） | 環境変数・ドメインもダッシュボード/CLIで完結 |
| CI/CD | **Git連携が標準**（push→ビルド→プレビューURL） | GitHub Actionsは補助（テスト実行等）に使う |
| プレビュー環境 | **Preview Deployments（標準）** | PRごとに実環境URL。この枠を選ぶ最大の理由のひとつ |

## 通信方式の対応

| 方式 | 実現手段 | 注意 |
|------|---------|------|
| REST / tRPC | FWのAPIルート（Functions） | tRPC + Next.jsは定番の組み合わせ |
| GraphQL | Functions | 動くが、重いリゾルバは実行時間に注意 |
| WebSocket | **✕（Functionsでは受けられない）** | リアルタイムは (1) Supabase Realtime / Ably / Pusher / PartyKit を併用 (2) WSだけFly.io等の常駐サービスに切り出す |
| SSE | **○**（Functionsのストリーミング） | AI応答ストリーミングはこれで足りることが多い。WSが本当に要るか先に確認 |
| gRPC | ✕ | gRPCが要る構成はこの枠ではない |
| Webhook受信 | APIルート | |
| 非同期メッセージング | Vercel Queues / Workflow | 本格的なPub/SubはUpstash QStash等を併用 |

## 参考構成

### 標準（フルスタックFW一体型）
```
[Vercel (Next.js: UI + APIルート)]
   ↓
[Neon PostgreSQL] [Upstash Redis] [Vercel Blob]
   ↓
[Vercel Cron / Workflow]（定期・非同期処理）
```

### リアルタイム併用
```
[Vercel (Next.js)] ── CRUD ──→ [Neon PostgreSQL]
        ↓
[Supabase Realtime / Ably]（WebSocketだけ外部サービス）
```

### 重いバックエンド併設（ハイブリッド）
```
[Vercel (Next.js: UI + BFF)] → [Fly.io / Cloud Run (重いAPI・常駐WS・gRPC)]
                                   ↓
                              [PostgreSQL]
```

## コスト感

- Hobby（無料）で個人プロジェクトは十分始められる。商用はPro **$20/月〜** + 使用量
- 転送量・画像最適化・Functions実行が従量で伸びるので、配信量の多いメディア系はR2/Cloudflare併用や他枠との比較を
- Neon / Upstash はスケールto0の無料枠あり。固定費ほぼゼロで本番構成が組める

## 強み・弱み

- **選ぶ理由**: フルスタックFWのデプロイ体験が最短（push→プレビュー→本番）、インフラ知識がほぼ不要、AI系ストリーミングUIとの相性
- **選ばない理由**: WebSocket・gRPC・常駐ワーカーが受けられない（外部併用が前提になる）。バックエンドが重いアプリは最初からFly.io / Cloud Runの方が構成がシンプル。ベンダー固有機能（ISR等）への依存はADRに残す
