#!/usr/bin/env bash

set -euo pipefail

cd harnesses/boxo
go get github.com/ipld/go-ipld-prime@v0

cd ../go-ipld-cbor
go get github.com/ipfs/go-ipld-cbor@v0

cd ../js
npm update @ipld/dag-cbor
npm update @atcute/cbor

cd ../python
uv lock -U

cd ../serde_ipld_dagcbor
cargo update serde_ipld_dagcbor
