#!/usr/bin/env bash

set -euo pipefail

# run.sh invokes us as `super_harness.sh > results.json`, so everything we
# write to stdout ends up in the results file. Each harness's JSON output is
# captured into a variable below, and only the final `jq` result is meant to
# reach stdout. The catch: a failing harness may print its error to stdout
# (Maven logs errors there, not stderr), which would silently land in
# results.json and never show up in CI.
#
# `run` guards against that. It captures the harness's stdout, lets stderr flow
# straight to CI, and on failure prints a clearly labelled error — including the
# captured stdout where Maven hides its errors — to stderr before aborting.
run() {
  local name="$1"
  shift
  local out rc=0
  out=$("$@") || rc=$?
  if [ "$rc" -ne 0 ]; then
    {
      echo "::error::harness '$name' failed (exit $rc) running: $*"
      echo "----- captured stdout from '$name' -----"
      printf '%s\n' "$out"
      echo "-----------------------------------------"
    } >&2
    exit "$rc"
  fi
  printf '%s' "$out"
}

cd harnesses/boxo
boxo=$(run go-ipld-prime go run ./main.go)
cd ../go-ipld-cbor
goipld=$(run go-ipld-cbor go run ./main.go)
cd ../go-dasl
godasl=$(run go-dasl go run ./main.go)

cd ../js
helia=$(run js-dag-cbor node main.js helia)
atcute=$(run atcute node main.js atcute)

cd ../python
cbrrr=$(run dag-cbrrr uv run main.py dag-cbrrr)
pylibipld=$(run python-libipld uv run main.py libipld)

cd ../serde_ipld_dagcbor
serde_ipld_dagcbor=$(run serde_ipld_dagcbor cargo run -q)

cd ../n0_dasl
n0_dasl=$(run n0_dasl cargo run -q)

cd ../libipld
libipld=$(run libipld cargo run -q)

cd ../java-dag-cbor
run java-dag-cbor-compile mvn compile -q >/dev/null
java=$(run java-dag-cbor mvn exec:java -Dexec.mainClass="coop.hypha.Main" -q)

jq -n \
  --argjson godasl "$godasl" \
  --argjson boxo "$boxo" \
  --argjson helia "$helia" \
  --argjson atcute "$atcute" \
  --argjson cbrrr "$cbrrr" \
  --argjson pylibipld "$pylibipld" \
  --argjson libipld "$libipld" \
  --argjson goipld "$goipld" \
  --argjson n0_dasl "$n0_dasl" \
  --argjson serde_ipld_dagcbor "$serde_ipld_dagcbor" \
  --argjson java "$java" \
  '{
    "go-dasl": $godasl,
    "go-ipld-prime": $boxo,
    "go-ipld-cbor": $goipld,
    "js-dag-cbor": $helia,
    "atcute": $atcute,
    "dag-cbrrr": $cbrrr,
    "python-libipld": $pylibipld,
    "n0_dasl": $n0_dasl,
    "serde_ipld_dagcbor": $serde_ipld_dagcbor,
    "libipld": $libipld,
    "java-dag-cbor": $java
  }'
