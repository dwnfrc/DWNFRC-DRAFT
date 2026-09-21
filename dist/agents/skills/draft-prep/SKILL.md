---
name: draft-prep
description: DRAFTフレームワークのPhase 4「実装準備」。Phase 2〜3の設計ドキュメントを元に、Claude Codeが自動読み込みするCLAUDE.mdと、実装をステップ分割したプロンプト集（docs/claude-code-prompts.md）を生成する。「実装準備をしたい」「CLAUDE.mdを作って」「実装プロンプトを作って」「そろそろ実装に入りたい」というときに使う。
---

# DRAFT Phase 4: 実装準備

## 目的

Phase 5（実装）で実装エージェントに渡す2つのファイルを作る:

1. **CLAUDE.md**（リポジトリルート）: AIエージェントが毎チャット自動で読むプロジェクトコンテキスト（Claude Code は `CLAUDE.md`、Codex は `AGENTS.md` リンク経由で同じ実体を読む）
2. **docs/claude-code-prompts.md**: 1ステップずつ実行するステップ別プロンプト集

あわせて執行の検出点を配置する: **scripts/doc-lint.sh**（決定論的整合の検査）と **.githooks/pre-commit**（コミット前の機械検出）。機械で判定できる違反は宣言ではなく検出点で捕まえる（README原典の執行原則）。

「前提知識（CLAUDE.md）」と「作業指示（prompts.md）」を分離するのがこのフェーズの核心。混ぜてはいけない。

この2ファイルは**派生層**にあたる: ソース層（design-spec、PRD、System Design Doc、dev-setup）から再生成可能で、ソースと食い違ったらソースが正。古くなったらこのスキルを再実行して作り直せばよい。

## 前提（入力）

以下のPhase 2〜3の成果物を `docs/` からReadする:

- 設計仕様書（`docs/design-spec.md` など。画面仕様・デザインシステム）
- `docs/01_prd.md`
- `docs/02-01_system-design-doc.md`（アーキテクチャ、ADR、API設計、DBスキーマ）
- `docs/03_dev-setup.md`（リポジトリ構成、コマンド、ブランチ戦略）
- `docs/04_deployment-procedure.md` / `docs/05_operation-runbook.md` / `docs/06_design-tokens.json`（あれば）

**成果物が見つからない場合はこのフェーズを実行しない。** フェーズを飛ばすと品質が落ちる:

- 設計仕様書がない → `draft-design-spec`（Phase 2）を案内する
- 開発ドキュメント（PRD / System Design Doc）がない → `draft-playbook`（Phase 3）を案内する
- System Design Docに技術スタックの確定（ADR）がない → `draft-playbook` に戻って技術選定を確定させるよう案内する。技術スタックが未確定のままCLAUDE.mdを書いてはいけない

## 進め方

### 1. docsを読み込み、材料を抽出する

上記のdocs一式をReadし、以下を整理する:

- 確定した技術スタック（フレームワーク、ORM、DB、認証、ホスティング、IaC、CI/CD、モノレポツール）
- ディレクトリ構成と開発コマンド（`docs/03_dev-setup.md` から）
- 実装時に毎回意識すべき設計方針3〜5個（ADRやUI設計原則から抽出）
- 画面一覧（コア画面とそれ以外の区別）、APIエンドポイント一覧、テーブル一覧

不明点（例: コマンド体系が未記載、コア画面がどれか判断できない）があれば、AskUserQuestionツールで選択式で確認する。ただし質問は最小限にし、docsから読み取れることは聞かない。

### 2. CLAUDE.md を生成する

このスキルのディレクトリにある `CLAUDE.template.md` をReadし、その構成（プロジェクト名 / Tech Stack / Structure / Key Design Decisions / Commands / Docs / Implementation Rules / Code Style）に従ってプロジェクトの実内容で埋める。

**書くこと / 書かないことを厳守する:**

| 書く | 書かない |
|------|---------|
| 確定した技術スタック | ステップ別の作業指示 |
| ディレクトリ構成 | 変わりやすい情報（TODO、進捗） |
| 重要な設計方針（3〜5個） | 冗長な説明 |
| 開発コマンド一覧 | Phase 2〜3の内容の複製 |
| docsへのファイルパス | |
| コーディング規約 | |
| 実装の規律（先送りの禁止・設計の不備を実装で回避しない・場当たり修正の禁止・コメントの規律など） | |

CLAUDE.mdは毎チャット読まれる前提知識。詳細はdocsへのパス参照に留め、本体は短く保つ。テンプレートのプレースホルダ（`{...}`）を残さないこと。プロジェクトに該当しない項目（例: IaC不使用、モノレポでない）はテンプレートに合わせて無理に埋めず、実態に合わせて削除・修正する。

Commandsは標準makeターゲット（`make dev` 等）で書く。実コマンドの真実源はMakefileであり、CLAUDE.mdに生コマンド（pnpm等）を複製しない（プロジェクトで使わないターゲットは削る）。

生成の最後に、末尾のスタンプへ生成時のDRAFT版数を記録する（このプラグインの `../../.claude-plugin/plugin.json` の version。取得できない環境では日付 `<!-- DRAFT: generated YYYY-MM-DD -->` で代替する）。方法論は生成後も進化するため、draft-guide がこのスタンプとの差からバックフィルを提案する。

**配置先はリポジトリルートの `CLAUDE.md`。** 既存のCLAUDE.mdがある場合は、上書きする前に必ずユーザーへ確認する（AskUserQuestionで「上書き / 既存内容とマージ / 中止」を提示する）。

### 3. docs/claude-code-prompts.md を生成する

このスキルのディレクトリにある `claude-code-prompts.template.md` をReadし、その骨子（Step 1〜9）に従ってプロジェクトの実内容で埋める。

**ステッププロンプトの設計原則:**

| 原則 | 理由 |
|------|------|
| 1ステップ = 1チャット | コンテキスト劣化（自動要約による詳細の損失・注意の希釈）の防止 |
| ゴールを「動作確認可能な状態」で定義 | AIエージェントが完了判断できる |
| 参照すべきdocsファイルを明示 | 必要な情報だけ読ませる |
| 「まだやらないこと」を明示 | スコープクリープ防止 |
| 依存関係順に並べる | 前のステップの成果物が次の前提になる |

**推奨ステップ構成（Webアプリの場合）:**

| Step | 内容 | 粒度の目安 |
|------|------|-----------|
| 1 | モノレポ骨格 + 開発環境 | フレームワーク初期化、Docker、.env、Makefile |
| 2 | DBスキーマ + シード | テーブル定義、デモデータ |
| 3 | バックエンドAPI（CRUD） | 全エンドポイント、バリデーション |
| 4 | 認証 | OAuth、ガード、protected routes |
| 5 | 共通UIコンポーネント | レイアウト、デザインシステム |
| 6 | コア画面 | 最も重要な画面 |
| 7 | 残り画面 | 2nd priority の画面群 |
| 8 | インフラ + CI/CD | Terraform、GitHub Actions、Dockerfile |
| 9 | テスト + 仕上げ | Unit、E2E、Lint、KPI計測の導入 |

依存関係順（骨格 → DB → API → 認証 → UI → インフラ → テスト）を崩さない。プロジェクトの構成に応じてステップは調整してよい（例: IaC不使用ならStep 8を縮小）が、順序の原則は維持する。

テンプレートのプレースホルダは全て実内容で埋める:

- Step 3のエンドポイント列挙は `docs/02-01_system-design-doc.md` のAPI設計から実際のリソース・エンドポイント名を書き出す
- Step 5のレイアウトパターン、Step 6のコア画面、Step 7の残り画面は設計仕様書の画面一覧・コア画面詳細仕様から具体名で列挙する
- 各ステップのゴールは「`make dev` で両サーバーが起動する」「curlで各エンドポイントが200を返す」のように、コマンドや操作で確認できる形で書く（コマンドは標準makeターゲットで書く）

各Stepの見出し直下に `Status:` 行を含める（テンプレート準拠。進捗の記録先で、draft-implement が完了時に `done YYYY-MM-DD` か `blocked YYYY-MM-DD` を記す。未着手は空欄）。この3値は無人ループの停止判定にも使われるので、値域を勝手に増やさない。

**再実行（既存の `docs/claude-code-prompts.md` がある）時は、上書きの前に旧ファイルから状態を移送する。** 派生層は捨てて作り直してよいが、進捗という状態はソースに無いため、移送せずに消すと戻らない（README原典の派生層ルール）。移送するもの:

- 各Stepの `Status:` 行。旧形式（チェックボックス `[x]`・`<!-- DONE: ... -->` コメント等、`Status:` 行導入前の完了マーク）しか無い場合は、対応するStepの `Status: done YYYY-MM-DD` に読み替える（日付が読めなければ `done` のみ）
- スコープ分割などで追記されたステップ: 本文ごと、新版の依存関係上の正しい位置へ移す（末尾で番号を振り直してよい）
- ブロッカー注記（「閉じられない理由」の明示。Step本文や `Status:` 行の後ろに書かれている）: 該当Stepの `Status:` 行の直後に1行で残す。`Status: blocked` と対で意味を持つので、片方だけを移送しない

移送を終えてから新版で置き換え、消えた状態が無いことを新旧の突き合わせで確認する。

**配置先は `docs/claude-code-prompts.md`。** Phase 5で `draft-implement` がこのファイルを読んで順に実行する。

### 4. 実行の検出点（doc-lintとpre-commitフック）を配置する

1. このスキルのディレクトリにある `doc-lint.template.sh` を `scripts/doc-lint.sh` としてコピーし、実行権限を付ける（`chmod +x scripts/doc-lint.sh`）
2. `.githooks/pre-commit` を作成し実行権限を付ける。内容は2行:

   ```sh
   #!/usr/bin/env sh
   exec scripts/doc-lint.sh --staged
   ```

3. gitリポジトリなら `git config core.hooksPath .githooks` を実行する（未初期化なら prompts.md の Step 1 が `git init` と配線を行う）
4. prompts.md の Step 1 に、Makefileの `doc-lint` ターゲット（`scripts/doc-lint.sh --docs` を呼ぶ）と、`make setup` への `git config core.hooksPath .githooks` の組み込みが含まれていることを確認する
5. `ln -s CLAUDE.md AGENTS.md` で `AGENTS.md` リンクを作る（既に実体の AGENTS.md がある場合は上書きせずユーザーに確認する）。AGENTS.md を読む他のエージェント（Codex・Cursor等）からも同じ前提知識が見えるようになる。実体は増やさない。前提知識の正は CLAUDE.md 1つ

検出点の役割分担: `--staged`（pre-commit）は先送りマーカー・ゴミ・`.gitkeep`・機械判定できるシークレット（`.env` のステージ、既知形式のトークン）・文体（本文のem dash、表1列目の太字、48字を超える太字）の混入をコミット前に検出し、`--docs`（`make doc-lint`）はドキュメントと実体の乖離（存在しないmakeターゲットの参照・リンク切れ・FDD命名）を検出する。生コマンドの複製のような「言及か転記か」の文脈判断が要るものは機械化せず、レビューと draft-guide の鮮度診断が担う。検出は機械、扱いの判断は先送りの原則とユーザー（意図して通すときは `git commit --no-verify`）。

### 5. ユーザーにレビューを促す

生成した2ファイルの要点（技術スタック、ステップ数と各ステップの内容）を簡潔に提示し、認識ズレがないか確認してもらう。特に「コア画面の選定」と「ステップ分割の粒度」はユーザーの意図と合っているかを確認する。

## 成果物

| ファイル | 配置場所 | 用途 |
|----------|----------|------|
| `CLAUDE.md` | リポジトリルート | AIエージェントが自動読み込みする前提知識 |
| `docs/claude-code-prompts.md` | docs/ | ステップ別プロンプト集（Phase 5の入力） |
| `scripts/doc-lint.sh` + `.githooks/pre-commit` | リポジトリ | 決定論的整合の検出点（実行権限付き） |
| `AGENTS.md` | リポジトリルート | `CLAUDE.md` へのシンボリックリンク（Codex等への可搬性） |

後工程に渡すのは常にファイル。口頭の合意で済ませず、CLAUDE.md と claude-code-prompts.md に書き出す。

## 次のフェーズ

実装準備が完了したら、Phase 5（実装）へ進む。新しいセッションを開始し `draft-implement` を実行するよう案内する（CLAUDE.mdを新しいセッションで自動読み込みさせるため。ユーザーが同一セッションで続けたい場合はそれに従う）。

## 注意

- **Step 1〜2は1チャットにまとめてもOK。** 骨格 + スキーマは依存が近い。prompts.mdのチャット分割の目安にそう明記する
- **UI実装ステップが最も重い。** コア画面と残り画面は必ず別ステップに分ける
- **インフラは後回しで良い。** ローカルで動くものを先に作る構成にする
- **CLAUDE.mdにステップ別指示を書かない。** 毎回読まれるので情報過多になる。CLAUDE.md = 前提知識、claude-code-prompts.md = 指示、という分担を崩さない
- **技術スタックをこのフェーズ以降で変えない。** 変えるとドキュメント全体の書き直しになる。未確定ならPhase 3（draft-playbook）に戻す
- **全ステップを1チャットで実行させる構成にしない。** コンテキストの肥大で品質が落ちる。1ステップ = 1チャットの粒度で書く
- **各ステップのゴールに動作確認を含める。** 動作確認せずに次へ進むとエラーが積み上がって修正困難になる
