#!/usr/bin/env bash
# Stubbed tests for `hc new`. No network access.
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0

setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/root" "$SANDBOX/stub" "$SANDBOX/home"
  cp -R "$REPO/bin" "$REPO/templates" "$SANDBOX/root/"
  mkdir -p "$SANDBOX/root/contests"
  : > "$SANDBOX/oj.log"

  # `oj-api get-contest <url>` lists the problem ids in $OJ_API_PROBLEMS.
  # OJ_API_FAILS makes it answer like a contest that cannot be read.
  cat > "$SANDBOX/stub/oj-api" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == "get-contest" ]] || exit 1
if [[ -n "${OJ_API_FAILS:-}" ]]; then
  echo '{"status": "error", "messages": ["stub oj-api: 404 Not Found"], "result": null}'
  exit 1
fi
url="$2"
sep=""
printf '{"status": "ok", "messages": [], "result": {"url": "%s", "problems": [' "$url"
for p in ${OJ_API_PROBLEMS:-}; do
  printf '%s{"url": "%s/tasks/%s"}' "$sep" "$url" "$p"
  sep=", "
done
printf ']}}\n'
STUB

  # `oj download <url>` writes samples into ./test and logs the call.
  # OJ_DOWNLOAD_FAILS=1 always fails; OJ_DOWNLOAD_FAIL_TIMES=N fails the first
  # N calls (like AtCoder answering 429 Too Many Requests).
  cat > "$SANDBOX/stub/oj" <<STUB
#!/usr/bin/env bash
[[ "\${1:-}" == "download" ]] || exit 0
echo "\$2" >> "$SANDBOX/oj.log"
calls=\$(wc -l < "$SANDBOX/oj.log")
if [[ -n "\${OJ_DOWNLOAD_FAILS:-}" ]] || (( calls <= \${OJ_DOWNLOAD_FAIL_TIMES:-0} )); then
  echo "stub oj: 429 Client Error: Too Many Requests" >&2
  exit 1
fi
mkdir -p test
echo "1" > test/sample-1.in
echo "1" > test/sample-1.out
STUB
  chmod +x "$SANDBOX/stub/oj" "$SANDBOX/stub/oj-api"
}

run_hc() {
  ( export PATH="$SANDBOX/stub:$PATH" HOME="$SANDBOX/home" \
      HC_REQUEST_INTERVAL=0 HC_RETRY_WAIT=0
    "$SANDBOX/root/bin/hc" "$@" ) 2>&1
}

download_count() {
  wc -l < "$SANDBOX/oj.log" | tr -d ' '
}

check() {  # check <name> <expected_status> <actual_status> <output> [expected_substring]
  if [[ "$2" == "$3" ]] && { [[ -z "${5:-}" ]] || [[ "$4" == *"$5"* ]]; }; then
    echo "PASS: $1"; pass=$((pass+1))
  else
    echo "FAIL: $1 (expected status $2, got $3)"; echo "--- output"; echo "$4"; echo "---"
    fail=$((fail+1))
  fi
}

assert() {  # assert <name> <command...>
  local name="$1"; shift
  if "$@"; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name"; fail=$((fail+1))
  fi
}

# 1. fresh contest: every problem gets Main.hs and samples
setup
out="$( export OJ_API_PROBLEMS="abc461_a abc461_b abc461_e"; run_hc new abc461 )"; st=$?
check "fresh contest succeeds" 0 "$st" "$out" "contests/abc461 (3 problems)"
d="$SANDBOX/root/contests/abc461"
assert "files exist on disk" \
  test -f "$d/abc461_a/Main.hs" -a -f "$d/abc461_e/Main.hs" -a -f "$d/abc461_e/test/sample-1.in"
assert "one download per problem" test "$(download_count)" -eq 3

# 2. rerun keeps edited Main.hs and skips problems that already have samples
setup
mkdir -p "$SANDBOX/root/contests/abc461/abc461_a/test"
echo "edited" > "$SANDBOX/root/contests/abc461/abc461_a/Main.hs"
echo 1 > "$SANDBOX/root/contests/abc461/abc461_a/test/sample-1.in"
out="$( export OJ_API_PROBLEMS="abc461_a abc461_b"; run_hc new abc461 )"; st=$?
check "rerun succeeds" 0 "$st" "$out" "ready:"
assert "edited Main.hs is kept" \
  test "$(cat "$SANDBOX/root/contests/abc461/abc461_a/Main.hs")" = "edited"
assert "existing samples are not downloaded again" test "$(download_count)" -eq 1

# 3. transient 429 is retried
setup
out="$( export OJ_API_PROBLEMS="abc461_e" OJ_DOWNLOAD_FAIL_TIMES=2; run_hc new abc461 )"; st=$?
check "transient download failure is retried" 0 "$st" "$out" "retrying"
assert "sample exists after retry" test -f "$SANDBOX/root/contests/abc461/abc461_e/test/sample-1.in"

# 4. persistent download failure -> failure naming the problem
setup
out="$( export OJ_API_PROBLEMS="abc461_a" OJ_DOWNLOAD_FAILS=1; run_hc new abc461 )"; st=$?
check "persistent download failure fails" 2 "$st" "$out" "incomplete problem directory"
assert "attempts are bounded" test "$(download_count)" -eq 3

# 5. problem list cannot be fetched -> failure
setup
out="$( export OJ_API_FAILS=1; run_hc new abc999 )"; st=$?
check "unlistable contest fails" 2 "$st" "$out" "cannot list the problems"

# 6. contest without problems -> failure
setup
out="$( export OJ_API_PROBLEMS=""; run_hc new abc999 )"; st=$?
check "empty contest fails" 2 "$st" "$out" "no problems found"

# 7. contest URL form works
setup
out="$( export OJ_API_PROBLEMS="abc465_a"; run_hc new https://atcoder.jp/contests/abc465 )"; st=$?
check "contest URL form" 0 "$st" "$out" "contests/abc465 (1 problems)"

# 8. problem URL form resolves to its contest
setup
out="$( export OJ_API_PROBLEMS="abc465_g"; run_hc new https://atcoder.jp/contests/abc465/tasks/abc465_g )"; st=$?
check "problem URL form" 0 "$st" "$out" "contests/abc465 (1 problems)"

# 9. non-AtCoder URL is rejected
setup
out="$(run_hc new https://example.com/foo)"; st=$?
check "non-AtCoder URL rejected" 2 "$st" "$out" "not an AtCoder contest URL"

echo
echo "passed: $pass, failed: $fail"
[[ "$fail" -eq 0 ]]
