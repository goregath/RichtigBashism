#!/usr/bin/env bash

[[ -n ${__LIB_LOGGER__+x} ]] && return 0
__LIB_LOGGER__=y

echo include logger

set_colors() {
	# usage tag=<TAG> log <LEVEL> <MSG>
	# set colors if available
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

shopt -s checkwinsize
set_colors