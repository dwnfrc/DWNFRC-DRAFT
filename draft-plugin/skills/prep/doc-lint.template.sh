#!/usr/bin/env bash
# doc-lint: 機械で判定できる違反の検出点(DRAFT)
#
# 検出は機械が行い、扱いは人が決める:
# - 自分の変更が作った先送りマーカーは、その場で閉じる(先送りの原則)
# - 意図して通す場合は git commit --no-verify (品質基準を下げる判断はユーザーのもの)
#
# 使い方:
#   scripts/doc-lint.sh --staged   # コミット前検査(.githooks/pre-commit が呼ぶ)
#   scripts/doc-lint.sh --docs     # ドキュメントと実体の整合検査(make doc-lint)
set -u

fail=0
finding() { printf 'doc-lint: %s\n' "$1"; fail=1; }

added_lines() {
  # ステージ済みdiffの追加行(+++ ヘッダを除く)。引数はpathspec
  git diff --cached --unified=0 --no-color -- "$@" | grep -E '^\+' | grep -v '^+++ '
}

staged_checks() {
  # 検査自体が実行できないときは合格にしない(フェイルクローズ)
  if ! git diff --cached --name-only >/dev/null 2>&1; then
    finding 'git diff --cached が失敗した(gitリポジトリでない等)。検査を実行できないため通さない'
    return
  fi

  # 1. 追加行の先送りマーカー
  #    規律文がマーカー名に言及するファイル(CLAUDE.md・prompts.md・このスクリプト)だけを除外する。
  #    PRD/FDD等のドキュメントに残った未記入のTODOは検出対象
  hits=$(added_lines . ':(exclude)CLAUDE.md' ':(exclude)docs/claude-code-prompts.md' ':(exclude)docs/_adopt-survey.md' ':(exclude)scripts/doc-lint.sh' \
    | grep -E 'TODO|FIXME|HACK|XXX' || true)
  if [ -n "$hits" ]; then
    finding '追加行に先送りマーカー(TODO/FIXME/HACK/XXX)がある:'
    printf '%s\n' "$hits" | head -20
  fi

  # 2. 実ファイルのあるディレクトリへの .gitkeep
  while IFS= read -r -d '' k; do
    case "$k" in
      *.gitkeep)
        d=$(dirname "$k")
        if [ "$(git ls-files "$d" | grep -cv '\.gitkeep$')" -gt 0 ]; then
          finding "実ファイルのあるディレクトリの .gitkeep: $k"
        fi
        ;;
    esac
  done < <(git diff --cached --name-only --diff-filter=A -z)

  # 3. ゴミファイル
  g=$(git diff --cached --name-only | grep -E '(^|/)(\.DS_Store|Thumbs\.db)$' || true)
  [ -n "$g" ] && finding "ゴミファイルがステージされている: $g"

  # 4. シークレット(決定論的に判定できるものだけ。網羅はコミット時のレビューが担う)
  e=$(git diff --cached --name-only | grep -E '(^|/)\.env(\.|$)' | grep -v '\.env\.example$' || true)
  [ -n "$e" ] && finding ".env がステージされている: $e"
  sec=$(added_lines . \
    | grep -E 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}' || true)
  if [ -n "$sec" ]; then
    finding '追加行にシークレットらしきトークン:'
    printf '%s\n' "$sec" | head -5
  fi

  # 5. 文体(README原典「テクニカルドキュメントとして書く」の決定論的な部分)
  #    対句・誇張・翻訳調のような文脈判断はレビューが担う。ここは機械で判定できるものだけ。
  #    インラインコードは「言及」であって「使用」ではないので落とす。
  md=$(added_lines '*.md' | sed 's/^+//; s/`[^`]*`//g')

  # 5-1. 本文中のem dash。「ラベル: 説明」の形に書く。
  #      見出しでタイトルとサブタイトルを分けるダッシュと、表の「該当なし」を示す単独のダッシュは別の用法なので除く。
  em=$(printf '%s\n' "$md" | grep -v '^[[:space:]]*#' \
    | sed 's/|[[:space:]]*—[[:space:]]*|/| |/g' | grep -- '—' || true)
  if [ -n "$em" ]; then
    finding '追加行の本文にem dashがある。読点・括弧・文の分割か「ラベル: 説明」に置き換える:'
    printf '%s\n' "$em" | head -10
  fi

  # 5-2. 表の1列目の太字。列の位置がすでにラベルを示しており、太字は何も指していない。
  #      2列目以降の太字は、並んだ選択肢から採用するものを指すなど意味を運ぶことがあるので見ない。
  tb=$(printf '%s\n' "$md" | grep -E '^[[:space:]]*\|[^|]*\*\*' || true)
  if [ -n "$tb" ]; then
    finding '追加行に、表の1列目を太字にした箇所がある。列の位置がラベルを示すので太字は要らない:'
    printf '%s\n' "$tb" | head -10
  fi

  # 5-3. 文を丸ごと覆う太字。太字は段落の頭に置く短いラベルとUI要素にだけ使う。
  #      文字数で数えるため、UTF-8ロケールでないときは検査しない(バイト数で誤検出するため)。
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]*)
      # 短い太字を先に落としてから残りを見る。左から順に対にするため、
      # 隣り合う太字の「あいだ」にある地の文を太字と読み違えない。
      bl=$(printf '%s\n' "$md" | while IFS= read -r l; do
        printf '%s\n' "$l" | sed -E 's/\*\*[^*]{1,48}\*\*//g' \
          | grep -qE '\*\*[^*]+\*\*' && printf '%s\n' "$l"
      done)
      if [ -n "$bl" ]; then
        finding '追加行に、48字を超える太字がある。太字は段落の頭の短いラベルとUI要素にだけ使う:'
        printf '%s\n' "$bl" | head -10
      fi
      ;;
  esac
}

docs_checks() {
  # 1. CLAUDE.md / docs/ がコードスパンで参照する `make <target>` が Makefile に実在するか
  #    (バッククォート付きの参照だけを対象にする。地の文の "make sure" 等を拾わないため)
  if [ -f Makefile ]; then
    for t in $(grep -rhoE '`make [a-z][a-z0-9-]*' CLAUDE.md docs/*.md 2>/dev/null | sed 's/^`make //' | sort -u); do
      grep -qE "^$t[[:space:]]*:" Makefile \
        || grep -qE "^[a-z][a-z0-9 -]*[[:space:]]$t([[:space:]][a-z0-9 -]*)?:" Makefile \
        || grep -qE "^\.PHONY:( .*)? $t( |$)" Makefile \
        || finding "docsが参照する make $t がMakefileに無い"
    done
  elif grep -rqE '`make [a-z]' CLAUDE.md docs/*.md 2>/dev/null; then
    finding 'docsがmakeターゲットを参照しているがMakefileが無い'
  fi

  # 2. docs/README.md のリンク先が実在するか(アンカーは切り離して判定)
  if [ -f docs/README.md ]; then
    for p in $(grep -oE '\]\([A-Za-z0-9_./-]+\.(md|mermaid)(#[A-Za-z0-9_-]+)?\)' docs/README.md | sed -E 's/^\]\(//; s/\)$//; s/#.*$//'); do
      [ -f "docs/$p" ] || [ -f "$p" ] || finding "docs/README.md のリンク切れ: $p"
    done
  fi

  # 3. docs/features/ の命名規則(YYYYMMDD-HHMM_名前.md)
  for f in docs/features/*.md; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    [ "$b" = "README.md" ] && continue
    echo "$b" | grep -qE '^[0-9]{8}-[0-9]{4}_.+\.md$' || finding "FDD命名規則違反: $f"
  done
}

case "${1:-}" in
  --staged) staged_checks ;;
  --docs)   docs_checks ;;
  *) echo "usage: $0 --staged|--docs" >&2; exit 2 ;;
esac

if [ "$fail" -ne 0 ]; then
  echo 'doc-lint: 検出あり。自分の変更が作ったものは閉じてからコミットする。意図して通す場合: git commit --no-verify' >&2
fi
exit "$fail"
