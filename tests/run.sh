#!/usr/bin/env bash
# swr test runner — no network, no Chrome needed. Spins a tiny local HTTP
# server and asserts the credibility invariants that define the product:
#   - valid 200 + short JSON  → exit 0, content on stdout
#   - 404 / 5xx / login wall / unreachable host → exit != 0, NO content
#   - bad usage / invalid url → exit 2
#   - swr init / doctor work
# Usage: ./tests/run.sh   (needs node >= 18; no opencli required)
set -uo pipefail

SWR="${SWR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/swr}"
PORT="${SWR_TEST_PORT:-38231}"
TMP="$(mktemp -d)"
SPID=""
pass=0; fail=0

cleanup(){ [ -n "$SPID" ] && kill "$SPID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

cat > "$TMP/server.js" <<'EOF'
const http=require('http');
http.createServer((req,res)=>{
  const b=(s)=>setTimeout(()=>{res.writeHead(200,{"content-type":"text/html; charset=utf8"});res.end(s)},30);
  if(req.url==='/ok')    return b('<h1>Hello World</h1><p>This is a real page.</p>');
  if(req.url==='/json')  return b('{"key":"value","ok":true}');
  if(req.url==='/404'){res.writeHead(404,{"content-type":"text/html; charset=utf8"});return res.end('<h1>404 Not Found</h1><p>Missing.</p>');}
  if(req.url==='/502'){res.writeHead(502,{"content-type":"text/html; charset=utf8"});return res.end('<p>Bad Gateway</p>');}
  if(req.url==='/wall') return b('<h1>Sign in to continue</h1><p>Please log in.</p>');
  return b('<h1>Fallback</h1>');
}).listen(Number(process.argv[2] || 38231));
EOF
node "$TMP/server.js" "$PORT" & SPID=$!
sleep 1

is(){ [ "$?" -eq 0 ]; }

r(){ # run swr capturing stdout; sets R_OUT, R_CODE
  R_OUT=$(SWR_TOTAL_BUDGET=2 "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

check(){ # name expected actual  -> prints PASS/FAIL
  local name="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then echo "PASS  $name (got $got)"; pass=$((pass+1));
  else echo "FAIL  $name (got $got, want $want)"; fail=$((fail+1)); fi
}

BASE="http://127.0.0.1:$PORT"

check "usage (no args)        " 2 "$( "$SWR"; echo $? )"
check "invalid url            " 2 "$( "$SWR" notaurl 2>/dev/null; echo $? )"
check "--version              " 0 "$( "$SWR" --version >/dev/null; echo $? )"
check "valid 200 -> ok        " 0 "$( "$SWR" "$BASE/ok" >/dev/null 2>/dev/null; echo $? )"

r "$BASE/ok"
  [ "$R_CODE" = 0 ] && [ -n "$R_OUT" ];    check "200 has content          " 1 "$(is && echo 1 || echo 0)"
r "$BASE/json"
  [ "$R_CODE" = 0 ] && [ -n "$R_OUT" ];    check "short JSON is content    " 1 "$(is && echo 1 || echo 0)"

r "$BASE/404"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "404 -> exit != 0, empty  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/502"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "5xx -> exit != 0, empty  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/wall"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "login wall -> err, empty " 1 "$(is && echo 1 || echo 0)"
r "http://10.255.255.1/x"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "unreachable -> err, empty" 1 "$(is && echo 1 || echo 0)"

mkdir -p "$TMP/proj" && ( cd "$TMP/proj" && "$SWR" init ) >/dev/null 2>&1
  [ -f "$TMP/proj/.agents/skills/smart-web-read/SKILL.md" ]; check "swr init -> .agents read " 1 "$(is && echo 1 || echo 0)"
  [ -f "$TMP/proj/.agents/skills/swr-search/SKILL.md" ];       check "swr init -> .agents search" 1 "$(is && echo 1 || echo 0)"
  [ -f "$TMP/proj/.claude/skills/smart-web-read/SKILL.md" ]; check "swr init -> .claude read " 1 "$(is && echo 1 || echo 0)"
  [ -f "$TMP/proj/.claude/skills/swr-search/SKILL.md" ];       check "swr init -> .claude search" 1 "$(is && echo 1 || echo 0)"
  [ ! -d "$TMP/proj/.claude/skills/smart-search" ];            check "no stale smart-search  " 1 "$(is && echo 1 || echo 0)"

echo "---"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]