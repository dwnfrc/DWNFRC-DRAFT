# draft — DRAFT開発フレームワーク プラグイン

[DRAFT](../README.md)（Document-driven, Reproducible, AI-powered, Full-stack Toolkit）の開発方式を、Claude Codeのスキルとして実行できるようにしたプラグイン。

このプラグインは、DRAFTの全フェーズをClaude Code内で完結させる実装。「後工程に渡すのは常にファイル」「フェーズを飛ばさない」「1ステップ=1チャット」の原則はそのまま維持している。

## スキル一覧

| スキル | フェーズ | やること | 主な成果物 |
|--------|---------|---------|-----------|
| `/draft:guide` | — | 全体像の説明と現在フェーズの診断、次のスキルの案内 | なし |
| `/draft:concept` | Phase 0 | 対話でコンセプトを言語化 | `docs/concept.md` |
| `/draft:brainstorm` | Phase 1 | 壁打ち（スコープ・画面・ロール・フローを選択式で具体化） | `docs/brainstorm-notes.md` |
| `/draft:design-spec` | Phase 2 | 設計仕様書の作成(UIの見た目はモックで合意) | `docs/design-spec.md`, `docs/screen_flow.mermaid`, `docs/mocks/`(UIのみ) |
| `/draft:playbook` | Phase 3 | 技術スタック確定 + 開発ドキュメント7点セット生成 | `docs/01_prd.md` 〜 `docs/06_design-tokens.json`, `docs/README.md`, `.github/PULL_REQUEST_TEMPLATE.md` |
| `/draft:prep` | Phase 4 | 実装準備（コンテキスト + ステップ別プロンプト + 検出点） | `CLAUDE.md`, `docs/claude-code-prompts.md`, `scripts/doc-lint.sh` |
| `/draft:implement` | Phase 5 | プロンプト集から1ステップ実装 + 動作確認(全ステップを人の確認を挟まずに消化する無人ループも持つ) | 実装コード |
| `/draft:feature` | イテレーション | 変更の設計(FDD要否判定→規模判定→壁打ち→Feature Design Doc作成) | `docs/features/YYYYMMDD-HHMM_{機能名}.md` |
| `/draft:feature-implement` | イテレーション | FDDから実装(プロンプト生成→実装→ドキュメント更新→コミット。未実装のFDDを人の確認を挟まずに消化する無人ループも持つ) | 実装コード + 更新されたdocs |
| `/draft:adopt` | 導入 | 既存プロジェクト(DRAFT外製)にソース層を逆生成して導入(調査→ヒアリング→現状版ドラフト→検証→検出点配置) | `docs/` ソース層4点 + `CLAUDE.md` + `scripts/doc-lint.sh` |
| `/draft:branch` | 補助 | 作業開始前に、戦略と変更規模から「main継続かブランチ作成か」を決めて準備 | 作業場所の決定(必要ならブランチ) |
| `/draft:commit` | 補助 | リポジトリの流儀に合ったメッセージ・粒度でコミット | コミット |
| `/draft:equip-extensions` | 補助 | 拡張機能で補いたい作業を推奨をつけて聞き、コーディングエージェントの拡張機能(スキル・プラグイン・MCPサーバーなど)を、その時点の候補から選んで入れる(Phase 2でモックを描く前・Phase 3の技術選定の直後・変更サイクルの壁打ち) | 入れた拡張機能、ADRと `docs/03_dev-setup.md` の記録(変更サイクルではFDDへの記載) |
| `/draft:inspect-extensions` | 補助 | コーディングエージェントの拡張機能のうち、記録したものと設定に入っているものを、記録と実際・中身の変化・ADRとの食い違い・使う環境の4点で点検 | 点検結果の報告 |

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

### Codex / Cursor で使う(Agent Skills)

Codex・Cursor など Agent Skills 対応クライアントは、Claude Code と同じ `SKILL.md` 形式を `.agents/skills/`(リポジトリ単位)と `~/.agents/skills/`(ユーザー単位)から読み込む。これらに向けて、`draft-plugin/skills/` を正とする**生成した派生**を [`dist/agents/skills/`](../dist/agents/skills/) に用意してある(プラグイン名前空間 `/draft:concept` をフラットな `draft-concept` に変換済み)。

導入はこのリポジトリのインストーラで行う:

```bash
# 全プロジェクト共通(ユーザー単位) — ~/.agents/skills/ に入れる
ruby /path/to/DRAFT/scripts/install-agent-skills.rb

# プロジェクト単位 — そのリポジトリの .agents/skills/ に入れる
ruby /path/to/DRAFT/scripts/install-agent-skills.rb --project /path/to/your-project

# コピーではなくシンボリックリンクで入れる(DRAFT側の更新が即反映される)
ruby /path/to/DRAFT/scripts/install-agent-skills.rb --link

# 取り除く
ruby /path/to/DRAFT/scripts/install-agent-skills.rb --uninstall
```

`--dry-run` で行う操作だけを確認できる。`--dest PATH` を使えば `~/.cursor/skills/` のような別の探索先にも入れられる。インストーラは導入前に派生が最新かを確認し、古ければ再生成してから入れる。

呼び出しの記号はクライアントごとに違う: Codex は `$draft-guide`、Cursor は `/draft-guide`。内容に応じた自動起動もある。迷ったら `draft-guide` から。

#### Codexのセッション内から入れる

リポジトリを手元に置かずに入れるなら、Codexに最初から入っている `skill-installer` にGitHubのURLを渡す:

```
$skill-installer install https://github.com/dwnfrc/DWNFRC-DRAFT/tree/main/dist/agents/skills/draft-guide
```

まとめて入れたいときは「dwnfrc/DWNFRC-DRAFT の `dist/agents/skills/` 配下のスキルを全部入れて」と頼めばよい(installerは複数パスを1回で処理する)。

この経路には制約が2つある。入れ先が `~/.codex/skills/` で `.agents/skills/` ではないため**Codex専用**になる(Cursor等とは共有されない)。それと**同名のスキルが既にあると中断する**ので、更新するときは先に消すか、上のインストーラを `--link` で使う。

派生は正から再生成できる。スキルを更新したら `ruby scripts/build-agent-skills.rb` で作り直す(`--check` で最新かを検証、`validate.rb` にも組み込み済み)。

## 構成

```
draft-plugin/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    ├── adopt/SKILL.md + CLAUDE.template.md + doc-lint.template.sh
    ├── guide/SKILL.md
    ├── concept/SKILL.md + concept.template.md
    ├── brainstorm/SKILL.md
    ├── design-spec/SKILL.md + design-spec.template.md + screen_flow.template.mermaid
    ├── playbook/SKILL.md + templates/（7点） + references/（tech-stacks: architecture + プロバイダ別6枚）
    ├── prep/SKILL.md + CLAUDE.template.md + claude-code-prompts.template.md
    ├── implement/SKILL.md + run-loop.sh（無人ループの駆動スクリプト）
    ├── feature/SKILL.md + feature-design-doc.template.md
    ├── feature-implement/SKILL.md
    ├── branch/SKILL.md
    ├── commit/SKILL.md
    ├── equip-extensions/SKILL.md
    └── inspect-extensions/SKILL.md
```

テンプレートの原本は [`../templates/`](../templates/) にあり、各スキルフォルダには実行時に参照するコピーを同梱している。方法論の原典は [`../README.md`](../README.md)。

Agent Skills対応クライアント(Codex・Cursor等)向けの配布物 [`../dist/agents/skills/`](../dist/agents/skills/) は `skills/` から `scripts/build-agent-skills.rb` で生成する派生。手で編集せず、正(`skills/`)を直して再生成する。導入は `scripts/install-agent-skills.rb`。
