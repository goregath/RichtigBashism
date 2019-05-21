#!/usr/bin/env bash

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
## @see setup()
on_exit() {
	trap 'on_error "$BASH_SOURCE" $- $? $LINENO "<unkown>"'  ERR
	log INFO "press enter to exit"
	read || :
	if [[ $(LC_ALL=C type -t teardown) == 'function' ]]; then
		teardown
	else
		log WARN 'missing teardown()'
	fi
	exit ${code}
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
## @depends grep
## @depends column (bsdmainutils)
## @depends sed
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
## @see setup()
on_error() {
	local source flags code line command msg= dump=
	source="$1"
	flags="$2"
	code="$3"
	line="$4"
	command="$5"
	if ! hash column >/dev/null 2>&1; then
		column() { cat -n; }
	fi
	if ! hash sed >/dev/null 2>&1; then
		sed() { cat; }
	fi
	log ERROR "[$source]: ${command} on line $line failed with $code [$flags]"
	for (( f=1, l=0; f < ${#FUNCNAME[@]}; f++,l++ )); do
		printf -v dump '\n  %-24s [%s]' "${FUNCNAME[$f]}" "${BASH_SOURCE[$f]}:${BASH_LINENO[$l]}"
		msg+="$dump"
	done
	log INFO "trace log:${msg}"
	msg="$(set -o | grep 'on$' | column -t | sed 's/^/  /')"
	log DEBUG "Bourne shell options:"$'\n'"${msg}"
	msg="$(shopt | grep 'on$' | column -t | sed 's/^/  /')"
	log DEBUG "Bash options:"$'\n'"${msg}"
	log DEBUG "current directory: $PWD"
	log DEBUG "machine: $MACHTYPE"
	log DEBUG "bash: $BASH_VERSION"
}

## Setup shell environment and perform checks.
## @fn __setup__()
##
## @return undefined
__setup__() {
	if [[ $(LC_ALL=C type -t log) != 'function' ]]; then
		log() { echo "$@"; }
	fi
	trap 'on_error "$BASH_SOURCE" $- $? $LINENO "\"$BASH_COMMAND\""' ERR
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
	if [[ $(LC_ALL=C type -t setup) == 'function' ]]; then
		setup
	else
		log WARN 'missing setup()'
	fi
}

__setup__