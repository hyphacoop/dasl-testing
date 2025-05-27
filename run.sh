#!/usr/bin/env bash

set -euo pipefail

./super_harness.sh > results.json
cd report
uv run main.py ../results.json
echo The report is available at report/dist/index.html, open it in your browser.
echo '  $ firefox report/dist/index.html'
