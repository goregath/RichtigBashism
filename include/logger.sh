#!/usr/bin/env bash

## Module: Advanced (colorized) logger utils
##
## @file
## @author              Oliver Zimmer <Oliver.Zimmer@e3dc.com>
## @date                2019-05-22 10:36:37
##
## Last Modified time:  2019-05-24 19:49:36
## Last Modified by:    GoreGath

[[ -n ${__LIB_LOGGER__+x} ]] && return 0
__LIB_LOGGER__=y
__LIB_LOGGER_LVLS_="ERROR WARN INFO DEBUG"

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
## @depends hexdump (bsdmainutils)
## @depends tput (ncurses-bin)
##
## @return undefined
__set_colors__() {
	if [[ -t 1 ]]; then
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

## Set all levels in descending order.
## @fn set_log_levels_desc()
##
## @param ... Levels in descending order
##
## @return 0
set_log_levels_desc() {
	__LIB_LOGGER_LVLS_="$@"
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
## @depends hexdump (bsdmainutils)
## @depends xxd (vim-common)
##
## @param level Logging level
## @param ... Message args, each argument is printed as a new log line 
##
## @return undefined
##
## @see set_log_levels_desc
log() {
	local _tag args i=$# ll=1 mi=2 rd=1
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

	local ansi_ctl lvl="${!ll^^}" out prefix

	if [[ -n ${LOG_LEVEL:+x} ]] \
		&& ! [[ $LOG_LEVEL == $lvl ]] \
		&& ! [[ "${__LIB_LOGGER_LVLS_%"${LOG_LEVEL}"*}" =~ "$lvl " ]]
	then
		# skip log if lvl is lower than LOG_LEVEL
		return
	fi


	case "$lvl" in
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
			_tag="$(printf '[%s] ' "${_tag[@]}")"
		else
			unset _tag
		fi
	fi

	for (( i = mi; i < ${#@} + 1; i++ )); do
		prefix="[${lvl}] "
		out="${ansi_ctl}${prefix}${_tag}${MOD_RST}${!i}"
		while IFS= read -r out; do
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
	done
}

shopt -s checkwinsize
__set_colors__