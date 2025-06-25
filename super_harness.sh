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
libipld=$(uv run main.py libipld)

cd ../serde_ipld_dagcbor
rust=$(cargo run)

jq -n \
  --argjson boxo "$boxo" \
  --argjson helia "$helia" \
  --argjson atcute "$atcute" \
  --argjson cbrrr "$cbrrr" \
  --argjson libipld "$libipld" \
  --argjson goipld "$goipld" \
  --argjson rust "$rust" \
  '{
    "go-ipld-prime": $boxo,
    "js-dag-cbor": $helia,
    "atcute": $atcute,
    "dag-cbrrr": $cbrrr,
    "python-libipld": $libipld,
    "go-ipld-cbor": $goipld,
    "serde_ipld_dagcbor": $rust
  }'
