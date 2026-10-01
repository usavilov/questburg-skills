#!/usr/bin/env bash
# Questburg API client: curl only, works on bash 3.2 (macOS) and up.
#
# Key:  $QUESTBURG_API_KEY, or the file ~/.config/questburg/key
# Base: $QUESTBURG_API_URL, default https://questburg.com/api/v1
#
# Prints the JSON answer to stdout. Exit code 0 on 2xx, 1 on an API error
# (the body is still printed: it says what went wrong), 2 on a usage error.
set -euo pipefail

BASE="${QUESTBURG_API_URL:-https://questburg.com/api/v1}"
KEY_FILE="${QUESTBURG_KEY_FILE:-$HOME/.config/questburg/key}"

usage() {
  cat >&2 <<'EOF'
Usage: qb.sh <command>

  me                               family, members (codes, points), key scope
  today [--member CODE] [--date YYYY-MM-DD]
                                   quests of the day with ids and states
  approvals                        what the kids checked off, waiting for an answer
  done <id>                        check a quest off
  approve <id>                     approve it: points are credited
  reject <id>                      decline a check-off
  approve-all                      approve everything the kids checked off
  offers                           active quests
  add-offer --title T --to kids|CODE[,CODE…]
            [--points N] [--weekdays 1,3,5] [--description D] [--no-approval]
                                   add a quest (weekdays: 0 = Sunday; none = daily)
EOF
  exit 2
}

key() {
  if [ -n "${QUESTBURG_API_KEY:-}" ]; then
    printf '%s' "$QUESTBURG_API_KEY"
  elif [ -r "$KEY_FILE" ]; then
    tr -d '[:space:]' <"$KEY_FILE"
  else
    echo "No key: set QUESTBURG_API_KEY or put the key into $KEY_FILE" >&2
    exit 2
  fi
}

# JSON string literal from arbitrary text: quotes, backslashes, control chars.
json() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '"%s"' "$s"
}

# call METHOD PATH [JSON_BODY]
call() {
  local method=$1 path=$2 body=${3:-} out code token
  token=$(key)
  out=$(mktemp)
  if [ -n "$body" ]; then
    code=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$BASE$path" \
      -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$body")
  else
    code=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$BASE$path" \
      -H "Authorization: Bearer $token")
  fi
  cat "$out"
  echo
  rm -f "$out"
  case "$code" in
    2??) return 0 ;;
    *) echo "HTTP $code" >&2; return 1 ;;
  esac
}

need_id() {
  [ -n "${1:-}" ] || usage
  # Ids come from `today` / `approvals`; anything else is a typo.
  case "$1" in
    *[!0-9a-fA-F-]*) echo "Not an id: $1 — take it from 'today' or 'approvals'" >&2; exit 2 ;;
  esac
}

cmd=${1:-}
[ -n "$cmd" ] || usage
shift

case "$cmd" in
  me) call GET /me ;;

  today)
    query=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --member) query="$query&member=${2:?--member needs a code}"; shift 2 ;;
        --date) query="$query&date=${2:?--date needs YYYY-MM-DD}"; shift 2 ;;
        *) usage ;;
      esac
    done
    call GET "/today${query:+?${query#&}}"
    ;;

  approvals) call GET /approvals ;;
  approve-all) call POST /approvals/approve-all ;;

  done | approve | reject)
    need_id "${1:-}"
    call POST "/occurrences/$1/$cmd"
    ;;

  offers) call GET /offers ;;

  add-offer)
    title="" to="" points=0 weekdays="" description="" approval=true
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) title=${2:?--title needs a value}; shift 2 ;;
        --to) to=${2:?--to needs kids or member codes}; shift 2 ;;
        --points) points=${2:?--points needs a number}; shift 2 ;;
        --weekdays) weekdays=${2:?--weekdays needs numbers 0-6}; shift 2 ;;
        --description) description=${2:?--description needs a value}; shift 2 ;;
        --no-approval) approval=false; shift ;;
        *) usage ;;
      esac
    done
    [ -n "$title" ] && [ -n "$to" ] || usage
    case "$points" in '' | *[!0-9]*) echo "--points is a whole number, 0 or more" >&2; exit 2 ;; esac
    case "$weekdays" in *[!0-6,]*) echo "--weekdays are numbers 0-6 separated by commas" >&2; exit 2 ;; esac

    if [ "$to" = "kids" ]; then
      assignees='"kids"'
    else
      assignees="["
      old_ifs=$IFS
      IFS=,
      for code in $to; do assignees="$assignees$(json "$code"),"; done
      IFS=$old_ifs
      assignees="${assignees%,}]"
    fi

    body="{\"title\":$(json "$title"),\"assignees\":$assignees,\"points\":$points"
    body="$body,\"weekdays\":[$weekdays],\"requiresApproval\":$approval"
    [ -n "$description" ] && body="$body,\"description\":$(json "$description")"
    call POST /offers "$body}"
    ;;

  *) usage ;;
esac
