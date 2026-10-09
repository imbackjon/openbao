#!/usr/bin/env bash

# Reusable flaky-test exploit harness: runs a target Go test repeatedly under
# the race detector with artificial CPU load to widen timing windows and
# trigger sleep-then-assert races and timer starvation flakes.

set -euo pipefail

usage() {
	cat <<EOF
Usage: $0 <package> <test-regex> <count> [loaders]

Runs 'go test <package> -race -count=<count> -run=<test-regex>' while <loaders>
'yes' processes saturate CPU cores, maximizing the chance of triggering
sleep-then-assert races and timer-starvation flakes.

Examples:
  $0 ./internal/vault '^TestRollbackManager$' 200 6
  $0 ./internal/builtin/credential/kubernetes '^Test_kubeAuthBackend_runTLSConfigUpdater$' 100 0

Environment:
  PATH must include the Go toolchain. GOTOOLCHAIN defaults to local.
EOF
	exit 1
}

package=${1:-}
test_regex=${2:-}
count=${3:-}
loaders=${4:-0}

if [[ -z "$package" || -z "$test_regex" || -z "$count" ]]; then
	usage
fi

GOTOOLCHAIN=${GOTOOLCHAIN:-local}
export GOTOOLCHAIN

if [[ "$loaders" -gt 0 ]]; then
	pids=()
	for ((i = 0; i < loaders; i++)); do
		yes > /dev/null &
		pids+=("$!")
	done
	trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
	echo "spawned $loaders CPU loaders (pids: ${pids[*]})"
fi

echo "running: go test $package -race -count=$count -run='$test_regex'"
go test "$package" -race -count="$count" -run "$test_regex" -timeout 30m
echo "stress completed without reproducing the failure"
