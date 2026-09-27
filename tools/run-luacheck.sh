#!/usr/bin/env bash

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
rc=$?
if (( rc != 0 )) || [[ -z "$script_dir" ]]; then
    echo 'FAIL: helper directory could not be resolved'
    exit "${rc:-1}"
fi

repo="$(git -C "$script_dir/.." rev-parse --show-toplevel 2>/dev/null)"
rc=$?
if (( rc != 0 )) || [[ -z "$repo" ]]; then
    echo 'FAIL: repository root could not be resolved'
    exit "${rc:-1}"
fi

target="${1:-addons}"

if ! command -v luacheck >/dev/null 2>&1; then
    echo 'FAIL: luacheck was not found on PATH'
    echo 'Install a Lua 5.1-compatible Luacheck toolchain before retrying.'
    exit 1
fi

if [[ "$target" = /* ]]; then
    resolved="$target"
else
    resolved="$repo/$target"
fi

if [[ ! -e "$resolved" ]]; then
    echo "FAIL: target does not exist: $target"
    exit 1
fi

printf 'Repository: %s\n' "$repo"
printf 'Luacheck target: %s\n' "$target"

cd "$repo" || exit $?
luacheck "$resolved"
exit $?
