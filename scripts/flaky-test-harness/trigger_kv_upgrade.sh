#!/usr/bin/env bash

# KV upgrade CI-timeout trigger: the original TestVersionedKV_Upgrade wrote
# 1,048,576 passthrough keys and read them back under an unbounded wait loop,
# taking ~7m26s with -race on a loaded runner. This script reproduces the load
# conditions and reports the wall time of the upgrade test so the CI-timeout
# exposure can be measured.

set -euo pipefail

loaders=${1:-6}

pkg=./internal/builtin/logical/kv

pids=()
for ((i = 0; i < loaders; i++)); do
	yes > /dev/null &
	pids+=("$!")
done
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
echo "spawned $loaders CPU loaders"

GOTOOLCHAIN=${GOTOOLCHAIN:-local}
export GOTOOLCHAIN

start=$(date +%s)
go test "$pkg" -race -count=1 -run '^TestVersionedKV_Upgrade$' -timeout 30m
end=$(date +%s)
echo "kv upgrade test wall time: $((end - start))s (with $loaders CPU loaders)"
