#!/usr/bin/env bash

export LC_ALL=C

if [[ -e "$0" ]]; then
	exe=$(basename $0)
else
	exe=calendar
fi

DB_BASE_DIR=~/.thunderbird/ivloaq67.default/calendar-data
UDAY_S=86400

REG_YEAR="[1-9][0-9]{3}\.(0[1-9]|1[0-2])\.([0-2][0-9]|3[0-1])"
REG_STR="[fl]o[dwmy]"
REG_OFFSET="[+-][1-9][0-9]*[dwmy]?"
REG_LENGTH="[+-]?[1-9][0-9]*[dwmy]?"

OFFSET_DEFAULT="+0"
LENGTH_DEFAULT="+1"

begin_ns=0           # Do 01. Jan 00:00:00 UTC 1970
end_ns=253402210800000000 # Fr 31. Dez 00:00:00 UTC 9999
raw=1

# combine multiple tags by array
TAG_IMPORT=( IMPORT )
TAG_ENV=( ENV )

shopt -s checkwinsize

set_colors() {
	# usage tag=<TAG> log <LEVEL> <MSG>
	# set colors if available
	if [[ -t 1 ]]; then
		case "$TERM" in
			xterm* ) ;&
			rxvt* )
				local tput="tput -T${TERM}"
				local ncolors=$($tput colors)
				$tput cols >/dev/null
				if (( ncolors >= 8 )); then
					MOD_REV="$($tput rev)"
					MOD_BLD="$($tput bold)"
					MOD_UDL="$($tput smul)"
					MOD_STO="$($tput smso)"
					MOD_RST="$($tput sgr0)"
					CLR_BLK="$($tput setaf 0)"
					CLR_RED="$($tput setaf 1)"
					CLR_GRN="$($tput setaf 2)"
					CLR_YLW="$($tput setaf 3)"
					CLR_BLU="$($tput setaf 4)"
					CLR_MGT="$($tput setaf 5)"
					CLR_CYN="$($tput setaf 6)"
					CLR_WHT="$($tput setaf 7)"
					_ANSI_CTRL=( 
						$(printf '%b' \
						"$MOD_REV"'\0\0'"$MOD_BLD"'\0\0'\
						"$MOD_UDL"'\0\0'"$MOD_STO"'\0\0'\
						"$MOD_RST"'\0\0'\
						"$CLR_BLK"'\0\0'"$CLR_RED"'\0\0'\
						"$CLR_GRN"'\0\0'"$CLR_YLW"'\0\0'\
						"$CLR_BLU"'\0\0'"$CLR_MGT"'\0\0'\
						"$CLR_CYN"'\0\0'"$CLR_WHT" \
						| hexdump -ve '1/1 "%.2X"'\
						| sed -e 's/0000/ /g')
					)
				fi
				;;
		esac
	fi
}

log() {
	local _tag args i=$# ll=1 mi=2 rd=1
	for (( ; i > 0; --i )); do
		if [[ "${!i}" == '--' ]]; then
			ll=$((i+1))
			mi=$((i+2))
			local el=$((i-1))
			args=${@:1:$el}
			break
		fi
	done

	local ansi_ctl lvl="${!ll^^}" out prefix
	case "$lvl" in
		DEBUG )  rd=2;                                 ;;
		ERR*  )  rd=2; ansi_ctl="${MOD_BLD}${CLR_RED}" ;;
		INFO* )  rd=2; ansi_ctl="${MOD_BLD}${CLR_CYN}" ;;
		WARN* )  rd=2; ansi_ctl="${MOD_BLD}${CLR_YLW}" ;;
		*     )        ansi_ctl="${MOD_BLD}${CLR_WHT}" ;;
	esac
	if [[ -n ${tag+x} ]]; then
		_tag=TAG_${tag^^}
		if [[ -n ${!_tag+x} ]]; then
			_tag=${_tag}[*]
			_tag=( ${!_tag} )
			_tag="$(printf '[%s] ' "${_tag[@]}")"
		else
			unset _tag
		fi
	fi
	prefix="[${lvl}] "
	out="${ansi_ctl}${prefix}${_tag}${MOD_RST}${*:$mi}"

	while read out; do
		local nctl nesc nout
		nout=${#out}
		nesc=$(
			hd="$(hexdump -ve '1/1 "%.2X"' <<<"$out")"
			for m in ${_ANSI_CTRL[*]}; do
				hd="${hd//$m/}"
			done
			str="$(xxd -r -p <<<"$hd")"
			echo "${#str}"
		)
		nctl=$(( nout - nesc ))

		exec 99>&$rd
		if [[ -n ${COLUMNS+x} ]] && (( ( nout - nctl ) > $COLUMNS )); then
			echo $args "${out:0:$((COLUMNS+nctl-3))} ${MOD_BLD}${CLR_GRN}${MOD_REV}>|${MOD_RST}" >&99
		else
			echo $args "$out" >&99
		fi
	done <<<"$out"
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
	          Second form: (f|l)o(d|w|m|y)
	$(table_csv <<< '
		        ;Day  ;Week ;Month;Year 
		First of;fod  ;fow  ;fom  ;foy  
		Last of ;lod  ;low  ;lom  ;loy  
	' | indent 10)
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
set_colors

for (( o=1,a=2; o < $# + 1; ++o,a=o+1 )); do
	opt="${!o}"
	arg="${!a}"
	case ${opt} in
		-h|--help )
				help 0
			;;
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
					echo matched
					pivot_date="${BASH_REMATCH[1]}"
					# date -d '20190401 00:00:01.99'
					# lod: date -d "$(date +%Y%m%d) -1 second +1 day" "+%Y%m%d %H:%M:%S"
					# fow: date -d "$(date -d yesterday +%u) days ago" +%Y%m%d
					# lom: date -d "$(date +%Y%m01) -1 second +1 month" +%Y%m%d
					case $pivot_date in
						fom )
							
							;;
					esac
					offset="${BASH_REMATCH[4]:-"$OFFSET_DEFAULT"}"
					length="${BASH_REMATCH[5]:1}"
					length="${length:-$LENGTH_DEFAULT}"
					begin_ns="$(date -d "${pivot_date} $(parse_spec $offset)" +%s)000000"
					end_ns="$(date -d "${pivot_date} $(parse_spec $offset) $(parse_spec $length) -1 second" +%s)999999"
					# [[ "$1" =~ ^([fl])o([dwmy])$ ]]; then
					# local at unit
					# at="${BASH_REMATCH[1]}"
					# unit="${BASH_REMATCH[2]}"
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
log INFO veryloooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong line
log INFO veryloooooooooooooooooooooooooooooooooooooooooo$'\n'oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong$'\n'lineeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee

get_events ${DB_BASE_DIR}/{cache,local}.sqlite | process