#!/usr/bin/env bash
# desktop-test.sh: check that every desktop termos-desktop offers is a real
# Fedora environment group whose packages can be installed together.
#
#   tests/desktop-test.sh
#
# Run as root in a Fedora container or VM of TermOS's release. Nothing is
# installed: dnf only works out each transaction. To be closer to a TermOS
# system, it first switches the container's release identity to Fedora
# KDE's, which TermOS is built from.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool="$repo/bin/termos-desktop"

if rpm -q fedora-release-identity-container >/dev/null 2>&1; then
    dnf -y -q swap fedora-release-identity-container fedora-release-identity-kde >/dev/null
fi

failed=()
for name in $("$tool" names); do
    if "$tool" check "$name"; then :; else failed+=("$name"); fi
done
"$tool" list >/dev/null
if (( ${#failed[@]} )); then
    echo "desktop-test: FAILED: ${failed[*]}" >&2
    exit 1
fi
echo "desktop-test: every desktop can be installed"
