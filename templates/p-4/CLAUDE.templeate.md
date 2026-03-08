# {プロジェクト名}

{一行説明}

## Tech Stack

- Frontend: {フレームワーク / 言語 / UIライブラリ}
- Backend: {フレームワーク / 言語 / ORM}
- DB: {DBMS (ホスティング先)}
- Auth: {認証ライブラリ (プロバイダー)}
- Infra: {ホスティング先}
- IaC: {Terraform / なし}
- CI/CD: {GitHub Actions / etc.}
- Monorepo: {pnpm workspace / turborepo / npm workspace}

## Structure

- apps/web — Frontend
- apps/api — Backend API
- packages/db — DB schema + migrations
- packages/shared — Shared types/constants
- infra/ — Terraform (IaC使用時)

## Key Design Decisions

<!-- 3〜5個。実装時に毎回意識すべき設計方針。 -->

- {設計方針1}
- {設計方針2}
- {設計方針3}

## Commands

- `pnpm dev` — Start both frontend and backend
- `pnpm --filter web dev` — Frontend only
- `pnpm --filter api dev` — Backend only
- `pnpm db:push` — Push schema to DB (dev)
- `pnpm db:generate` — Generate migration SQL (prod)
- `pnpm db:migrate` — Apply migrations (prod)
- `pnpm db:seed` — Insert demo data
- `pnpm db:studio` — Open DB GUI
- `pnpm test` — Run all tests
- `pnpm lint` — Run linter
- `pnpm format` — Run formatter

## Docs

Detailed specifications are in `docs/`:

- docs/{設計仕様書ファイル名} — Product design, UX, layout system, data model
- docs/01_prd.md — User stories, KPI, scope
- docs/02-01_system-design-doc.md — Architecture, ADRs, API design, DB schema
- docs/02-02_feature-design-doc.md — Template for feature additions
- docs/03_dev-setup.md — Monorepo structure, setup steps, branch strategy
- docs/04_deployment-procedure.md — Deploy, CI/CD, rollback
- docs/05_operation-runbook.md — Monitoring, incident response

## Code Style

- Conventional Commits: feat:, fix:, docs:, chore:
- {Linter} + {Formatter}
- {その他のコーディング規約}
