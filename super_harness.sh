#!/usr/bin/env bash

set -euo pipefail

cd harnesses/boxo
boxo=$(go run ./main.go)

cd ../js
helia=$(node main.js helia)
atcute=$(node main.js atcute)

cd ../dag-cbrrr
cbrrr=$(uv run main.py)

jq -n \
  --argjson boxo "$boxo" \
  --argjson helia "$helia" \
  --argjson atcute "$atcute" \
  --argjson cbrrr "$cbrrr" \
  '{
    "go-ipld-prime": $boxo,
    "js-dag-cbor": $helia,
    "atcute": $atcute,
    "dag-cbrrr": $cbrrr
  }'
