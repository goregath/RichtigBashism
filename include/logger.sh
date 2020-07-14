#!/usr/bin/env bash

## Module: Advanced (colorized) logger utils
##
## @file
## @author              Oliver Zimmer <Oliver.Zimmer@e3dc.com>
## @date                2019-05-22 10:36:37
##
## Last Modified time:  2020-07-06 08:35:56
## Last Modified by:    e3dc
## 
## @defgroup liblog Extended logging library
## 
## @addtogroup liblog
## @{

# Copyright © 2019 github.com/goregath
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file or http://www.wtfpl.net/ 
# for more details.

[[ -n ${__LIB_LOGGER__:+x} ]] && return 0
declare -x __LIB_LOGGER__
export __LIB_LOGGER__=y

declare __LIB_LOGGER_LVLS_="ERROR WARN INFO DEBUG TRACE ALL"
declare -i __LIB_LOGGER_LVLS_WIDTH=5

if ! hash tput >/dev/null 2>&1; then
	echo "[WARN] unable to fully setup logger: missing tput" >&2
fi

# tput() {
# 	/usr/bin/tput "$@"
# }

## Encode character sequence to hex.
## @fn logger::encode()
##
## @param str String to encode
##
## @param[out] stdout The encoded string
##
## @return undefined
logger::encode() {
	local LC_ALL=C
	while (( ${#} > 0 )); do
		for (( i = 0; i < ${#1}; i++ )); do
			printf '%%%02X' "'${1:i:1}"
		done
		shift
	done
}

## Encode hex to character sequence.
## @fn logger::decode()
##
## @param hex The hex string
##
## @param[out] stdout The decoded string
##
## @return undefined
logger::decode() {
	while (( ${#} > 0 )); do
		printf '%b' "${1//%/\\x}"
		shift
	done
}

## If possible set color sequences to tags.
## Supported tags are:
##   - MOD_REV
##   - MOD_BLD
##   - MOD_UDL
##   - MOD_STO
##   - MOD_RST
##   - CLR_BLK
##   - CLR_RED
##   - CLR_GRN
##   - CLR_YLW
##   - CLR_BLU
##   - CLR_MGT
##   - CLR_CYN
##   - CLR_WHT
## @fn __set_colors__()
## @depends tput (ncurses-bin)
##
## @return undefined
__set_colors__() {
	if [[ -t 1 ]] && hash tput >/dev/null 2>&1; then
		case "$TERM" in
			xterm* ) ;&
			rxvt* )
				local tput="tput -T ${TERM}"
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
						$(logger::encode \
							"$MOD_REV" %20 "$MOD_BLD" %20 \
							"$MOD_UDL" %20 "$MOD_STO" %20 \
							"$MOD_RST" %20 \
							"$CLR_BLK" %20 "$CLR_RED" %20 \
							"$CLR_GRN" %20 "$CLR_YLW" %20 \
							"$CLR_BLU" %20 "$CLR_MGT" %20 \
							"$CLR_CYN" %20 "$CLR_WHT")
					)
				fi
				;;
		esac
	fi
}

## Unset all color codes
## @fn __unset_colors__()
##
## @see __set_colors__
## @return 0
__unset_colors__() {
	MOD_REV=
	MOD_BLD=
	MOD_UDL=
	MOD_STO=
	MOD_RST=
	CLR_BLK=
	CLR_RED=
	CLR_GRN=
	CLR_YLW=
	CLR_BLU=
	CLR_MGT=
	CLR_CYN=
	CLR_WHT=
	_ANSI_CTRL=( )
}

## Set all levels in descending order.
## @fn set_log_levels_desc()
##
## @param ... Levels in descending order
##
## @return 0
logger::set_log_levels_desc() {
	__LIB_LOGGER_LVLS_WIDTH=1
	local -i w=1
	__LIB_LOGGER_LVLS_="$@"
	while (( $# )); do
		(( w = ( ${#1} > w ? ${#1} : w) ))
		shift
	done
	__LIB_LOGGER_LVLS_WIDTH=$w
}

## @fn logger::enable_column_mode()
## @return undefined
logger::enable_column_mode()  {
	shopt -s checkwinsize
	if hash tput >/dev/null 2>&1; then
		tput cols >/dev/null
	fi
}

## @fn logger::disable_column_mode()
## @return undefined
logger::disable_column_mode() {
	shopt -u checkwinsize
	unset COLUMNS
}

## @fn logger::enable_color_mode()
## @return undefined
logger::enable_color_mode()  {
	__set_colors__
}

## @fn logger::disable_color_mode()
## @return undefined
logger::disable_color_mode() {
	__unset_colors__
}

## Advanced logger with colors if supported by terminal.
##
## All known levels share the same output stream (`STDERR`) by default.
## The messages for "DEBUG" are only printed if the varaiable `DEBUG` is 
## defined (the value is negligible). The levels "INFO", "WARN" and "ERROR" 
## are colorized accordingly.
##
## This logger supports multiple custom tags by assigning a qualified name 
## to the variable `tag`. If a corresponding variable `TAG_<tag>` is defined, 
## the content is split into words and appended to the log level.
##
## ### Example 1
## Tags are supported
## ~~~{sh}
##     TAG_URGENT=( "Main" "Urgent" )
##     tag=urgent log WARN message
##     # [WARN] [Main] [Urgent] message
## ~~~
##
## ### Example 2 
## Each message argument is a new log message
## ~~~{sh}
##     log INFO 'line 1' 'line 2' 'line 3'
##     # [INFO] line 1
##     # [INFO] line 2
##     # [INFO] line 3
## ~~~
##
## ### Example 3 
## Line overflows will be truncated (if `COLUMNS` is defined).
## The coulmns are set at startup by calling `shopt -s checkwinsize`.
## ~~~{sh}
##     echo $COLUMNS
##     # 80
##     log INFO 'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.'
##     # [INFO] Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonu >|
## ~~~
## @fn log()
##
## @param level Logging level
## @param ... Message args, each argument is printed as a new log line 
##
## @return undefined
##
## @see set_log_levels_desc
log() {
	trap '' DEBUG
	local _tag= args= i=$# ll=1 mi=2 rd=1
	# supported levels in order of importance (desc)
	for (( ; i > 0; --i )); do
		if [[ "${!i}" == '--' ]]; then
			ll=$((i+1))
			mi=$((i+2))
			local el=$((i-1))
			args=${@:1:$el}
			break
		fi
	done

	local ansi_ctl= lvl="${!ll^^}" out prefix

	if [[ -n ${LOG_LEVEL:+x} ]] \
		&& ! [[ $LOG_LEVEL == $lvl ]] \
		&& ! [[ "${__LIB_LOGGER_LVLS_%"${LOG_LEVEL}"*}" =~ "$lvl " ]]
	then
		# skip log if lvl is lower than LOG_LEVEL
		return 0
	fi

	case "${lvl^^}" in
		DEB*  )  rd=2; ;;
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
			_tag="$(printf '[ %s ] ' "${_tag[@]}")"
		else
			_tag+=' '
		fi
	fi

	case "${LOG_LEVEL:-x}" in
		DEBUG|TRACE|ALL )
			: "${FUNCNAME[*]}"
			: "${_#log* }"
			: "${_#log* }"
			: "${_%% *}"
			_tag+="$_: ";
			;;
	esac

	for (( i = mi; i < ${#@} + 1; i++ )); do
		if [[ -z ${!i:+x} ]]; then
			continue
		fi
		printf -v prefix '[%s%-'$__LIB_LOGGER_LVLS_WIDTH's%s] ' ' ' "$lvl" ' '
		out="${ansi_ctl}${prefix}${_tag}${MOD_RST}${!i}"
		while IFS= read -r out; do
			local nctl nout
			nout=${#out}
			if [[ ${#_ANSI_CTRL[@]} != 0 ]]; then
				local nesc
				nesc=$(
					hd="$(logger::encode "$out")"
					for m in ${_ANSI_CTRL[*]}; do
						hd="${hd//$m/}"
					done
					str="$(logger::decode "$hd")"
					echo "${#str}"
				)
				nctl=$(( nout - nesc ))
			else
				nctl=0
			fi

			exec 99>&$rd
			if [[ -n ${COLUMNS+x} ]] && (( ( nout - nctl ) > $COLUMNS )); then
				echo $args "${out:0:$((COLUMNS+nctl-3))} ${MOD_BLD}${CLR_GRN}${MOD_REV}>|${MOD_RST}" >&99
			else
				echo $args "$out" >&99
			fi
		done <<<"$out"
	done
}

## Wrapper for function `log` to accept lines from stdin.
## @fn log_stdin()
##
## @param level Logging level
##
## @see log
## @return undefined
log_stdin() {
	while IFS= read -r l0 l1 l2 l3 l4 l5 l6 l7; do
		log "$1" "$l0" "$l1" "$l2" "$l3" "$l4" "$l5" "$l6" "$l7"
	done
}

export -f log log_stdin

logger::set_log_levels_desc "ERROR" "WARN" "INFO" "DEBUG" "TRACE" "ALL"
logger::disable_column_mode
logger::disable_color_mode

## @}