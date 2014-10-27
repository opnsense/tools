#!/bin/sh
#
# Copyright (c) 2006 Dominique Goncalves
#
# See COPYING for licence terms.
#
# $Id: pf_rules.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $
#
# Create a basic pf.conf.
# Block everything by default,
# Allow everything on lo0,
# Do not create rules on some interface ie: plip0,
# Allow all tcp and udp connections to outside with keep state flags,
# Allow icmp on all interfaces.
#
# PROVIDE: pf_rules
# REQUIRE: netif
# BEFORE: pf

. /etc/rc.subr

name="pf_rules"
rcvar=`set_rcvar`
start_cmd="create_rules"
required_files="$pf_rules"

create_rules ()
{
	echo "Creating $pf_rules."

	echo "scrub in all" > $pf_rules
	echo "block drop all" >> $pf_rules
	echo "pass quick on lo0 all" >> $pf_rules

	for inf in `ifconfig -l` ; do
		if echo $inf | egrep -qv 'lo|plip|gif|tun'; then
			echo "pass on $inf proto icmp all" >> $pf_rules
			echo "pass out on $inf proto {tcp,udp} from ($inf) to any keep state" >> $pf_rules
			echo "pass in on $inf proto tcp from any to ($inf) port 22 keep state" >> $pf_rules
		fi
	done
}

load_rc_config $name
run_rc_command "$1"
