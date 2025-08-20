#!/usr/bin/env bash

set -euo pipefail

cd harnesses/boxo
go get github.com/ipld/go-ipld-prime@v0

cd ../go-ipld-cbor
go get github.com/ipfs/go-ipld-cbor@v0

cd ../go-dasl
go get github.com/hyphacoop/go-dasl@latest

cd ../js
npm update @ipld/dag-cbor
npm update @atcute/cbor

cd ../python
uv lock -U

cd ../serde_ipld_dagcbor
cargo update serde_ipld_dagcbor

cd ../libipld
cargo update libipld

cd ../java-dag-cbor
# Manually use latest tag
latest_tag=$(curl -s "https://api.github.com/repos/peergos/dag-cbor/tags" | jq -r '.[0].name')
mvn versions:use-latest-versions -DgenerateBackupPoms=false
mvn versions:use-dep-version -Dincludes="com.github.peergos:dag-cbor" -DdepVersion="$latest_tag" -DforceVersion=true -DgenerateBackupPoms=false
