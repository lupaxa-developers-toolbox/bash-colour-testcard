#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARD="${ROOT}/src/bash-colour-testcard.sh"
FAILS=0

assert_eq()
{
    local got="$1"
    local want="$2"
    local name="$3"
    if [[ "${got}" == "${want}" ]]; then
        printf 'PASS  %s\n' "${name}"
        return 0
    fi
    printf 'FAIL  %s\n' "${name}"
    printf '      got:  [%s]\n' "${got}"
    printf '      want: [%s]\n' "${want}"
    FAILS=$((FAILS + 1))
}

assert_contains()
{
    local haystack="$1"
    local needle="$2"
    local name="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        printf 'PASS  %s\n' "${name}"
        return 0
    fi
    printf 'FAIL  %s\n' "${name}"
    printf '      missing: [%s]\n' "${needle}"
    printf '      output:  [%s]\n' "${haystack}"
    FAILS=$((FAILS + 1))
}

assert_not_contains()
{
    local haystack="$1"
    local needle="$2"
    local name="$3"
    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf 'PASS  %s\n' "${name}"
        return 0
    fi
    printf 'FAIL  %s\n' "${name}"
    printf '      unexpectedly found: [%s]\n' "${needle}"
    FAILS=$((FAILS + 1))
}

run_card()
{
    NO_COLOR='' TERM=xterm-256color FORCE_COLOR=1 COLUMNS="${COLUMNS:-80}" "${CARD}" "$@"
}

# ---------------------------------------------------------------------------
# Version and help
# ---------------------------------------------------------------------------
# shellcheck disable=SC1090,SC1091
source "${CARD}"
cli_version="$(run_card -V)"
assert_eq "${cli_version}" "$(get_version)" "-V matches get_version"

help_rc=0
help_out="$(run_card -h)" || help_rc=$?
assert_eq "${help_rc}" "0" "-h exits 0"
assert_contains "${help_out}" "Usage:" "-h prints usage"

# ---------------------------------------------------------------------------
# Colour count
# ---------------------------------------------------------------------------
count_out="$(run_card -n)"
if [[ "${count_out}" =~ [0-9]+ ]]; then
    printf 'PASS  -n prints a colour count\n'
else
    printf 'FAIL  -n prints a colour count\n'
    printf '      output: [%s]\n' "${count_out}"
    FAILS=$((FAILS + 1))
fi

# ---------------------------------------------------------------------------
# Mode exclusivity and -m bounds
# ---------------------------------------------------------------------------
combo_rc=0
combo_err="$(run_card -c -s 2>&1)" || combo_rc=$?
assert_eq "${combo_rc}" "1" "-c and -s together exit 1"
assert_contains "${combo_err}" "Usage:" "-c and -s print usage"

zero_rc=0
zero_err="$(run_card -m 0 2>&1)" || zero_rc=$?
assert_eq "${zero_rc}" "1" "-m 0 exits 1"
assert_contains "${zero_err}" "between 1-" "-m 0 names the valid range"

over_rc=0
over_err="$(run_card -m 9999 2>&1)" || over_rc=$?
assert_eq "${over_rc}" "1" "-m above ncolors exits 1"
assert_contains "${over_err}" "between 1-" "-m overflow names the valid range"

# ---------------------------------------------------------------------------
# -m without a mode still draws simple swatches; last index is count-1
# ---------------------------------------------------------------------------
simple_out="$(run_card -m 8)"
assert_contains "${simple_out}" "Code:   0" "-m 8 includes code 0"
assert_contains "${simple_out}" "Code:   7" "-m 8 includes code 7"
assert_not_contains "${simple_out}" "Code:   8" "-m 8 does not include code 8"

# ---------------------------------------------------------------------------
# Complete mode is n×n and respects -m as a count
# ---------------------------------------------------------------------------
complete_out="$(run_card -c -m 2)"
assert_contains "${complete_out}" "F:  0 B:  0" "complete -m 2 includes 0×0"
assert_contains "${complete_out}" "F:  1 B:  1" "complete -m 2 includes 1×1"
assert_not_contains "${complete_out}" "F:  2 B:" "complete -m 2 excludes fg 2"

# ---------------------------------------------------------------------------
# Complete without -m caps at 16 on 256-colour terminals
# ---------------------------------------------------------------------------
capped_err="$(run_card -c 2>&1 >/dev/null)" || true
assert_contains "${capped_err}" "16" "complete without -m mentions the 16-colour cap"

# ---------------------------------------------------------------------------
# Column count follows width (not a fixed 3). Cell width is 22.
# ---------------------------------------------------------------------------
count_codes_on_first_swatch_line()
{
    local output="$1"
    local line
    line="$(printf '%s\n' "${output}" | grep 'Code:' | head -n 1)"
    printf '%s\n' "${line}" | grep -o 'Code:' | wc -l | tr -d ' '
}

narrow_rc=0
COLUMNS=10 run_card -s -m 2 >/dev/null || narrow_rc=$?
assert_eq "${narrow_rc}" "0" "COLUMNS=10 simple mode does not crash"

wide_out="$(COLUMNS=110 run_card -s -m 8)"
assert_eq "$(count_codes_on_first_swatch_line "${wide_out}")" "5" \
    "COLUMNS=110 packs 5 simple swatches per row (110/22)"

tight_out="$(COLUMNS=66 run_card -s -m 8)"
assert_eq "$(count_codes_on_first_swatch_line "${tight_out}")" "3" \
    "COLUMNS=66 packs 3 simple swatches per row (66/22)"

# ---------------------------------------------------------------------------
# Test mode copy and EOF
# ---------------------------------------------------------------------------
look_out="$(printf '%s\n' '1' '2' 'n' | run_card -t)"
assert_contains "${look_out}" "will look like" "test mode uses 'will look like'"

eof_rc=0
printf '' | run_card -t >/dev/null 2>&1 || eof_rc=$?
assert_eq "${eof_rc}" "1" "test mode EOF exits 1"

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
nocolor_rc=0
TERM=xterm-256color NO_COLOR=1 FORCE_COLOR=1 "${CARD}" -s -m 2 >/dev/null 2>&1 || nocolor_rc=$?
assert_eq "${nocolor_rc}" "1" "NO_COLOR wins over FORCE_COLOR for display"

notty_rc=0
TERM=xterm-256color "${CARD}" -s -m 2 >/dev/null 2>&1 || notty_rc=$?
assert_eq "${notty_rc}" "1" "display without TTY or FORCE_COLOR exits 1"

if [[ "${FAILS}" -ne 0 ]]; then
    printf 'FAILED: %s assertion(s)\n' "${FAILS}" >&2
    exit 1
fi

echo "PASS: test_bash_colour_testcard.sh"
