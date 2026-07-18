# draft — DRAFT開発フレームワーク プラグイン

[DRAFT](../README.md)（Document-driven, Reproducible, AI-powered, Full-stack Toolkit）の開発方式を、Claude Codeのスキルとして実行できるようにしたプラグイン。

元の方法論はPhase 1〜4をClaude.ai、Phase 5をClaude Codeで行う前提だが、このプラグインでは全フェーズをClaude Code内で完結できる。「後工程に渡すのは常にファイル」「フェーズを飛ばさない」「1ステップ=1チャット」の原則はそのまま維持している。

## スキル一覧

| スキル | フェーズ | やること | 主な成果物 |
|--------|---------|---------|-----------|
| `/draft:guide` | — | 全体像の説明と現在フェーズの診断、次のスキルの案内 | なし |
| `/draft:concept` | Phase 0 | 対話でコンセプトを言語化 | `docs/concept.md` |
| `/draft:brainstorm` | Phase 1 | 壁打ち（スコープ・画面・ロール・フローを選択式で具体化） | `docs/brainstorm-notes.md` |
| `/draft:design-spec` | Phase 2 | 設計仕様書の作成 | `docs/design-spec.md`, `docs/screen_flow.mermaid` |
| `/draft:playbook` | Phase 3 | 技術スタック確定 + 開発ドキュメント6点セット生成 | `docs/01_prd.md` 〜 `docs/05_operation-runbook.md`, `docs/README.md`, `.github/PULL_REQUEST_TEMPLATE.md` |
| `/draft:prep` | Phase 4 | 実装準備（コンテキスト + ステップ別プロンプト） | `CLAUDE.md`, `docs/claude-code-prompts.md` |
| `/draft:implement` | Phase 5 | プロンプト集から1ステップ実装 + 動作確認 | 実装コード |
| `/draft:feature` | イテレーション | 機能追加の設計(規模判定→壁打ち→Feature Design Doc作成) | `docs/features/YYYYMMDD-HHMM_{機能名}.md` |
| `/draft:feature-implement` | イテレーション | FDDから実装(プロンプト生成→実装→ドキュメント更新→コミット) | 実装コード + 更新されたdocs |
| `/draft:branch` | 補助 | 作業開始前に、戦略と変更規模から「main継続かブランチ作成か」を決めて準備 | 作業場所の決定(必要ならブランチ) |
| `/draft:commit` | 補助 | リポジトリの流儀に合ったメッセージ・粒度でコミット | コミット |

迷ったら `/draft:guide` から始める。ブランチ戦略は `docs/03_dev-setup.md` が真実の源で、未定義ならbranchスキルがヒアリングして追記する。

## インストール

### ローカルで試す（開発中）

```bash
claude --plugin-dir /path/to/DRAFT/draft-plugin
```

### マーケットプレイス経由

このリポジトリ自体がマーケットプレイス（ルートの `.claude-plugin/marketplace.json`）になっている。

```
/plugin marketplace add <path-or-github-owner/DRAFT>
/plugin install draft@draft-marketplace
```

インストール後は `/reload-plugins` または再起動で反映される。

## 構成

```
draft-plugin/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    ├── guide/SKILL.md
    ├── concept/SKILL.md + concept.template.md
    ├── brainstorm/SKILL.md
    ├── design-spec/SKILL.md + design-spec.template.md + screen_flow.template.mermaid
    ├── playbook/SKILL.md + templates/（6点） + references/（tech-stacks-aws/gcp）
    ├── prep/SKILL.md + CLAUDE.template.md + claude-code-prompts.template.md
    ├── implement/SKILL.md
    ├── feature/SKILL.md + feature-design-doc.template.md
    ├── branch/SKILL.md
    └── commit/SKILL.md
```

テンプレートの原本は [`../templates/`](../templates/) にあり、各スキルフォルダには実行時に参照するコピーを同梱している。方法論の原典は [`../README.md`](../README.md)。
