#!/usr/bin/env bash

# Deterministic trigger for the logging permission-test defect: as root,
# mode-0000 directories are still writable, so Setup succeeds and the old
# test's os.ErrPermission expectation fails. This script proves the bypass
# directly, without needing the Go test.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
	echo "not running as root; the permission bypass only manifests with euid 0" 1>&2
	exit 1
fi

dir=$(mktemp -d)
chmod 0000 "$dir"
if touch "$dir/bypass-probe" 2>/dev/null; then
	echo "root bypassed mode-0000 directory permissions: $dir"
	rm -rf "$dir"
	exit 0
fi
rm -rf "$dir"
echo "unexpected: root could not write into the 0000 directory" 1>&2
exit 1
