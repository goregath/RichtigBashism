#!/usr/bin/env bash

## Module: Script lifecycle utils
##
## @file
## @author              Oliver Zimmer <Oliver.Zimmer@e3dc.com>
## @date                2019-05-22 12:44:47
##
## Last Modified time:  2020-07-08 14:31:58
## Last Modified by:    e3dc

# Copyright © 2019 github.com/goregath
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file or http://www.wtfpl.net/ 
# for more details.

[[ -n ${__LIB_EXECUTION__:+x} ]] && return 0
export __LIB_EXECUTION__=y

## This function should be called right before the shell will exit.
## Its main purpose is to perform cleanup tasks.
## 
## @fn on_exit()
##
## @remark It's a trap (e.g. `trap on_exit EXIT`)
## @remark This function is designed to work with shell errexit flag (`set -e`)
##
## @return undefined
##
## @see __setup__()
on_exit() {
	trap 'on_error "${BASH_SOURCE:-unknown}" $- $? $LINENO "<unkown>"'  ERR
	if [[ ${__LIB_EXECUTION_CONFIRM_ON_EXIT_:-x} == y ]]; then
		log INFO "press enter to exit"
		read || :
	fi
	if [[ "$(LC_ALL=C type -t execution::teardown)" == 'function' ]]; then
		execution::teardown
	else
		log WARN 'missing execution::teardown()'
	fi
}

## Print error summary for a previously failed command.
##
## @remark It's a trap (e.g. `trap on_error ERR`)
##
## @remark This function is designed to work with shell error flags (`set -eE`)
##
## Example (debug):
## ~~~{sh}
##     [ERROR] [lib.sh]: "false" on line 7 failed with 1 [ehBE]
##     [INFO] trace log:
##       fail             [lib.sh:7]
##       worker           [lib.sh:3]
##       do_work          [test.sh:186]
##       main             [test.sh:217]
##     [DEBUG] Bourne shell options:
##       braceexpand           on
##       errtrace              on
##       hashall               on
##       interactive-comments  on
##       pipefail              on
##     [DEBUG] Bash options:
##       cmdhist               on
##       complete_fullquote    on
##       extglob               on
##       extquote              on
##       force_fignore         on
##       hostcomplete          on
##       interactive_comments  on
##       progcomp              on
##       promptvars            on
##       sourcepath            on
##     [DEBUG] current directory: scripts
##     [DEBUG] machine: i686-pc-linux-gnu
##     [DEBUG] bash: 4.3.11(1)-release
## ~~~
##
## @depends
##   @ref bin_grep
## , @ref bin_column (bsdmainutils, optional)
## , @ref bin_sed
##
## @fn on_error()
##
## @param source  Source file of error
## @param flags   Shell flags as set by command `set`
## @param code    Return code of failed command
## @param line    Line of error in source file
## @param command Command that caused the error
##
## @param[out] stderr Caller stack and debug output to logger
##
## @return undefined
##
## @see __setup__()
on_error() {
	local TAG_PID source flags code line command msg= dump=
	source="$1"
	flags="$2"
	code="$3"
	line="$4"
	command="$5"
	TAG_PID=( $$ ${BASHPID/#$$/} )
	if ! hash column >/dev/null 2>&1; then
		column() { cat; }
	fi
	if ! hash sed >/dev/null 2>&1; then
		sed() { cat; }
	fi
	for (( f=1, l=0; f < ${#FUNCNAME[@]}; f++,l++ )); do
		printf -v dump '\n  %-24s [%s]' "${FUNCNAME[$f]:-unknown}" "${BASH_SOURCE[$f]:-unknown}:${BASH_LINENO[$l]:-0}"
		msg+="$dump"
	done
	log TRACE "command failed:"$'\n'"$command" || :
	# tag=pid log ERROR "line $line failed with $code [$flags]${msg}"
	tag=pid log DEBUG "$source:$line failed with $code [$flags] in ${FUNCNAME[1]:-main}${msg}"
	msg="$(set -o | grep 'on$' | column -t | sed 's/^/  /')"
	log TRACE "Bourne shell options:"$'\n'"${msg}"
	msg="$(shopt | grep 'on$' | column -t | sed 's/^/  /')"
	log TRACE "Bash options:"$'\n'"${msg}"
	log TRACE "current directory: $PWD"
	log TRACE "machine: $MACHTYPE"
	log TRACE "bash: $BASH_VERSION"
}

execution::set_confirm_on_exit() {
	export __LIB_EXECUTION_CONFIRM_ON_EXIT_=y
}

## Setup shell environment and perform checks.
## @depends
##   execution::setup()
## @fn __setup__()
##
## @return undefined
__setup__() {
	if [[ $(LC_ALL=C type -t log) != 'function' ]]; then
		log() { echo "$@"; }
	fi
	# allows up to 100 nested functions, limits recursion
	FUNCNEST=100
	trap 'on_error "${BASH_SOURCE[0]:-main}" $- $? ${LINENO:-0} "'\''${BASH_COMMAND:-unknown}'\''"' ERR
	trap 'on_exit' EXIT
	set -o pipefail
	shopt -s extglob
	set -B # The shell will perform brace expansion.
	set -e # Exit immediately if a command exits with a non-zero status.
	set -E # If set, the ERR trap is inherited by shell functions.
	set -h # Remember the location of commands as they are looked up.
	set +m # Job control is enabled.
	set +u # Treat unset variables as an error when substituting.
	set +v # Print shell input lines as they are read.
	if [[ -n ${-//[^x]/} ]]; then
		export DEBUG=true
	fi
	if [[ "$(LC_ALL=C type -t execution::setup)" == 'function' ]]; then
		execution::setup
	else
		log WARN 'missing execution::setup()'
	fi
}

__setup__