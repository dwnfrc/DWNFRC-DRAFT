#!/usr/bin/env bash
#
# DRAFT: 無人ループ駆動スクリプト
#
# 2つのモードがある。どちらも1つの作業単位につき1セッションを新しく起こすため、
# コンテキストは単位ごとに完全にリセットされる。
#
#   phase5     (既定) docs/claude-code-prompts.md の未着手ステップを消化する。
#                     各反復は `claude -p '/draft:implement loop'`。
#   iteration         docs/features/ の未実装FDDを古い順に消化する。
#                     各反復は `claude -p '/draft:feature-implement loop <FDDのパス>'`。
#                     パスを渡すのは、子セッションが自分を1反復と読み分けるため。
#                     未実装かどうかはgitから導く(FDDに状態欄は作らない)。
#                     各反復は始めたブランチへ戻って終わる前提で、戻っていなければ止める。
#
# 使い方:
#   bash scripts/draft-loop.sh                             # Phase 5
#   DRAFT_LOOP_MODE=iteration bash scripts/draft-loop.sh   # イテレーション
#
# 環境変数:
#   DRAFT_LOOP_MODE             phase5 | iteration (既定: phase5)
#   DRAFT_LOOP_PROMPTS          プロンプト集のパス (既定: docs/claude-code-prompts.md)
#   DRAFT_LOOP_FEATURES         FDDのディレクトリ (既定: docs/features)
#   DRAFT_LOOP_MAX_ITER         反復の上限 (既定: 30)
#   DRAFT_LOOP_PERMISSION_MODE  claude --permission-mode に渡す値 (既定: acceptEdits)
#   DRAFT_LOOP_SKIP_PREFLIGHT   1 で走行前の独立レビュー確認を飛ばす
#   DRAFT_LOOP_RAW              1 で進捗の整形をやめ、claude の生出力をそのまま流す
#
# 進捗を残さずに終わった反復のセッションログは消さずに残し、パスを走行ログに出す。
# 終わり方(自分で発話を終えたのか落ちたのか)は、そこを読まないと分からない。
#   DRAFT_LOOP_LIMIT_WAIT_CAP   利用上限での待機の累計上限・秒 (既定: 21600 = 6時間)
#   DRAFT_LOOP_LIMIT_WAIT       リセット時刻を読めなかったときの1回の待機・秒 (既定: 900)
#   DRAFT_LOOP_LIMIT_PATTERN    利用上限メッセージの検出パターン (grep -E。文言が変わったとき用)
#
# 権限について: 無人実行なので、実装に必要なツールが問い合わせ無しで通る状態が要る。
# 既定の acceptEdits はファイル編集しか通さないため、多くのプロジェクトでは
# .claude/settings.json の許可リストを整えるか、内容を理解したうえで
# DRAFT_LOOP_PERMISSION_MODE=bypassPermissions を指定する必要がある。
# どこまで許すかはユーザーの判断であり、このスクリプトは既定を広げない。
#
# 利用上限について: 上限に当たったセッションは、何もせずメッセージだけを出して終わる。
# これは停滞ではないので止めない。リセット時刻まで待って同じステップを再開し、
# その反復は停滞カウンタにも反復数にも数えない。ここで人を呼んでも、人にできるのは
# 待つことだけで、呼ばれるまでの時間がそのまま空転になる。待っても解消しない
# (累計の待機が上限に達した) ときだけ止める。
#
# 終了コード:
#   0  作業単位が尽きた (全ステップが done / 未実装FDDが無い)
#   1  前提の不足 (プロンプト集やFDDが無い / claude が無い / gitリポジトリでない)
#   2  保留で停止 (人の判断が要る)
#   3  同じ単位が2回続けて進捗を残さずに終わった (クラッシュ等)
#   4  反復の上限に到達
#   5  独立レビュー(サブエージェント)を起動できない
#   6  利用上限での待機が累計上限に達した

set -uo pipefail

MODE="${DRAFT_LOOP_MODE:-phase5}"
PROMPTS="${DRAFT_LOOP_PROMPTS:-docs/claude-code-prompts.md}"
FEATURES="${DRAFT_LOOP_FEATURES:-docs/features}"
MAX_ITER="${DRAFT_LOOP_MAX_ITER:-30}"
PERMISSION_MODE="${DRAFT_LOOP_PERMISSION_MODE:-acceptEdits}"
LIMIT_WAIT_CAP="${DRAFT_LOOP_LIMIT_WAIT_CAP:-21600}"
LIMIT_FALLBACK_WAIT="${DRAFT_LOOP_LIMIT_WAIT:-900}"
LIMIT_PATTERN="${DRAFT_LOOP_LIMIT_PATTERN:-limit reached|hit your [a-z0-9 -]*limit|limit will reset|limit[^a-zA-Z]*resets}"

START_REF=""
START_BRANCH=""
SESSION_LOG=""
KEEP_LOG=0
LIMIT_WAITED=0

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

# iteration用の作業リスト。docs/features/ のFDDを古い順に並べる(ファイル名が時系列)。
fdds() { ls -1 "$FEATURES"/*.md 2>/dev/null | grep -v '/README\.md$' | sort; }

# FDDが実装済みか(終了コード0で実装済み)。
# 実装済み = そのFDDに触れたコミットのうち、docs/features/ の外にも触れたものがある。
# サイクルのコミットは実装・ソースDoc更新・FDDを1つにまとめるので、この条件で判定できる。
# 状態はFDDではなくgitが持つ。
# grep の終了コードは実装や対話シェルで読み違えやすいので、出力そのもので判定する。
# git diff-tree に --root を付けない。付けるとrootコミットが全ファイルを足したものとして出る。
# FDDと実装コードが同じ初期コミットに入っているリポジトリでは、それが「実装済み」に見えて
# 未実装のFDDを黙って飛ばす。付けない場合の外れ方は「未実装のまま」であり、
# 実装が進めば必ず親を持つコミットが触れるので、安全な側に倒れる。
fdd_implemented() {
  local hits
  hits=$(git log --format=%H -- "$1" 2>/dev/null \
    | while read -r c; do git diff-tree --no-commit-id --name-only -r "$c" < /dev/null; done \
    | grep -v "^${FEATURES}/" | head -1)
  [ -n "$hits" ]
}

first_pending() {
  case "$MODE" in
    iteration) fdds | while read -r f; do
                 fdd_implemented "$f" || { printf '%s\n' "$f"; break; }
               done ;;
    *)         steps | awk -F'\t' '$2 == "" { print $1; exit }' ;;
  esac
}

# iteration には状態欄が無いので、保留は走行を始める前には現れない(走行中に検出する)。
first_blocked() {
  case "$MODE" in
    iteration) : ;;
    *)         steps | awk -F'\t' '$2 ~ /^blocked/ { print $1; exit }' ;;
  esac
}

# 1反復の結果を読む。phase5 は Status 値、iteration は実装済みなら done。
status_of() {
  case "$MODE" in
    iteration) fdd_implemented "$1" && printf 'done\n' ;;
    *)         steps | awk -F'\t' -v h="$1" '$1 == h { print $2; exit }' ;;
  esac
}

label_of() {
  case "$MODE" in
    iteration) basename "$1" ;;
    *)         printf '%s\n' "${1#\#\# }" ;;
  esac
}

# 子セッションに「自分が1反復である」ことと対象を渡す。パスが無いと、スキル側は
# セットアップ依頼と読み分けられず、何も実装せずに終わる。
session_prompt() {
  case "$MODE" in
    iteration) printf '/draft:feature-implement loop %s\n' "$1" ;;  # draft-keep-namespace
    *)         printf '/draft:implement loop\n' ;;                  # draft-keep-namespace
  esac
}

# 経過時間を mm:ss で
elapsed() { printf '%d:%02d' $(( SECONDS / 60 )) $(( SECONDS % 60 )); }

# 待機秒を読める長さで
duration() { if [ "$1" -lt 60 ]; then printf '%d秒' "$1"; else printf '%d分' $(( $1 / 60 )); fi; }

# 走行中に積まれたコミットを全文で出す。自律判断の記録はここにある。
# 走行開始時にコミットが1つも無かった場合(Phase 5の初回走行)は全履歴を出す。
# ここが黙ると、事前の承認を飛ばした分を事後に読む経路が消える。
audit() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 0

  local range
  if [ -n "$START_REF" ]; then
    if [ "$(git rev-parse HEAD 2>/dev/null)" = "$START_REF" ]; then
      log "この走行でのコミットはありません。"
      return 0
    fi
    range="${START_REF}..HEAD"
  else
    if ! git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
      log "この走行でのコミットはありません。"
      return 0
    fi
    range="HEAD"
  fi

  log "この走行で積まれたコミット（自律判断の記録はこの本文にあります。必ず読んでください）:"
  git --no-pager log --stat "$range"
}

cleanup() {
  audit
  if [ -n "$SESSION_LOG" ] && [ "$KEEP_LOG" = 0 ]; then rm -f "$SESSION_LOG"; fi
}

# 標準入力から利用上限のメッセージを抜き出す(無ければ何も出さない)。
# stream-json では "text":"..." の中に入るので、引用符の内側だけを取る。
limit_message() {
  grep -oiE "[^\"]*(${LIMIT_PATTERN})[^\"]*" | tail -n 1 | cut -c1-200
}

# 上限メッセージからリセット時刻("resets 8:20pm (Asia/Tokyo)" 等)を読み、
# 待つ秒数を返す。読めなければ既定の待機秒を返す。
limit_wait_seconds() {
  local secs=""
  if command -v python3 >/dev/null 2>&1; then
    secs="$(printf '%s\n' "$1" | python3 -c '
import sys, re, datetime
try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None
msg = sys.stdin.read()
m = re.search(r"reset[a-z]*\s*(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?", msg, re.I)
if not m:
    sys.exit(1)
hour = int(m.group(1))
minute = int(m.group(2) or 0)
ap = (m.group(3) or "").lower()
if ap == "pm" and hour != 12:
    hour += 12
if ap == "am" and hour == 12:
    hour = 0
if hour > 23 or minute > 59:
    sys.exit(1)
tz = None
z = re.search(r"\(([A-Za-z]+/[A-Za-z0-9_+-]+)\)", msg)
if z and ZoneInfo is not None:
    try:
        tz = ZoneInfo(z.group(1))
    except Exception:
        tz = None
now = datetime.datetime.now(tz)
target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
if target <= now:
    target += datetime.timedelta(days=1)
print(int((target - now).total_seconds()) + 60)
' 2>/dev/null)"
  fi

  case "$secs" in
    ''|*[!0-9]*) printf '%s' "$LIMIT_FALLBACK_WAIT" ;;
    *)           printf '%s' "$secs" ;;
  esac
}

# 利用上限に当たったときの待機。待つのが正しい動作なので、ここでは人を呼ばない。
# 待っても解消しない(累計が上限に達した)ときだけ止める。
limit_hold() {
  local msg="$1" wait_for total
  wait_for="$(limit_wait_seconds "$msg")"
  total=$(( LIMIT_WAITED + wait_for ))

  log "利用上限: ${msg}"

  if [ "$total" -gt "$LIMIT_WAIT_CAP" ]; then
    log "次の再開まで $(duration "$wait_for")、この走行の累計待機は $(duration "$total") になります。"
    log "累計の上限 $(duration "$LIMIT_WAIT_CAP") を超えるため、ここで止めます。"
    log "DRAFT_LOOP_LIMIT_WAIT_CAP を伸ばして再実行してください。"
    exit 6
  fi

  LIMIT_WAITED="$total"
  log "$(duration "$wait_for")待って再開します（この走行の累計待機 $(duration "$LIMIT_WAITED")）。停滞としては数えません。"
  sleep "$wait_for"
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

# 進捗も理由も残さずに終わった反復の「終わり方」を示す。無人セッションは、ツール実行を
# 伴わない発話でターンを閉じた時点で終わる。最後が発話なら自分で終端したということで、
# 最後がツール実行なら落ちたか中断されたということである。この2つは原因も対処も違うのに、
# 走行ログからは同じ「未記録のまま終了」に見える。ログを消さずに残すのも同じ理由で、
# 後から読める経路がここしか無い。
session_tail() {
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$SESSION_LOG" <<'EOF'
import json, sys

last_text = ""
last_kind = ""
turns = None
try:
    fh = open(sys.argv[1], encoding="utf-8", errors="replace")
except OSError:
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "assistant":
            for c in ev.get("message", {}).get("content", []):
                kind = c.get("type")
                if kind in ("text", "tool_use"):
                    last_kind = kind
                if kind == "text":
                    t = " ".join(c.get("text", "").split())
                    if t:
                        last_text = t
        elif ev.get("type") == "result":
            turns = ev.get("num_turns")

if turns is not None:
    print("  ターン数: %s" % turns)
if last_kind == "text" and last_text:
    print("  最後は発話でターンを閉じています（無人ではこれが終端です）:")
    print("    %s" % last_text[:200])
elif last_kind == "tool_use":
    print("  最後はツール実行の途中で切れています（クラッシュか中断の疑い）。")
EOF
}

# 1ステップを新しいセッションで実行する。claude の終了コードを返す。
# 出力は $SESSION_LOG にも落とす(利用上限のメッセージを走行後に読むため)。
run_step() {
  : > "$SESSION_LOG"
  local prompt
  prompt="$(session_prompt "$1")"

  if [ "${DRAFT_LOOP_RAW:-0}" = "1" ] || ! command -v python3 >/dev/null 2>&1; then
    claude -p "$prompt" --permission-mode "$PERMISSION_MODE" < /dev/null | tee "$SESSION_LOG"
    return "${PIPESTATUS[0]}"
  fi
  claude -p "$prompt" --permission-mode "$PERMISSION_MODE" \
      --output-format stream-json --verbose < /dev/null | tee "$SESSION_LOG" | format_progress
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
  local prompt probe limit
  prompt='Agentツールでサブエージェントを1体だけ起動し、Bashで `git status --short` を実行させてください。'
  prompt+='起動して実行できたら READY の1語だけを、できなければ UNAVAILABLE の1語だけを出力してください。他には何も出力しないこと。'

  while :; do
    probe="$(claude -p "$prompt" --permission-mode "$PERMISSION_MODE" < /dev/null 2>&1)"

    case "$probe" in
      *READY*)
        log "独立レビューは起動できます。"
        return 0
        ;;
    esac

    # 上限中は確認そのものが通らない。起動できないのではなく、まだ試せていない。
    limit="$(printf '%s\n' "$probe" | limit_message)"
    if [ -n "$limit" ]; then
      limit_hold "$limit"
      continue
    fi

    log "独立レビューを起動できません。無人ループは開始しません。"
    log "権限設定(.claude/settings.json の許可リスト、または DRAFT_LOOP_PERMISSION_MODE)を見直してください。"
    log "応答: ${probe}"
    exit 5
  done
}

command -v claude >/dev/null 2>&1 || { log "claude が PATH にありません。"; exit 1; }

case "$MODE" in
  iteration)
    git rev-parse --git-dir >/dev/null 2>&1 || {
      log "gitリポジトリではありません。iterationモードは実装済みの判定をgitから導きます。"
      exit 1
    }
    if [ -z "$(fdds)" ]; then
      log "$FEATURES にFDDがありません。先に /draft:feature で設計してください。"
      exit 1
    fi
    ;;
  phase5)
    if [ ! -f "$PROMPTS" ]; then
      log "$PROMPTS が見つかりません。Phase 4 (/draft:prep) が未完了です。"
      exit 1
    fi
    ;;
  *)
    log "DRAFT_LOOP_MODE の値が不正です: ${MODE} (phase5 か iteration)"
    exit 1
    ;;
esac

SESSION_LOG="$(mktemp "${TMPDIR:-/tmp}/draft-loop.XXXXXX")" || { log "一時ファイルを作れません。"; exit 1; }

if git rev-parse --git-dir >/dev/null 2>&1; then
  # --verify --quiet はコミットが無いとき何も出さずに失敗する。
  # 素の `git rev-parse HEAD` は "HEAD" という文字列を吐くので使えない。
  START_REF="$(git rev-parse --verify --quiet HEAD || true)"
  START_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

trap cleanup EXIT

case "$MODE" in
  iteration) log "対象: $FEATURES の未実装FDD / 上限: ${MAX_ITER}反復 / 権限: ${PERMISSION_MODE}" ;;
  *)         log "対象: $PROMPTS / 上限: ${MAX_ITER}反復 / 権限: ${PERMISSION_MODE}" ;;
esac

preflight_review

prev_target=""
repeat=0

for (( iter = 1; iter <= MAX_ITER; iter++ )); do
  blocked="$(first_blocked)"
  if [ -n "$blocked" ]; then
    log "保留で停止: $(label_of "$blocked")"
    log "理由は $PROMPTS の該当 Status: 行の直後にあります。人の判断を入れてから再実行してください。"
    exit 2
  fi

  target="$(first_pending)"
  if [ -z "$target" ]; then
    case "$MODE" in
      iteration) log "未実装のFDDはありません。次の変更は /draft:feature で設計してください。" ;;
      *)         log "全ステップが done です。Phase 5 完了。" ;;
    esac
    exit 0
  fi

  label="$(label_of "$target")"

  if [ "$target" = "$prev_target" ]; then
    repeat=$(( repeat + 1 ))
  else
    repeat=1
    prev_target="$target"
  fi

  if [ "$repeat" -ge 3 ]; then
    KEEP_LOG=1
    log "停止: ${label} が2回続けて進捗を残さずに終わりました。"
    log "クラッシュ、コンテキスト切れ、または反復が自分で発話を終えた可能性があります(利用上限なら自動で待つので、これには当たりません)。"
    log "直前のセッションの全出力: $SESSION_LOG"
    exit 3
  fi

  if [ "$repeat" -eq 1 ]; then
    log "反復 ${iter}/${MAX_ITER}: ${label}"
  else
    log "反復 ${iter}/${MAX_ITER}: ${label} （再試行 $(( repeat - 1 ))回目）"
  fi

  SECONDS=0
  run_step "$target"
  rc=$?

  # 履歴を読む前に、始めたブランチへ戻っていることを確かめる。作業ブランチに残ったまま
  # 終えると、取り込んでいない変更がそのブランチの履歴に見えて実装済みと誤判定される。
  if [ "$MODE" = iteration ] && [ -n "$START_BRANCH" ]; then
    now_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ "$now_branch" != "$START_BRANCH" ]; then
      KEEP_LOG=1
      log "停止: ${label} が ${START_BRANCH} ではなく ${now_branch} で終わりました ($(elapsed))"
      log "変更を取り込めていない可能性があります。${START_BRANCH} に戻して状況を確認してください。"
      log "停止したセッションの全出力: $SESSION_LOG"
      exit 2
    fi
  fi

  after="$(status_of "$target")"

  # 上限で落ちた反復は「進捗を書かずに終わった」に数えない。待って同じステップを再開する。
  if [ -z "$after" ]; then
    limit="$(tail -c 65536 "$SESSION_LOG" 2>/dev/null | limit_message)"
    if [ -n "$limit" ]; then
      log "利用上限で中断: ${label} ($(elapsed))"
      limit_hold "$limit"
      iter=$(( iter - 1 ))
      repeat=$(( repeat - 1 ))
      continue
    fi
  fi

  # iteration には状態欄が無い。人の判断が要って止まった反復は理由を1行で宣言するので、
  # それを走行ログから拾う。宣言が無いまま閉じなかった反復は、上の停滞判定に回る。
  if [ "$MODE" = iteration ] && [ -z "$after" ]; then
    stop="$(tail -c 65536 "$SESSION_LOG" 2>/dev/null \
      | grep -oE 'DRAFT-LOOP-STOP:[^"\\]*' | tail -n 1)"
    if [ -n "$stop" ]; then
      KEEP_LOG=1
      log "保留で停止: ${label} ($(elapsed))"
      log "${stop}"
      log "停止したセッションの全出力: $SESSION_LOG"
      log "人の判断を入れてから再実行してください。"
      exit 2
    fi
  fi

  case "$after" in
    done*)    log "完了: ${label} ($(elapsed))" ;;
    blocked*) log "保留: ${label} ($(elapsed))。次の判定で停止します" ;;
    *)        KEEP_LOG=1
              log "未記録のまま終了: ${label} ($(elapsed), claude終了コード ${rc})"
              session_tail
              log "このセッションの全出力: $SESSION_LOG" ;;
  esac
done

log "反復の上限 (${MAX_ITER}) に到達しました。残りを確認してから再実行してください。"
exit 4
