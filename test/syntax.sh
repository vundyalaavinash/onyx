#!/usr/bin/env bash
# Every shell script in the pipeline must parse.
set -e
cd "$(dirname "$0")/.."
fail=0
while IFS= read -r f; do
  bash -n "$f" || { echo "syntax error: $f"; fail=1; }
done < <(find . -name '*.sh' -not -path './vscode/*' -not -path './node_modules/*')
[[ $fail == 0 ]] && echo "syntax ok"
exit $fail
