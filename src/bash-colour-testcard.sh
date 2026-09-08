#!/usr/bin/env bash

# Terminal colour testcard: simple swatches, complete fg×bg, count, or an
# interactive pair test. Colour codes are 0 .. ncolors-1.

BASH_COLOUR_TESTCARD_VERSION="0.1.0"
SCRIPT_TITLE="Bash Colour Testcard"

COMPLETE_DEFAULT_CAP=16
SIMPLE_CELL_WIDTH=22
COMPLETE_CELL_WIDTH=26

get_version()
{
    printf '%s\n' "${BASH_COLOUR_TESTCARD_VERSION}"
}

force_colour()
{
    case "${FORCE_COLOR-}" in
        ""|0|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo])
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

control_c()
{
    printf '%s\n' "${reset-}"
    printf '\n** Interrupted **\n' >&2
    exit 130
}

show_error()
{
    if [[ -n "${1-}" ]]; then
        printf '%s%s%s\n' "${red-}" "${1}" "${reset-}" >&2
    fi
}

probe_ncolors()
{
    if ! tput longname > /dev/null 2>&1; then
        printf 'Unknown terminal type %s - aborting\n' "${TERM-}" >&2
        exit 1
    fi

    ncolors="$(tput colors)"
    if [[ -z "${ncolors}" || "${ncolors}" -le 7 ]]; then
        printf 'Colour support not available or less than 8 colours - aborting\n' >&2
        exit 1
    fi
    max_code=$((ncolors - 1))
}

positive_int()
{
    [[ -n "${1-}" && "${1}" =~ ^[0-9]+$ && "${1}" -gt 0 ]]
}

# Command substitution makes stdout a pipe, so `tput cols` often returns 80.
# Ask the controlling tty (or COLUMNS in a pipe) for the real width.
refresh_width()
{
    local stty_cols=""
    if [[ -t 1 && -r /dev/tty ]]; then
        stty_cols="$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')"
        if positive_int "${stty_cols}"; then
            screen_width="${stty_cols}"
            return 0
        fi
    fi
    if positive_int "${COLUMNS-}"; then
        screen_width="${COLUMNS}"
        return 0
    fi
    screen_width=80
}

grid_columns()
{
    local cell_width="$1"
    local cols=$((screen_width / cell_width))
    if [[ "${cols}" -lt 1 ]]; then
        cols=1
    fi
    printf '%s\n' "${cols}"
}

cache_colour_codes()
{
    local i
    fg_codes=()
    bg_codes=()
    for ((i = 0; i < ncolors; i++)); do
        fg_codes[i]="$(tput setaf "${i}" 2>/dev/null || true)"
        bg_codes[i]="$(tput setab "${i}" 2>/dev/null || true)"
    done
    red="$(tput setaf 1 2>/dev/null || true)"
    bold="$(tput bold 2>/dev/null || true)"
    cls="$(tput clear 2>/dev/null || true)"
    reset="$(tput sgr0 2>/dev/null || true)"
}

require_display()
{
    if [[ -n "${NO_COLOR-}" ]]; then
        printf 'Colour display disabled by NO_COLOR - aborting\n' >&2
        exit 1
    fi
    if [[ ! -t 1 ]] && ! force_colour; then
        printf 'Not a terminal (set FORCE_COLOR=1 to override) - aborting\n' >&2
        exit 1
    fi
    cache_colour_codes
    refresh_width
}

display_count()
{
    local mode="$1"
    if [[ "${LIMITED_MODE}" == true ]]; then
        printf '%s\n' "${limited_colors}"
        return 0
    fi
    if [[ "${mode}" == "complete" && "${ncolors}" -gt "${COMPLETE_DEFAULT_CAP}" ]]; then
        printf 'Showing %s of %s colours (use -m N for more).\n' \
            "${COMPLETE_DEFAULT_CAP}" "${ncolors}" >&2
        printf '%s\n' "${COMPLETE_DEFAULT_CAP}"
        return 0
    fi
    printf '%s\n' "${ncolors}"
}

center_text()
{
    local text="$1"
    local textsize="${#text}"
    local span=$(((screen_width + textsize) / 2))
    printf '%*s\n' "${span}" "${text}"
}

draw_line()
{
    local line
    line="$(printf '%*s' "${screen_width}" '')"
    line="${line// /-}"
    if [[ -t 1 ]]; then
        local start=$'\e(0' end=$'\e(B' acs="${line//-/q}"
        printf '%s%s%s\n' "${start}" "${acs}" "${end}"
        return 0
    fi
    printf '%s\n' "${line}"
}

show_header()
{
    local do_clear="$1"
    shift
    refresh_width
    if [[ "${do_clear}" == "1" && -t 1 ]]; then
        printf '%s' "${cls}"
    fi
    draw_line
    if [[ $# -gt 0 ]]; then
        local line
        for line in "$@"; do
            center_text "${line}"
        done
        draw_line
    fi
}

show_footer()
{
    draw_line
}

show_colour_count()
{
    printf '%s\n' "${SCRIPT_TITLE}"
    printf 'Your terminal appears to support %s colours\n' "${ncolors}"
}

show_simple_colours()
{
    local local_colors color columns
    local_colors="$(display_count simple)"
    show_header 0 "${SCRIPT_TITLE}" "Simple Mode with ${local_colors} of ${ncolors} colours"
    columns="$(grid_columns "${SIMPLE_CELL_WIDTH}")"

    for ((color = 0; color < local_colors; color++)); do
        printf ' %s        %s (Code: %3s) ' "${bg_codes[color]}" "${reset}" "${color}"
        if (( (color + 1) % columns == 0 )); then
            printf '%s\n' "${reset}"
        fi
    done
    if (( local_colors % columns != 0 )); then
        printf '%s\n' "${reset}"
    fi
    show_footer
}

show_complete_colours()
{
    local local_colors fg_color bg_color columns count=0
    local_colors="$(display_count complete)"
    show_header 0 "${SCRIPT_TITLE}" "Complete Mode with ${local_colors} of ${ncolors} colours"
    columns="$(grid_columns "${COMPLETE_CELL_WIDTH}")"

    for ((fg_color = 0; fg_color < local_colors; fg_color++)); do
        for ((bg_color = 0; bg_color < local_colors; bg_color++)); do
            count=$((count + 1))
            printf '%s F:%3s B:%3s %s' \
                "${bg_codes[bg_color]}${fg_codes[fg_color]}" \
                "${fg_color}" "${bg_color}" "${reset}"
            printf '%s F:%3s B:%3s %s' \
                "${bold}${bg_codes[bg_color]}${fg_codes[fg_color]}" \
                "${fg_color}" "${bg_color}" "${reset}"
            if (( count % columns == 0 )); then
                printf '%s\n' "${reset}"
            fi
        done
    done
    if (( count % columns != 0 )); then
        printf '%s\n' "${reset}"
    fi
    show_footer
}

read_colour_code()
{
    local prompt="$1"
    local value=""
    while true; do
        if ! read -r -p "${prompt}" value; then
            printf '\nAborted\n' >&2
            exit 1
        fi
        if [[ "${value}" =~ ^[[:digit:]]+$ ]] && \
            [[ "${value}" -ge 0 ]] && \
            [[ "${value}" -le "${max_code}" ]]; then
            REPLY_COLOUR="${value}"
            return 0
        fi
        show_error "Enter a number between 0-${max_code}"
    done
}

test_mode()
{
    local fg_color bg_color done=false reply=""
    show_header 1 "${SCRIPT_TITLE}" "Test Mode with ${ncolors} colours supported"

    while [[ "${done}" == false ]]; do
        read_colour_code "Enter a foreground colour code (0-${max_code}): "
        fg_color="${REPLY_COLOUR}"
        read_colour_code "Enter a background colour code (0-${max_code}): "
        bg_color="${REPLY_COLOUR}"

        printf '\t%sThis is what your colours will look like%s\n' \
            "${bg_codes[bg_color]}${fg_codes[fg_color]}" "${reset}"
        printf '\t%sThis is what your colours will look like with bold text%s\n' \
            "${bold}${bg_codes[bg_color]}${fg_codes[fg_color]}" "${reset}"

        while true; do
            if ! read -r -n 1 -p "Would you like to run another test (y/n) ? " reply; then
                printf '\nAborted\n' >&2
                exit 1
            fi
            printf '\n'
            if [[ "${reply}" =~ ^[Nn]$ ]]; then
                done=true
                break
            elif [[ "${reply}" =~ ^[Yy]$ ]]; then
                break
            fi
            echo "Please enter Y or N"
        done
    done
    show_footer
}

usage()
{
    local rc="${1:-1}"
    cat <<EOF

  Usage: $0 [ -h ] [ -V ] [ -cnst ] [ -m number ]

    -h    : Print this screen
    -V    : Print the version and exit
    -c    : complete mode (foreground & background)
    -m    : maximum number of colours to display (1-${ncolors:-N})
    -n    : display just the number of supported colours
    -s    : simple mode (background swatches)
    -t    : test mode (prompt for two colour codes)

    Colour codes are 0-$((${ncolors:-8} - 1)). -c, -n, -s and -t are exclusive.
    Complete mode without -m caps at ${COMPLETE_DEFAULT_CAP} colours when more
    are available.

EOF
    exit "${rc}"
}

main()
{
    local mode="" arg
    LIMITED_MODE=false
    limited_colors=0
    ncolors=""
    max_code=0
    red=""
    bold=""
    cls=""
    reset=""
    screen_width=80
    fg_codes=()
    bg_codes=()

    trap control_c SIGINT
    trap control_c SIGTERM

    while getopts ":hcnstm:V" arg; do
        case "${arg}" in
            h)
                mode="help"
                ;;
            V)
                get_version
                exit 0
                ;;
            m)
                LIMITED_MODE=true
                limited_colors="${OPTARG}"
                ;;
            c)
                if [[ -n "${mode}" && "${mode}" != "help" ]]; then
                    usage 1
                fi
                mode="complete"
                ;;
            n)
                if [[ -n "${mode}" && "${mode}" != "help" ]]; then
                    usage 1
                fi
                mode="count"
                ;;
            s)
                if [[ -n "${mode}" && "${mode}" != "help" ]]; then
                    usage 1
                fi
                mode="simple"
                ;;
            t)
                if [[ -n "${mode}" && "${mode}" != "help" ]]; then
                    usage 1
                fi
                mode="test"
                ;;
            :)
                probe_ncolors
                show_error "Option -${OPTARG} requires an argument."
                usage 1
                ;;
            \?)
                probe_ncolors
                show_error "Invalid option: -${OPTARG}"
                usage 1
                ;;
        esac
    done

    if [[ "${mode}" == "help" ]]; then
        probe_ncolors
        usage 0
    fi

    if [[ -z "${mode}" ]]; then
        mode="simple"
    fi

    probe_ncolors

    if [[ "${LIMITED_MODE}" == true ]]; then
        if [[ ! "${limited_colors}" =~ ^[[:digit:]]+$ ]] || \
            [[ "${limited_colors}" -lt 1 ]] || \
            [[ "${limited_colors}" -gt "${ncolors}" ]]; then
            show_error "You must specify a number between 1-${ncolors}"
            usage 1
        fi
    fi

    if [[ "${mode}" == "count" ]]; then
        if [[ "${LIMITED_MODE}" == true ]]; then
            printf 'Note: -m is ignored with -n\n' >&2
        fi
        show_colour_count
        return 0
    fi

    require_display

    case "${mode}" in
        complete)
            show_complete_colours
            ;;
        simple)
            show_simple_colours
            ;;
        test)
            test_mode
            ;;
        *)
            usage 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    main "$@"
fi
