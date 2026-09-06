#!/usr/bin/env bash
# Stubbed tests for `hc new` resilience. No network access.
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0

setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/root" "$SANDBOX/stub" "$SANDBOX/home"
  cp -R "$REPO/bin" "$REPO/templates" "$REPO/config" "$SANDBOX/root/"
  mkdir -p "$SANDBOX/root/contests"
  cat > "$SANDBOX/stub/oj" <<'STUB'
#!/usr/bin/env bash
# `oj download <url>` writes samples into ./test, unless OJ_DOWNLOAD_FAILS is set.
[[ "${1:-}" == "download" ]] || exit 0
[[ -n "${OJ_DOWNLOAD_FAILS:-}" ]] && { echo "stub oj: download failed" >&2; exit 1; }
mkdir -p test
echo "1" > test/sample-1.in
echo "1" > test/sample-1.out
STUB
  cat > "$SANDBOX/stub/oj-prepare" <<'STUB'
#!/usr/bin/env bash
echo "stub oj-prepare: AssertionError (analyzer)" >&2
exit "${OJ_PREPARE_STATUS:-1}"
STUB
  chmod +x "$SANDBOX/stub/oj" "$SANDBOX/stub/oj-prepare"
}

make_problem() {  # make_problem <contest> <problem> <with_main> <with_samples>
  local d="$SANDBOX/root/contests/$1/$2"
  mkdir -p "$d/test"
  [[ "$3" == yes ]] && cp "$SANDBOX/root/templates/Main.hs" "$d/Main.hs"
  if [[ "$4" == yes ]]; then echo 1 > "$d/test/sample-1.in"; echo 1 > "$d/test/sample-1.out"; fi
  return 0
}

run_hc() {
  ( export PATH="$SANDBOX/stub:$PATH" HOME="$SANDBOX/home"; "$SANDBOX/root/bin/hc" "$@" ) 2>&1
}

check() {  # check <name> <expected_status> <actual_status> <output> [expected_substring]
  if [[ "$2" == "$3" ]] && { [[ -z "${5:-}" ]] || [[ "$4" == *"$5"* ]]; }; then
    echo "PASS: $1"; pass=$((pass+1))
  else
    echo "FAIL: $1 (expected status $2, got $3)"; echo "--- output"; echo "$4"; echo "---"
    fail=$((fail+1))
  fi
}

# 1. analyzer failed, but every file is present -> success
setup
make_problem abc465 abc465_a yes yes
make_problem abc465 abc465_g yes yes
out="$(run_hc new abc465)"; st=$?
check "analyzer failure with complete files succeeds" 0 "$st" "$out" "ready:"

# 2. missing Main.hs and samples are repaired
setup
make_problem abc465 abc465_a yes yes
make_problem abc465 abc465_g no no
out="$(run_hc new abc465)"; st=$?
check "missing files are repaired" 0 "$st" "$out" "restore template: abc465_g/Main.hs"
[[ -f "$SANDBOX/root/contests/abc465/abc465_g/Main.hs" ]] \
  && [[ -f "$SANDBOX/root/contests/abc465/abc465_g/test/sample-1.in" ]] \
  && { echo "PASS: repaired files exist on disk"; pass=$((pass+1)); } \
  || { echo "FAIL: repaired files exist on disk"; fail=$((fail+1)); }

# 3. unrepairable problem -> failure
setup
make_problem abc465 abc465_a yes yes
make_problem abc465 abc465_g no no
out="$( export OJ_DOWNLOAD_FAILS=1; run_hc new abc465 )"; st=$?
check "unrepairable problem fails" 2 "$st" "$out" "still incomplete"

# 4. contest directory never created -> failure
setup
out="$(run_hc new abc999)"; st=$?
check "missing contest directory fails" 2 "$st" "$out" "failed before creating"

# 5. clean oj-prepare run stays successful
setup
make_problem abc471 abc471_a yes yes
out="$( export OJ_PREPARE_STATUS=0; run_hc new abc471 )"; st=$?
check "successful oj-prepare run succeeds" 0 "$st" "$out" "ready:"

# 6. contest URL form works
setup
make_problem abc465 abc465_a yes yes
out="$(run_hc new https://atcoder.jp/contests/abc465)"; st=$?
check "contest URL form" 0 "$st" "$out" "contests/abc465 (1 problems)"

# 7. problem URL form resolves to its contest
setup
make_problem abc465 abc465_g yes yes
out="$(run_hc new https://atcoder.jp/contests/abc465/tasks/abc465_g)"; st=$?
check "problem URL form" 0 "$st" "$out" "contests/abc465"

# 8. non-AtCoder URL is rejected
setup
out="$(run_hc new https://example.com/foo)"; st=$?
check "non-AtCoder URL rejected" 2 "$st" "$out" "not an AtCoder contest URL"

echo
echo "passed: $pass, failed: $fail"
[[ "$fail" -eq 0 ]]
