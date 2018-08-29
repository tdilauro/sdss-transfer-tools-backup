#!/bin/bash

####################################################################################################
# Various functions to make life easier
#
# Tim DiLauro <tim.dilauro@gmail.com>
####################################################################################################

# capture home directory for future function calls
PROGHOME=$( dirname $0 )
PROGNAME=${0##*/}
PROGPID=$$


#---------------------------------------------------------------------------------------------------
# Function: die
# Display error code and optional message, then exit with rc=1
#---------------------------------------------------------------------------------------------------
function die () { 
    local rc=$1; shift

    echo "$@ [rc=${rc}]" 1>&2
    exit 1
}


#---------------------------------------------------------------------------------------------------
# Function: warn
# Emit a message to STDERR
#---------------------------------------------------------------------------------------------------
function warn () {
    echo "$@" 1>&2
}


#---------------------------------------------------------------------------------------------------
# Log message function
# Log a message with date, program name, and process ID prepended.
# Requires isozdate()
# Parameters: <process id> <log string>
# Returns: log message string
#---------------------------------------------------------------------------------------------------
function log () {
    pid=$1; shift
    echo "$(isozdate) $PROGNAME [${pid}]: $@"
}



#---------------------------------------------------------------------------------------------------
# Local Config function
# Parameter: <package prefix>
#---------------------------------------------------------------------------------------------------
function PkgPrefixConfigFile () {
    local prefix=~/.sdss-packaging
    echo "${prefix}/$@"
}



#---------------------------------------------------------------------------------------------------
# Get Package Properties function
# Given a package name, extract properties from that name and lookup other associate properties.
# Those properties or dropped into the environment of the current shell as variables.
# Parameter: <package name>
# Error codes: (1) general errors (currently log messages are emitted); (2) invalid parameters
#---------------------------------------------------------------------------------------------------
# verify package name format and drop properties into the environment

function getPackageProperties () {
    # script expects one argument of the form "<prefix>-<seq>-of-<pkgcount>"
    if [[ ( $# == 1 ) && ( "$1" =~ '^([^/]+)-([0-9]+)-of-([0-9]+)$' ) ]]; then
        pkgPrefix=${BASH_REMATCH[1]}
	pkgCount=${BASH_REMATCH[3]}
	seqNum=$( PadNumberToMax "${BASH_REMATCH[2]}" "${pkgCount}" )
	pkgName="${pkgPrefix}-${seqNum}-of-${pkgCount}"
    else
	warn "${PROGNAME} - invalid argument(s): $@"
	warn "Usage: ${PROGNAME} <pkgprefix>-<sequence#>-of-<pkgcount>"
	return 2
    fi

    # Get custom configuration
    configFile=$( PkgPrefixConfigFile "${pkgPrefix}" )
    . ${configFile} || die $? $( log ${PROGPID} "${pkgName}: couldn't source config file \"${configFile}\"" )

    # check for some inconsistencies
    if [ "${numberOfPkgs}" -ne "${pkgCount}" ]; then
	log ${PROGPID} "${pkgName}: pkgCount (${pkgCount}) not equal to numberOfPkgs (${numberOfPkgs}) from config file \"${configFile}\""
	((errors++))
    elif [ "${seqNum}" -gt "${pkgCount}" ]; then
	log ${PROGPID} "${pkgName}: seqNum (${seqNum}) is greater than pkgCount (${pkgCount}) in pkgName \"${pkgName}\""
	((errors++))
    elif [ "${seqNum}" -lt 1 ]; then
	log ${PROGPID} "${pkgName}: seqNum (${seqNum}) cannot be less than one (1) in pkgName \"${pkgName}\""
	((errors++))
    fi
    if [ "${errors}" -gt 0 ]; then return 1; else return 0; fi
}



#---------------------------------------------------------------------------------------------------
# PadNumberToMax function
# Parameters: <number-to-pad> <max-number>
# Zero pad the <number-to-pad> up to the lenght of <max-number>
# NB: If <number-to-pad> is already longer than <max-number>, it will not be shortened.
#---------------------------------------------------------------------------------------------------
function PadNumberToMax () {
    local number=$(( 10#$1 + 0 ))
    local max=$2
    printf "%0${#max}d" "${number}";
}


#---------------------------------------------------------------------------------------------------
# Function: sedesc
# Escape characters with special meaning to the sed utility
# Probably should take a parameter for the 's' command pattern seperator (usually '/'), 
# in case we're using a different one
#---------------------------------------------------------------------------------------------------
function sedesc () {
     echo "$@" | sed -e 's/\([[\/.*]\|\]\)/\\&/g'
}


#---------------------------------------------------------------------------------------------------
# Function: isozdate
# return date in iso 8601 date/time format (2007-03-01T13:00:00Z)
#---------------------------------------------------------------------------------------------------
function isozdate () { 
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}


#---------------------------------------------------------------------------------------------------
# Function: DatedExitFunction
# return the passed string prefixed with the datetime of function call & suffixed with "[Exiting]"
# Example call: trap " DatedExitFunction $PROGNAME $@ " EXIT
#---------------------------------------------------------------------------------------------------
function DatedExitFunction () { 
    echo "$( isozdate ) $@ [exiting]" 
}  


#---------------------------------------------------------------------------------------------------
# Function: include
# Source one or more files into the current shell
#---------------------------------------------------------------------------------------------------
function include () {
    local rc=0 file absfile

    for file in "$@"; do
	if [ -z "${file}" ]; then
	    warn "can't source file \"\" (null)"
	    rc=1
	    continue
	elif [[ "${file}" =~ '/.*' ]]; then
	    absfile="${file}"
	else
	    absfile="${PROGHOME}/${file}"
	fi

	if [ -f "${absfile}" ]; then
	    source "${absfile}"
	else
	    echo "include(): Unable to source file \"${absfile}\" (\"${file}\") " 1>&2
	    rc=1
	fi
    done

    return ${rc}
}


#---------------------------------------------------------------------------------------------------
