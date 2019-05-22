#!/usr/bin/env bash

export LC_ALL=C

if [[ -e "$0" ]]; then
	exe=$(basename $0)
else
	exe=calendar
fi

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

DB_BASE_DIR=~/.thunderbird/ivloaq67.default/calendar-data
UDAY_S=86400

REG_YEAR="[1-9][0-9]{3}\.(0[1-9]|1[0-2])\.([0-2][0-9]|3[0-1])"
REG_STR="fo[wmy]"
REG_OFFSET="[+-][1-9][0-9]*[dwmy]?"
REG_LENGTH="[+-]?[1-9][0-9]*[dwmy]?"

OFFSET_DEFAULT="+0"
LENGTH_DEFAULT="+1"

begin_ns=0           # Do 01. Jan 00:00:00 UTC 1970
end_ns=253402210800000000 # Fr 31. Dez 00:00:00 UTC 9999
raw=1

# combine multiple tags by array
TAG_IMPORT=( IMPORT )
TAG_SRC=( SRC )
TAG_ENV=( ENV )

include() {
	search() {
		local src is_included=1
		while read -r src; do
			if source "$src/$lib" 2>/dev/null; then
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
	search <<-SOURCES
		.
		${SCRIPTPATH}
		${BASH_INCLUDES//:/$nl}
	SOURCES
}

# Day;Week;Month;Year
# First of;fod;fow;fom;foy
# Last of;lod;low;lom;loy
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

indent() {
	sed -e 's/^/'"$(printf "%${1:-2}s")"'/'
}

help() {
	cat >&2 <<-HLP
	$exe [-d [DATE][OFFSET]:LENGTH] [-h]
	  -d, --date    Query calendar around this date. 
	                Defaults to today
	  -h, --help    Display this message and exit

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

	EXAMPLES:
	  Query events starting one month before and after a date
	  \$ $exe -d 2020.01.01-1m:2m

	  Query events for one weak starting at a date
	  \$ $exe -d 2019.03.01:1w
	HLP
	exit "${1}"
}

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

to_day_s() {
	date -d "$(date -d @${!1} +%Y%m%d)" +%s
}

to_date() {
	date -d @${!1} +%d.%m.%Y
}

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

include include/execution.sh
include include/logger.sh

for (( o=1,a=2; o < $# + 1; ++o,a=o+1 )); do
	opt="${!o}"
	arg="${!a}"
	case ${opt} in
		-h|--help ) ;;
		-f|--format )
				case $arg in
					yad ) process() { process_db_out; }; ((o++)) ;;
					raw ) process() { cat; }; get_events() { read_db "$@"; }; ((o++)) ;;
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
					echo "${BASH_REMATCH[@]}"
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
				help 1
			;;
	esac
done

log INFO "BEGIN: $(date -d @"$((begin_ns / 1000000))")" >&2
log INFO "END:   $(date -d @"$((end_ns / 1000000))")" >&2

get_events ${DB_BASE_DIR}/{cache,local}.sqlite | process