#!/usr/bin/env bash

# Copyright © 2019 github.com/goregath
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file or http://www.wtfpl.net/ 
# for more details.

declare -x LC_ALL=C

if [[ -e "$0" ]]; then
	exe=$(basename $0)
else
	exe=calendar
fi

declare -x LOG_LEVEL=${LOG_LEVEL:-ERROR}

declare -r LENGTH_DEFAULT="+1"
declare -r OFFSET_DEFAULT="+0"
declare -r REG_LENGTH="[+-]?[1-9][0-9]*[dwmy]?"
declare -r REG_OFFSET="[+-][1-9][0-9]*[dwmy]?"
declare -r REG_STR="fo[wmy]"
declare -r REG_YEAR="[1-9][0-9]{3}\.(0[1-9]|1[0-2])\.([0-2][0-9]|3[0-1])"
declare -r SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
declare -r TAG_ENV=ENV
declare -r TAG_IMPORT=IMPORT
declare -r TAG_SRC=SRC
declare -r UDAY_S=86400


declare -i begin_ns=0                # Do 01. Jan 00:00:00 UTC 1970
declare -i end_ns=253402210800000000 # Fr 31. Dez 00:00:00 UTC 9999

declare    db_base_dir="$( b=( ~/.thunderbird/*/calendar-data ); echo -n ${b[0]} )"

## Sources library by path.
##
## The usage is analogous to a C-like preprocessor `#include`.
## The given path can either be absolute or relative. 
## If the path is relative, the file is then resolved in the following order:
##   1. Current working directory
##   2. Directory of script @ref SCRIPTPATH
##   3. All directories enumerated by @ref BASH_INCLUDES separated by `:` (colon).
## @fn include()
##
## @param path Path to library
##
## @return Error (!0) if include could not be resolved or failed to include
##
## @see SCRIPT_PATH
## @see BASH_INCLUDES
include() {
	search() {
		local src is_included=1
		while read -r src; do
			if [[ -s "$src/$lib" ]] && source "$src/$lib"; then
				tag=src log INFO "included $src/$lib"
				is_included=0
				break
			fi
		done
		return $is_included
	}
	local lib nl
	lib="$1"
	nl=$'\n'
	search "$1" <<-SOURCES

		.
		${SCRIPTPATH}
		${BASH_INCLUDES//:/$nl}
	SOURCES
}

table_csv() {
	local hdl top btm trm delim hd vd cr tcr bcr
	delim=';'
	vd='│'
	hd='─'
	cr='┼'
	tcr='┬'
	bcr='┴'
	column -t -s"$delim" -o" $vd " -c 32 | {
		IFS= read -r hdl
		top="${hdl//[^$vd]/$hd}"
		top="${top//$vd/$tcr}"
		btm="${hdl//[^$vd]/$hd}"
		btm="${btm//$vd/$cr}"
		trm="${hdl//[^$vd]/$hd}"
		trm="${trm//$vd/$bcr}"
		echo "┌─${top}─┐"
		echo "│ ${hdl} │"
		echo "├─${btm}─┤"
		while IFS= read -r rws; do
		echo "│ ${rws} │"
		done
		echo "└─${trm}─┘"
	}
}

## Indent stdin by n spaces
## @fn indent()
##
## @param n Number of spaces to prepend before each line. Default: 2
##
## @param[out] stdout Indentent output
##
## @return As defined by sed
indent() {
	sed -e 's/^/'"$(printf "%${1:-2}s")"'/'
}

## Trim leading and trailing whitespaces from variable.
##
## If a character is of the POSIX class _space_ it is considered as a whitespace.
## The POSIX character class _space_ is defined as `[ \t\n\r\f\v]`.
## @fn trim_var()
##
## @param name Name of variable
##
## @return undefined
trim_var() {
	local var="${!1}"
	local padl=${var%%[![:space:]]*}
	local padr=${var##*[![:space:]]}
	var="${var#$padl}"
	var="${var%$padr}"   
	eval "$1=\"${var}\""
}

## First trim leading and trailing whitespaces by calling @ref trim_var
## and then trim trailing "/" from variable.
## @fn trim_path_var()
##
## @param name Name of variable
##
## @return undefined
##
## @see trim_var
trim_path_var() {
	trim_var $1
	eval "$1=\"${!1%/}\""
}

## Display help text and exit.
## @fn help()
##
## @param code Exit code
##
## @param[out] stderr Help text
##
## @return undefined
help() {
	cat >&2 <<-HLP
	$exe [-b DIR] [-d [DATE][OFFSET]:LENGTH] [-f FMT] [-h]
	  -b, --database-root   Directory of calendar data.
	                        Defaults to \$HOME/.thunderbird/*/calendar-data
	  -d, --date            Query calendar around this date. 
	                        Defaults to today
	  -f, --format          Chose output format.
	  -h, --help            Display this message and exit.

	  DATE    First form:  YYYY.MM.DD
	          Second form: fo(w|m|y)
	$(table_csv <<< '
		        ;Week ;Month;Year 
		First of;fow  ;fom  ;foy  
	' | indent 10)
	          Note: First of week is defined as monday.

	  OFFSET  (-|+)NUM[UNIT]
	  LENGTH  [-|+]NUM[UNIT]
	  NUM     A signed integer
	  UNIT    y: Year, m: Month, w: Week, d: Day (default)

	FORMAT:
	  Supported formats are yad and raw (dash separated values).

	OUTPUT:
	  Each line on stdout contains a day with one or more events.
	  Events start with one of the following marker:

	    [HH:MM] Local time
	    [~]     Continuous event (multiple days)
	    [=]     Whole day

	EXAMPLES:
	  Query events starting one month before and after a date
	  \$ $exe -d 2020.01.01-1m:2m

	  Query events for one weak starting at a date
	  \$ $exe -d 2019.03.01:1w

	  Query events for current month
	  \$ $exe -d fom:1m
	HLP
	exit "${1}"
}

## Parse value string and convert to date (GNU date) arithmetics.
## @fn parse_spec()
##
## @param spac Value string, fmt.: [-|+]value[unit]
##
## @param[out] stdout Date operation
##
## @return 1 on invalid spec, else 0
parse_spec() {
	# [-|+]value[unit]
	if [[ -z ${1:+x} ]]; then
		log WARN "cannot parse empty argument spec"
		return 0
	fi
	if [[ "$1" =~ ^([+-]?)(0|[1-9][0-9]*)([dwmy]?)$ ]]; then
		local sign value unit
		sign="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		if (( value == 0 )); then
			return 0
		fi
		unit="${BASH_REMATCH[3]:-d}"
		case ${unit,,} in
			y ) echo "${sign:-+}${value} year" ;;
			m ) echo "${sign:-+}${value} month" ;;
			w ) echo "${sign:-+}${value} week" ;;
			d ) echo "${sign:-+}${value} day" ;;
			* ) log ERROR "invalid unit \"$unit\""; return 2 ;;
		esac
	else
		log ERROR "invalid argument \"$1\""
		return 1
	fi
}

## Get day in seconds from unix timestamp.
## @fn to_day_s()
##
## @param var_name Name of variable that holds the date in seconds
##
## @param[out] stdout Begin of day in seconds 
##
## @return As defined by date
to_day_s() {
	date -d "$(date -d @${!1} +%Y%m%d)" +%s
}

## Print date as DD.MM.YYYY .
## @fn to_date()
##
## @param var_name Name of variable that holds the date in seconds
##
## @param[out] stdout Date, fmt.: DD.MM.YYYY
##
## @return As defined by date
to_date() {
	date -d @${!1} +%d.%m.%Y
}

## Print time of day as HH:MM .
## @fn to_time()
##
## @param var_name Name of variable that holds the date in seconds
##
## @param[out] stdout Date, fmt.: HH:MM
##
## @return As defined by date
to_time() {
	date -d @${!1} +%H:%M
}

save_event() {
	date="$(to_day_s event_start_s)"
	ref_holder="${dates[$date]}"
	set -u
	if [[ -z ${ref_holder:+x} ]]; then
		create_ref # -> ref_holder
		dates["$date"]="$ref_holder"
	fi
	eval "${ref_holder}"'+=('"$(printf '%q' "$event")"')'
	set +u
}

create_ref() {
	local name="REF$(( ref_id++ ))"
	eval "$name"'=()'
	ref_holder="$name"
}

null_print() {
	for e in "${@}"; do
		printf "\0%s" "${e}"
	done
}

read_db() {
	for dbfile in "$@"; do
		sqlite3 "$dbfile" '
			SELECT title, event_start, event_end, event_stamp
				FROM cal_events 
			WHERE 
				event_start BETWEEN '$begin_ns' AND '$end_ns'
		'
	done
}

get_events() {
	local ref_id ref_holder new_ref dates
	local date title event events event_start_s event_end_s
	ref_id=0
	declare -A dates=()
	for (( i = 1; i < $#+1; i++ )); do
		while IFS='|' read -r -a event; do
			title="${event[0]}"
			event_start_s=${event[1]::-6}
			event_end_s=${event[2]::-6}
			if (( event_end_s == event_start_s )); then
				event="[=] ${title}"
				save_event
			elif (( (event_end_s - event_start_s) % UDAY_S )); then
				event="[$(to_time event_start_s)] ${title}"
				save_event
			else
				for (( ; event_start_s < event_end_s; event_start_s += UDAY_S )); do
					event="[~] ${title}"
					save_event
				done
			fi
		done < <( read_db "${!i}" )
	done
	for date in "${!dates[@]}"; do
		ref_holder="${dates[$date]}"
		declare -n events="$ref_holder"
		echo -n "${date}"
		null_print "${events[@]}" | sort -z | tr '\0' ' '
		echo
	done
}

process_db_out() {
	sort | \
	while read -r -a d; do
		day=${d[0]}
		echo "$(to_date day) ${d[*]:1}"
	done
}
process() { process_db_out; }

set -e
set -o pipefail

for (( o=1; o < $# + 1; ++o )); do
	opt="${!o}"
	case ${opt} in
		-h|--help )
				help 0
			;;
	esac
done

include include/logger.sh
include include/execution.sh

for (( o=1,a=2; o < $# + 1; ++o,a=o+1 )); do
	opt="${!o}"
	arg="${!a}"
	case ${opt} in
		-h|--help ) ;;
		-b|--database-root ) 
				trim_path_var arg
				if [[ -d "$arg" ]]; then
					db_base_dir="$arg"
				else
					log ERROR "$opt: invalid thunderbird directory"
					exit 1
				fi
				((o++))
			;;
		-f|--format )
				case $arg in
					yad ) process() { process_db_out; }; ((o++)) ;;
					raw ) process() { cat; }; get_events() { read_db "$@"; }; ((o++)) ;;
					* )
							log ERROR "$opt: invalid format"
							exit 1
						;;
				esac
			;;
		-d|--date )
				if [[ "$arg" =~ ^($REG_YEAR)?($REG_OFFSET)?(:$REG_LENGTH)?$ ]]; then
					pivot_date="${BASH_REMATCH[1]:-"$(date +%Y%m%d)"}"
					offset="${BASH_REMATCH[4]:-"$OFFSET_DEFAULT"}"
					length="${BASH_REMATCH[5]:1}"
					length="${length:-$LENGTH_DEFAULT}"
					begin_ns="$(date -d "${pivot_date//./} $(parse_spec $offset)" +%s)000000"
					end_ns="$(date -d "${pivot_date//./} $(parse_spec $offset) $(parse_spec $length) -1 second" +%s)999999"
					((o++))
				elif [[ "$arg" =~ ^($REG_STR)($REG_OFFSET)?(:$REG_LENGTH)?$ ]]; then
					# echo "${BASH_REMATCH[@]}"
					pivot_date="${BASH_REMATCH[1]}"
					case $pivot_date in
						fow )
								if [[ $(date +%u) == 1 ]]; then
									pivot_date="$(date +%Y%m%d)"
								else
									pivot_date="$(date -d "$(date -d yesterday +%u) days ago" +%Y%m%d)"
								fi
							;;
						fom ) pivot_date="$(date +%Y%m01)"; ;;
						foy ) pivot_date="$(date +%Y0101)"; ;;
					esac
					offset="${BASH_REMATCH[2]:-"$OFFSET_DEFAULT"}"
					length="${BASH_REMATCH[3]:1}"
					length="${length:-$LENGTH_DEFAULT}"
					begin_ns="$(date -d "${pivot_date} $(parse_spec $offset)" +%s)000000"
					end_ns="$(date -d "${pivot_date} $(parse_spec $offset) $(parse_spec $length) -1 second" +%s)999999"
					((o++))
				fi
			;;
		* )
				log ERROR "invalid option '$opt'"
				help 1
			;;
	esac
done

log INFO "BEGIN: $(date -d @"$((begin_ns / 1000000))")" >&2
log INFO "END:   $(date -d @"$((end_ns / 1000000))")" >&2

get_events ${db_base_dir}/{cache,local}.sqlite | process