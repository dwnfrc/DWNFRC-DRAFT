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

<!-- Makefileが実コマンドの唯一の真実源。ここには標準ターゲット名だけを書き、生コマンド（pnpm等）を複製しない。 -->

- `make setup` — First-time setup (deps, .env, DB)
- `make dev` — Start development servers
- `make build` — Build all packages
- `make test` — Run all tests
- `make lint` — Run linter
- `make format` — Run formatter
- `make db-push` — Push schema to DB (dev)
- `make db-generate` — Generate migration SQL
- `make db-migrate` — Apply migrations
- `make db-seed` — Insert demo data
- `make db-studio` — Open DB GUI
- `make doc-lint` — Check docs↔reality drift (staged checks run via pre-commit hook)

## Docs

Detailed specifications are in `docs/`. This file and `docs/claude-code-prompts.md` are derived from `docs/` — if they disagree, `docs/` is the source of truth:

- docs/{設計仕様書ファイル名} — Product design, UX, layout system, data model
- docs/01_prd.md — User stories, KPI, scope
- docs/02-01_system-design-doc.md — Architecture, ADRs, API design, DB schema
- docs/02-02_feature-design-doc.md — Template for change-cycle FDDs
- docs/03_dev-setup.md — Monorepo structure, setup steps, branch strategy
- docs/04_deployment-procedure.md — Deploy, CI/CD, rollback
- docs/05_operation-runbook.md — Monitoring, incident response

## Implementation Rules

- **先送りしない。完了とは残作業がゼロの状態。** TODO/FIXMEコメント、固定値やモックを返す仮実装、握りつぶした例外、通していない経路、完了報告の「今後の課題」節は、すべて先送りの言い換えでしかない。禁止しているのは形ではなく先送りそのもの。残したくなったら設計に曖昧さがあるサインなので、実装を止めて確認し、設計ドキュメントに反映してから実装する
- **設計の不備を実装で回避しない。** 「設計ドキュメントの記述では要件が満たせない・記述同士が矛盾している・必要な決定が欠けている」と気づいたら、実装側の回避策で辻褄を合わせて進まない。手を止めて不備の内容・影響・直し方を提示し、合意の上で設計ドキュメントを直してから、直った設計を入力に実装を再開する
- **スコープを黙って縮めない。** 縮める判断はユーザーのもの。合意を取り、残りをドキュメントに書き出してから完了とする
- **合意を求めることを完了の代わりにしない。** 合意が要るのはユーザーのスコープを縮めるときだけ。自分の変更が作った穴・自分で見つけた欠陥は、「これも直しますか」と聞かずにその場で閉じる。それは縮小ではなく完了条件
- **残すときは、閉じられない理由を名指しする。** 「後で」ではなく何がブロックしているか（ユーザーの決定が要る／認証情報や外部リソースが無い／別の作業に依存する）を、先送りするその時点で述べる。理由を名指しできないなら閉じられるということなので閉じる
- **場当たり的な修正をしない。** エラーやバグは症状を抑えるパッチではなく、根本原因を特定し、原因と修正方針を提示してから直す。症状だけ抑えるパッチは原因の解決を後ろに送る先送りの一形態。設計に関わる修正はユーザーの合意を得てから行う
- **コメントはコードから読み取れないことだけを書く。** 処理の言い換え（`// ユーザーを取得する` の直後に `getUser()`）は書かない。書くのは「なぜこの実装なのか」「不変条件」「外部制約」「呼び出し側の契約」。密度と体裁は周囲の既存コードに合わせる
- **不要になった `.gitkeep` は削除する。** ディレクトリに実ファイルを追加したら、その中の `.gitkeep` を消す

## Code Style

- Conventional Commits: feat:, fix:, refactor:, docs:, chore:
- コミットメッセージの言語: {英語 / 日本語}
- コミットのトレーラーは付けない（`Co-Authored-By`、セッションURL等）。ツールや実行環境が既定で付けようとする場合も、この規約が優先する
- コミットのサブジェクトは50字を目安に、72字を超えない。本文は空行を挟んで表示幅72カラムで折り返す（全角は2カラム）
- **コミット本文はdiffから読み取れないことだけを書く。** 書くのは「なぜ変えたか」「採らなかった案」「どこまで検証したか」。変更ファイルの一覧やバージョン番号の更新は `git show --stat` の仕事。長さを既存の履歴に合わせない（直前のコミットを基準にすると単調に膨らむ）
- {Linter} + {Formatter}
- {コメント規約: 言語標準のdoc comment形式、プレフィックス（`NOTE:` 等）を使うかどうか。決めごとが無ければ既存コードの流儀に従う}
- {その他のコーディング規約}

<!-- DRAFT: v{生成時のプラグインバージョン} -->
