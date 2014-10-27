#
# print error
#
print_error_opns() {
	echo
	echo "####################################"
	echo "Something went wrong, check errors!" 
	echo "####################################"
	echo
	echo
	if [ "$1" != "" ]; then
		echo $1
	fi
    [ -n "${LOGFILE:-}" ] && \
        echo "Log saved on ${LOGFILE}" && \
		tail -n20 ${LOGFILE} >&2
	echo
	echo "Press enter to continue."
    read ans
    kill $$
}
