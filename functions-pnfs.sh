#!/bin/bash

####################################################################################################
# Functions for Fermilab's Enstore system
# For details, see Enstore Users Guide at FNAL: http://www-ccf.fnal.gov/enstore/users_guide.html
#
# Tim DiLauro <tim.dilauro@gmail.com>
####################################################################################################


#---------------------------------------------------------------------------------------------------
# Function: top-level-dir
# Returns the top-level directory of a filepath argument with no trailing slash
# NB: *** This probably needs to move to a utility class ***
# NB: Would like to be able to do this without calling external program
#---------------------------------------------------------------------------------------------------
function top-level-dir () {
    local dir="$@"

    # prepend $PWD for relative paths
    if [[ "${dir:0:1}" = /* ]]; then dir="${PWD}/${dir}" ; fi
    echo "${dir}" | sed -e 's|//[/]*|/|g' -e 's|^\(/*[^/]*\).*|\1|'
}



#---------------------------------------------------------------------------------------------------
# Function: pnfs-init
# Setup the environment for copying to/from tape via /pnfs directory hierarchy
# NB: This function should won't work in a subshell.
#---------------------------------------------------------------------------------------------------
function pnfs-init () {
    if [ -f "/fnal/ups/etc/setups.sh" ]; then
	. "/fnal/ups/etc/setups.sh"
    fi
    setup -q stken encp
}



#---------------------------------------------------------------------------------------------------
# Function: pnfs-copy-usage
# Display usage message for pnfs-copy() function on STDERR
#---------------------------------------------------------------------------------------------------
function pnfs-copy-usage () {
    echo "Usage:" 1>&2
    echo "     pnfs-copy <source file> <destination file>" 1>&2
    echo "     pnfs-copy <source file> [source file [...]] <destination directory>" 1>&2
}



#---------------------------------------------------------------------------------------------------
# Function: pnfs-copy
# Load content from the tape via the mapping directory
# NB: encp is not capable of recursive directory copy and only files can be specified as source
#---------------------------------------------------------------------------------------------------
function pnfs-copy () {
    local tapeDir argcnt destination 
    local encpResultString encprc

    tapeDir="/pnfs"

    argcnt=$#;

    # last argument is the destination
    destination="${!#}"
    # sources are this: "${@:1:$((argcnt-1))}"

    # print out the list of sources
    # for i in "${@:1:$((argcnt-1))}"; do echo "*** $i ***"; done

    # a couple simple checks to make sure we're on the right track before running the command
    if [ "$( top-level-dir ${destination} )" == "$( top-level-dir "${tapeDir}" )" ]; then
	echo "pnfs-copy: special restriction: tape mapping directory \"${tapeDir}\" cannot be destination directory"
	return 1
    elif [ "$argcnt" -lt 2 ]; then
	echo "pnsf-copy: Not enough arguments" 1>&2
	pnfs-copy-usage
	return 1
    elif [ "${argcnt}" -gt 2 ]  &&  [ ! -d "${destination}" ] ; then
	echo "pnsf-copy: Multiple sources, but \"${destination}\" is not a directory" 1>&2
	pnfs-copy-usage
	return 1
#    elif [ "${destination:0:1}" != '/' ]; then
#       echo "pnsf-copy: destination path \"${destination}\" is not absolute (does not begin with a '/')" 1>&2
#	return 1
    fi


    NL='
'
    encpResultString="$( encp "${@:1:$((argcnt-1))}" "${destination}" 2>&1 )" ; encprc=$?
    if [ "${encprc}" -ne 0 ]; then 
	#echo; echo; 
	# next line displays result string as it was emitted by encp
	#echo "${encpResultString}"; 
	# next line makes the variables safe (I think) for an eval
	# next treats all white space the same
	encpResultString=$( pnfs-error-formatter "${encpResultString}" );
	echo ${encpResultString}; 
	#( # If we do anything with this result string, we should do it in a subshell
	  #  echo "${encpResultString}" | while IFS=$NL read -r resultline; do echo "--> ${resultline} <--"; done ; 
	  #  echo "Error: rc=${encprc};  status=$STATUS; infile=$INFILE; outfile=$OUTFILE"; 
	#) 
    fi
    return ${encprc}
}



#---------------------------------------------------------------------------------------------------
# Function: pnfs-error-formatter
# Format the encp error string to list of (possibly multiline) NAME='value' entries
#---------------------------------------------------------------------------------------------------
function pnfs-error-formatter () {
    # sed pattern for error string variable names
    local varPattern='[[:upper:]][[:upper:][:digit:]_]*'

    echo "$@" | sed -n -e "

        # if empty line, error message should be next, but flush buffer first
        /^$/ b flushBuffer

	/^${varPattern}=/ b flushBuffer


        # Any other pattern, just add the line to the hold buffer and break
	H
	b

	:errMessage
        # want ERRMSG=... at the end of all of this
	n                             # read next line
	s/^\(.*\)$/ERRMSG=\1/         # prepend the variable name
	$ b done

        # now need to read (non-blank?) lines until EOF
	:finish
	N
	$ b done
	b finish

	:done
        # put the pattern in the hold space
	h
        # ... and continue on to flush the buffer (and end)

	:flushBuffer
        # work with hold space and hold pattern space
	x
        # do whatever we want to do with the VARIABLE=... string
	s/^\(${varPattern}\)=\(.*\)$/\1='\2'/
        # maybe making the next line a delete and moving up to right after the swap would be more efficient
	/^$/!p
        # swap back to our previous pattern space
	x
       # if the original pattern was an empty line, then we're into the error message
        /^$/ b errMessage
        # otherwise, continue
	x
    "
}