#!/usr/bin/env bash

set -euo pipefail

cd harnesses/boxo
boxo=$(go run ./main.go)
cd ../go-ipld-cbor
goipld=$(go run ./main.go)

cd ../js
helia=$(node main.js helia)
atcute=$(node main.js atcute)

cd ../python
cbrrr=$(uv run main.py dag-cbrrr)
pylibipld=$(uv run main.py libipld)

cd ../serde_ipld_dagcbor
serde_ipld_dagcbor=$(cargo run -q)

cd ../libipld
libipld=$(cargo run -q)

cd ../java-dag-cbor
mvn compile -q
java=$(mvn exec:java -Dexec.mainClass="coop.hypha.Main" -q)

jq -n \
  --argjson boxo "$boxo" \
  --argjson helia "$helia" \
  --argjson atcute "$atcute" \
  --argjson cbrrr "$cbrrr" \
  --argjson pylibipld "$pylibipld" \
  --argjson libipld "$libipld" \
  --argjson goipld "$goipld" \
  --argjson serde_ipld_dagcbor "$serde_ipld_dagcbor" \
  --argjson java "$java" \
  '{
    "go-ipld-prime": $boxo,
    "go-ipld-cbor": $goipld,
    "js-dag-cbor": $helia,
    "atcute": $atcute,
    "dag-cbrrr": $cbrrr,
    "python-libipld": $pylibipld,
    "serde_ipld_dagcbor": $serde_ipld_dagcbor,
    "libipld": $libipld,
    "java-dag-cbor": $java
  }'
