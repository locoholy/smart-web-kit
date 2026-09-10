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
FAKE_OPENCLI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fake-opencli"
PORT="${SWR_TEST_PORT:-38231}"
TMP="$(mktemp -d)"
SPID=""
pass=0; fail=0

cleanup(){
  if [ -n "$SPID" ]; then
    kill "$SPID" 2>/dev/null || true
    wait "$SPID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

cat > "$TMP/server.js" <<'EOF'
const http=require('http');
http.createServer((req,res)=>{
  const b=(s)=>setTimeout(()=>{res.writeHead(200,{"content-type":"text/html; charset=utf8"});res.end(s)},30);
  if(req.url==='/ok')    return b('<h1>Hello World</h1><p>This is a real page.</p>');
  if(req.url==='/json')  return b('{"key":"value","ok":true}');
  // Served as JSON: must reach stdout byte-for-byte. An HTML stripper run over
  // this silently turns "a < b and c > d" into "a d" and still exits 0.
  if(req.url==='/api'){res.writeHead(200,{"content-type":"application/json"});
    return res.end('{"title":"a < b and c > d","html":"<b>bold</b>","n":5}');}
  // Relative hrefs: "get me the download link" is unanswerable with 'dl/mac.html'.
  if(req.url==='/links') return b('<h1>Downloads</h1><p>Get it for '+
    '<a href="dl/mac.html">Mac</a> or <a href="/dl/win.html">Windows</a>, '+
    'or read the <a href="https://elsewhere.example/docs">docs</a>. '+
    'This page carries enough prose to clear the readability floor comfortably.</p>');
  if(req.url==='/nested-links') return b('<h2><a href="/heading">Downloads</a></h2>'+
    '<ul><li><a href="/app.deb"><span>Linux</span></a></li></ul>'+
    '<nav>Navigation boilerplate<a href="/catalog">Catalog</a></nav>'+
    '<footer><a href="/docs">Docs</a></footer>'+
    '<aside><a href="/other">Other platforms</a></aside>'+
    '<p>This page carries enough prose to clear the readability floor comfortably.</p>');
  // A linked table row: nested tags inside <a>/<h*>/<li> must separate the
  // cells, not fuse "$9.64" + "72,060" + "70" into one run of digits.
  if(req.url==='/cells') return b('<h1>Board</h1><table><tr><td>'+
    '<a href="/m/1"><span>1</span><span>Fable</span><span>73.4%</span>'+
    '<span>$9.64</span><span>72,060</span><span>70</span></a></td></tr></table>'+
    '<p>'+'Padding prose to clear the readability floor. '.repeat(20)+'</p>');
  // A long, valid article that merely MENTIONS a login and a 404. Content.
  if(req.url==='/mentions') return b('<h1>Guide</h1><p>'+'Real documentation body. '.repeat(120)+
    'If the dashboard shows 404 not found, please log in again.</p><p>'+'More prose. '.repeat(120)+'</p>');
  if(req.url==='/404'){res.writeHead(404,{"content-type":"text/html; charset=utf8"});return res.end('<h1>404 Not Found</h1><p>Missing.</p>');}
  if(req.url==='/502'){res.writeHead(502,{"content-type":"text/html; charset=utf8"});return res.end('<p>Bad Gateway</p>');}
  if(req.url==='/wall') return b('<h1>Sign in to continue</h1><p>Please log in.</p>');
  if(req.url==='/gwall') return b('<title>Google Search</title><a href="/search?q=x&amp;emsg=SG_REL">Click here</a><p>If you are having trouble accessing Google Search, please click here.</p>');
  return b('<h1>Fallback</h1>');
}).listen(Number(process.argv[2] || 38231));
EOF
node "$TMP/server.js" "$PORT" & SPID=$!
sleep 1

is(){ [ "$?" -eq 0 ]; }

r(){ # L1 tests must never invoke a real browser; sets R_OUT, R_CODE
  R_OUT=$(SWR_BROWSER=off SWR_TOTAL_BUDGET=2 "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

r_browser(){ # L2 contract test via fake OpenCLI; sets R_OUT, R_CODE
  R_OUT=$(SWR_TOTAL_BUDGET=2 SWR_OPENCLI_BIN="$FAKE_OPENCLI" SWR_OPENCLI_LOG="$TMP/opencli.log" "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

r_browser_error(){ # A Chrome error page must never be emitted as readable content.
  R_OUT=$(SWR_TOTAL_BUDGET=2 SWR_FAKE_ERROR=1 SWR_OPENCLI_BIN="$FAKE_OPENCLI" SWR_OPENCLI_LOG="$TMP/opencli.log" "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

r_browser_dom(){ # Thin extract must be recovered from the page landmark before L3.
  R_OUT=$(SWR_TOTAL_BUDGET=2 SWR_FAKE_THIN_EXTRACT=1 SWR_OPENCLI_BIN="$FAKE_OPENCLI" SWR_OPENCLI_LOG="$TMP/opencli.log" "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

r_browser_mention(){ # A long L2 page that merely mentions a 404 is still content.
  R_OUT=$(SWR_TOTAL_BUDGET=2 SWR_FAKE_MENTION=1 SWR_OPENCLI_BIN="$FAKE_OPENCLI" SWR_OPENCLI_LOG="$TMP/opencli.log" "$SWR" "$1" 2>/dev/null); R_CODE=$?
}

r_browser_l3(){ # L3 must read only a first-party API response.
  R_OUT=$(SWR_TOTAL_BUDGET=2 SWR_FAKE_L3=1 SWR_OPENCLI_BIN="$FAKE_OPENCLI" SWR_OPENCLI_LOG="$TMP/opencli.log" "$SWR" "$1" 2>/dev/null); R_CODE=$?
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
check "init rejects flags     " 2 "$( "$SWR" init --global >/dev/null 2>&1; echo $? )"
check "invalid browser window " 2 "$( SWR_BROWSER_WINDOW=sideways "$SWR" "$BASE/ok" >/dev/null 2>&1; echo $? )"
check "valid 200 -> ok        " 0 "$( "$SWR" "$BASE/ok" >/dev/null 2>/dev/null; echo $? )"

r "$BASE/ok"
  [ "$R_CODE" = 0 ] && [ -n "$R_OUT" ];    check "200 has content          " 1 "$(is && echo 1 || echo 0)"
r "$BASE/json"
  [ "$R_CODE" = 0 ] && [ -n "$R_OUT" ];    check "short JSON is content    " 1 "$(is && echo 1 || echo 0)"

r "$BASE/api"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *'"a < b and c > d"'* ]] && [[ "$R_OUT" == *'"<b>bold</b>"'* ]]
  check "JSON survives verbatim   " 1 "$(is && echo 1 || echo 0)"
r "$BASE/links"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"($BASE/dl/mac.html)"* ]] && [[ "$R_OUT" == *"($BASE/dl/win.html)"* ]] \
    && [[ "$R_OUT" == *"(https://elsewhere.example/docs)"* ]]
  check "links come out absolute  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/nested-links"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"[Downloads]($BASE/heading)"* ]] \
    && [[ "$R_OUT" == *"[Linux]($BASE/app.deb)"* ]] \
    && [[ "$R_OUT" == *"[Catalog]($BASE/catalog)"* ]] \
    && [[ "$R_OUT" == *"[Docs]($BASE/docs)"* ]] \
    && [[ "$R_OUT" == *"[Other platforms]($BASE/other)"* ]] \
    && [[ "$R_OUT" != *"Navigation boilerplate"* ]]
  check "nested/navigation links  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/cells"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"1 Fable 73.4% \$9.64 72,060 70"* ]]
  check "nested cells stay apart  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/mentions"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"Real documentation body"* ]]
  check "long page: mention != wall" 1 "$(is && echo 1 || echo 0)"
: > "$TMP/opencli.log"
r_browser_mention "$BASE/gwall"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"deterministic fixture"* ]]
  check "L2 page: mention != wall " 1 "$(is && echo 1 || echo 0)"

r "$BASE/404"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "404 -> exit != 0, empty  " 1 "$(is && echo 1 || echo 0)"
: > "$TMP/opencli.log"
r_browser "$BASE/404"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ] && [ ! -s "$TMP/opencli.log" ]; check "404 skips browser       " 1 "$(is && echo 1 || echo 0)"
r "$BASE/502"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "5xx -> exit != 0, empty  " 1 "$(is && echo 1 || echo 0)"
r "$BASE/wall"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "login wall -> err, empty " 1 "$(is && echo 1 || echo 0)"
r "$BASE/gwall"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "google wall -> err, empty" 1 "$(is && echo 1 || echo 0)"
r_browser "$BASE/gwall"
  [ "$R_CODE" = 0 ] && [ -n "$R_OUT" ];    check "google wall -> fake L2 " 1 "$(is && echo 1 || echo 0)"
  grep -F "open $BASE/gwall --window background" "$TMP/opencli.log" >/dev/null; check "L2 opens background    " 1 "$(is && echo 1 || echo 0)"
r_browser_error "$BASE/gwall"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "Chrome HTTP error -> empty" 1 "$(is && echo 1 || echo 0)"
r_browser_dom "$BASE/gwall"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *"DOM fallback"* ]]; check "thin extract -> DOM read " 1 "$(is && echo 1 || echo 0)"
  grep -F "get html --selector main, article, [role=main] --as html" "$TMP/opencli.log" >/dev/null; check "DOM landmark contract  " 1 "$(is && echo 1 || echo 0)"
r_browser_l3 "$BASE/gwall"
  [ "$R_CODE" = 0 ] && [[ "$R_OUT" == *'"plan":"SuperGrok"'* ]]; check "L3 reads first-party API " 1 "$(is && echo 1 || echo 0)"
  grep -F "network --detail first-party" "$TMP/opencli.log" >/dev/null && ! grep -F "network --detail third-party" "$TMP/opencli.log" >/dev/null; check "L3 rejects third-party    " 1 "$(is && echo 1 || echo 0)"
r "http://10.255.255.1/x"
  [ "$R_CODE" != 0 ] && [ -z "$R_OUT" ];   check "unreachable -> err, empty" 1 "$(is && echo 1 || echo 0)"

mkdir -p "$TMP/home" "$TMP/proj" && ( cd "$TMP/proj" && HOME="$TMP/home" "$SWR" init ) >/dev/null 2>&1
  [ -f "$TMP/home/.agents/skills/smart-web-read/SKILL.md" ]; check "swr init -> global read  " 1 "$(is && echo 1 || echo 0)"
  [ -f "$TMP/home/.agents/skills/swr-search/SKILL.md" ];       check "swr init -> global search" 1 "$(is && echo 1 || echo 0)"
  [ -f "$TMP/home/.agents/skills/swr-research/SKILL.md" ];     check "swr init -> global research" 1 "$(is && echo 1 || echo 0)"
  cmp -s "$(dirname "$SWR")/../skills/smart-web-read/SKILL.md" "$TMP/home/.agents/skills/smart-web-read/SKILL.md"; check "read source synced      " 1 "$(is && echo 1 || echo 0)"
  cmp -s "$(dirname "$SWR")/../skills/swr-search/SKILL.md" "$TMP/home/.agents/skills/swr-search/SKILL.md";       check "search source synced    " 1 "$(is && echo 1 || echo 0)"
  cmp -s "$(dirname "$SWR")/../skills/swr-research/SKILL.md" "$TMP/home/.agents/skills/swr-research/SKILL.md";   check "research source synced  " 1 "$(is && echo 1 || echo 0)"
  [ "$(HOME="$TMP/home" "$SWR" doctor --skills 2>/dev/null; echo $?)" = "skills-ready
0" ]; check "doctor skills synced    " 1 "$(is && echo 1 || echo 0)"
  [ ! -d "$TMP/proj/.agents" ] && [ ! -d "$TMP/proj/.claude" ]; check "no project skill dirs   " 1 "$(is && echo 1 || echo 0)"

echo "---"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
