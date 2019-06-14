#!/usr/bin/env bash

## Module: Web utils
##
## @file
## @author              Oliver Zimmer <Oliver.Zimmer@e3dc.com>
## @date                2019-05-22 12:44:07
##
## Last Modified time:  2019-06-14 13:19:48
## Last Modified by:    GoreGath

[[ -n ${__LIB_WEB__:+x} ]] && return 0
export __LIB_WEB__=y

## Echo description for Http status code.
##
## ### Example
##
## ~~~{sh}
##     http_status_str 404
##     # Not Found
## ~~~
## @fn http_status_str()
##
## @param code Http status code
##
## @return 0
http_status_str() {
	local code=$1 descr
	case "$code" in
		100 ) descr="Continue" ;;
		101 ) descr="Switching Protocols" ;;
		200 ) descr="OK" ;;
		201 ) descr="Created" ;;
		202 ) descr="Accepted" ;;
		203 ) descr="Non-Authoritative Information" ;;
		204 ) descr="No Content" ;;
		205 ) descr="Reset Content" ;;
		206 ) descr="Partial Content" ;;
		300 ) descr="Multiple Choices" ;;
		301 ) descr="Moved Permanently" ;;
		302 ) descr="Found" ;;
		303 ) descr="See Other" ;;
		304 ) descr="Not Modified" ;;
		305 ) descr="Use Proxy" ;;
		307 ) descr="Temporary Redirect" ;;
		400 ) descr="Bad Request" ;;
		401 ) descr="Unauthorized" ;;
		402 ) descr="Payment Required" ;;
		403 ) descr="Forbidden" ;;
		404 ) descr="Not Found" ;;
		405 ) descr="Method Not Allowed" ;;
		406 ) descr="Not Acceptable" ;;
		407 ) descr="Proxy Authentication Required" ;;
		408 ) descr="Request Timeout" ;;
		409 ) descr="Conflict" ;;
		410 ) descr="Gone" ;;
		411 ) descr="Length Required" ;;
		412 ) descr="Precondition Failed" ;;
		413 ) descr="Request Entity Too Large" ;;
		414 ) descr="Request-URI Too Long" ;;
		415 ) descr="Unsupported Media Type" ;;
		416 ) descr="Requested Range Not Satisfiable" ;;
		417 ) descr="Expectation Failed" ;;
		500 ) descr="Internal Server Error" ;;
		501 ) descr="Not Implemented" ;;
		502 ) descr="Bad Gateway" ;;
		503 ) descr="Service Unavailable" ;;
		504 ) descr="Gateway Timeout" ;;
		505 ) descr="HTTP Version Not Supported" ;;
	esac
	if [[ -n ${descr+x} ]]; then
		code+=" (${descr})"
	fi
	echo -n "$code"
}