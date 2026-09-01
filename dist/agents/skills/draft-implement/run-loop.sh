#!/usr/bin/env bash
#
# DRAFT Phase 5 — 無人ループ駆動スクリプト
#
# docs/claude-code-prompts.md の未着手ステップを、1ステップにつき1セッションで
# 消化しきる。各反復は `claude -p '/draft:implement loop'` を新しいセッションとして
# 起こすため、コンテキストはステップごとに完全にリセットされる。
#
# 使い方:
#   bash scripts/draft-loop.sh
#
# 環境変数:
#   DRAFT_LOOP_PROMPTS          プロンプト集のパス (既定: docs/claude-code-prompts.md)
#   DRAFT_LOOP_MAX_ITER         反復の上限 (既定: 30)
#   DRAFT_LOOP_PERMISSION_MODE  claude --permission-mode に渡す値 (既定: acceptEdits)
#   DRAFT_LOOP_SKIP_PREFLIGHT   1 で走行前の独立レビュー確認を飛ばす
#   DRAFT_LOOP_RAW              1 で進捗の整形をやめ、claude の生出力をそのまま流す
#
# 権限について: 無人実行なので、実装に必要なツールが問い合わせ無しで通る状態が要る。
# 既定の acceptEdits はファイル編集しか通さないため、多くのプロジェクトでは
# .claude/settings.json の許可リストを整えるか、内容を理解したうえで
# DRAFT_LOOP_PERMISSION_MODE=bypassPermissions を指定する必要がある。
# どこまで許すかはユーザーの判断であり、このスクリプトは既定を広げない。
#
# 終了コード:
#   0  全ステップが done
#   1  前提の不足 (プロンプト集が無い / claude が無い)
#   2  blocked で停止 (人の判断が要る)
#   3  同じステップが2回続けて Status を更新せずに終わった (クラッシュ等)
#   4  反復の上限に到達
#   5  独立レビュー(サブエージェント)を起動できない

set -uo pipefail

PROMPTS="${DRAFT_LOOP_PROMPTS:-docs/claude-code-prompts.md}"
MAX_ITER="${DRAFT_LOOP_MAX_ITER:-30}"
PERMISSION_MODE="${DRAFT_LOOP_PERMISSION_MODE:-acceptEdits}"

START_REF=""

log() { printf '\n\033[1m[draft-loop]\033[0m %s\n' "$*"; }

# 各ステップの見出しと Status 値を "見出し<TAB>値" で吐く。
steps() {
  awk '
    /^## Step/          { head = $0; seen = 0; next }
    head != "" && /^Status:/ && seen == 0 {
      v = $0
      sub(/^Status:[[:space:]]*/, "", v)
      print head "\t" v
      seen = 1
    }
  ' "$PROMPTS"
}

first_pending()  { steps | awk -F'\t' '$2 == "" { print $1; exit }'; }
first_blocked()  { steps | awk -F'\t' '$2 ~ /^blocked/ { print $1; exit }'; }

# 指定した見出しの Status 値を返す(1反復の結果を読むため)
status_of() { steps | awk -F'\t' -v h="$1" '$1 == h { print $2; exit }'; }

# 経過時間を mm:ss で
elapsed() { printf '%d:%02d' $(( SECONDS / 60 )) $(( SECONDS % 60 )); }

# 走行中に積まれたコミットを全文で出す。自律判断の記録はここにある。
audit() {
  [ -n "$START_REF" ] || return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  if [ "$(git rev-parse HEAD 2>/dev/null)" = "$START_REF" ]; then
    log "この走行でのコミットはありません。"
    return 0
  fi
  log "この走行で積まれたコミット（自律判断の記録はこの本文にあります。必ず読んでください）:"
  git --no-pager log --stat "${START_REF}..HEAD"
}

# claude の stream-json を、人が読める進捗行に変える。
# 既定の text 出力はステップが終わるまで何も出さないため、実装中は画面が止まって見える。
# stream-json はツール実行のたびにイベントが届くので、経過時間と「今なにをしているか」を出せる。
format_progress() {
  python3 -u -c '
import sys, json, os, time
start = time.time()
cwd = os.getcwd() + "/"
def el():
    s = int(time.time() - start)
    return "%d:%02d" % (s // 60, s % 60)
def one(text, limit=78):
    return " ".join(str(text).split())[:limit]
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except ValueError:
        continue
    if ev.get("type") != "assistant":
        continue
    for c in ev.get("message", {}).get("content", []):
        kind = c.get("type")
        if kind == "tool_use":
            inp = c.get("input") or {}
            detail = (inp.get("command") or inp.get("file_path") or inp.get("description")
                      or inp.get("pattern") or inp.get("prompt") or "")
            if isinstance(detail, str) and detail.startswith(cwd):
                detail = detail[len(cwd):]
            print("    %6s  %-9s %s" % (el(), c.get("name", "?"), one(detail)))
        elif kind == "text":
            t = one(c.get("text", ""))
            if t:
                print("    %6s  %s" % (el(), t))
'
}

# 1ステップを新しいセッションで実行する。claude の終了コードを返す。
run_step() {
  if [ "${DRAFT_LOOP_RAW:-0}" = "1" ] || ! command -v python3 >/dev/null 2>&1; then
    claude -p '/draft:implement loop' --permission-mode "$PERMISSION_MODE" < /dev/null
    return $?
  fi
  claude -p '/draft:implement loop' --permission-mode "$PERMISSION_MODE" \
      --output-format stream-json --verbose < /dev/null | format_progress
  return "${PIPESTATUS[0]}"
}

# 独立レビューは各ステップで必ず使う。起動できないまま走ると、1ステップを作り切ってから
# blocked になり、その作業が宙に浮く。走行前に一度だけ確かめて、駄目なら着手しない。
preflight_review() {
  if [ "${DRAFT_LOOP_SKIP_PREFLIGHT:-0}" = "1" ]; then
    log "事前確認をスキップしました (DRAFT_LOOP_SKIP_PREFLIGHT=1)"
    return 0
  fi

  log "事前確認: 独立レビュー(サブエージェント)を起動できるか"
  local prompt probe
  prompt='Agentツールでサブエージェントを1体だけ起動し、Bashで `git status --short` を実行させてください。'
  prompt+='起動して実行できたら READY の1語だけを、できなければ UNAVAILABLE の1語だけを出力してください。他には何も出力しないこと。'
  probe="$(claude -p "$prompt" --permission-mode "$PERMISSION_MODE" < /dev/null 2>&1)"

  case "$probe" in
    *READY*)
      log "独立レビューは起動できます。"
      ;;
    *)
      log "独立レビューを起動できません。無人ループは開始しません。"
      log "権限設定(.claude/settings.json の許可リスト、または DRAFT_LOOP_PERMISSION_MODE)を見直してください。"
      log "応答: ${probe}"
      exit 5
      ;;
  esac
}

command -v claude >/dev/null 2>&1 || { log "claude が PATH にありません。"; exit 1; }

if [ ! -f "$PROMPTS" ]; then
  log "$PROMPTS が見つかりません。Phase 4 (draft-prep) が未完了です。"
  exit 1
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  START_REF="$(git rev-parse HEAD 2>/dev/null || true)"
fi

trap audit EXIT

log "対象: $PROMPTS / 上限: ${MAX_ITER}反復 / 権限: ${PERMISSION_MODE}"

preflight_review

prev_target=""
repeat=0

for (( iter = 1; iter <= MAX_ITER; iter++ )); do
  blocked="$(first_blocked)"
  if [ -n "$blocked" ]; then
    log "保留で停止: ${blocked#\#\# }"
    log "理由は $PROMPTS の該当 Status: 行の直後にあります。人の判断を入れてから再実行してください。"
    exit 2
  fi

  target="$(first_pending)"
  if [ -z "$target" ]; then
    log "全ステップが done です。Phase 5 完了。"
    exit 0
  fi

  label="${target#\#\# }"

  if [ "$target" = "$prev_target" ]; then
    repeat=$(( repeat + 1 ))
  else
    repeat=1
    prev_target="$target"
  fi

  if [ "$repeat" -ge 3 ]; then
    log "停止: ${label} が2回続けて Status を更新せずに終わりました。"
    log "セッションのクラッシュかコンテキスト切れの可能性があります。手動で状況を確認してください。"
    exit 3
  fi

  if [ "$repeat" -eq 1 ]; then
    log "反復 ${iter}/${MAX_ITER}: ${label}"
  else
    log "反復 ${iter}/${MAX_ITER}: ${label} （再試行 $(( repeat - 1 ))回目）"
  fi

  SECONDS=0
  run_step
  rc=$?

  after="$(status_of "$target")"
  case "$after" in
    done*)    log "完了: ${label} ($(elapsed))" ;;
    blocked*) log "保留: ${label} ($(elapsed)) — 次の判定で停止します" ;;
    *)        log "未記録のまま終了: ${label} ($(elapsed), claude終了コード ${rc})" ;;
  esac
done

log "反復の上限 (${MAX_ITER}) に到達しました。残りを確認してから再実行してください。"
exit 4
