#!/usr/bin/env bash
set -euo pipefail

cd "${BASH_SOURCE[0]%/*}/.."

find ./ -type f -name '*.sh' | while IFS= read -r path; do
    echo "$path"
    file=${path##*/}
    dir=${path%/*}
    # Switch working directory so that shellcheck can access external sources
    # (via arg `--external-sources`)
    pushd "$dir" > /dev/null
    shellcheck --external-sources --shell bash "$file"
    popd > /dev/null
done
