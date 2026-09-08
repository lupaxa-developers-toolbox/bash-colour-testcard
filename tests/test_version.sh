#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARD="${ROOT}/src/bash-colour-testcard.sh"

# shellcheck disable=SC1090,SC1091
source "${CARD}"

version="$(get_version)"
pkg_version="${BASH_COLOUR_TESTCARD_VERSION}"

if [[ "${version}" != "${pkg_version}" ]]; then
    echo "FAIL: get_version does not match BASH_COLOUR_TESTCARD_VERSION" >&2
    exit 1
fi

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+ ]]; then
    echo "FAIL: version is not dotted semver (major.minor…): ${version}" >&2
    exit 1
fi

major="${version%%.*}"
rest="${version#*.}"
minor="${rest%%[.-]*}"
if [[ ! "${major}" =~ ^[0-9]+$ || ! "${minor}" =~ ^[0-9]+$ ]]; then
    echo "FAIL: major/minor are not numeric: ${version}" >&2
    exit 1
fi

echo "PASS: test_version.sh"
