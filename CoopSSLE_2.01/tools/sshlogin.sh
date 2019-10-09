#!/bin/sh

# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
#
# Information: Remotestart eines Skripts via ssh
#
# Autor(en): D.Casota (DCA), daniel.casota@intersolutions.ch
#            InterSolutions GmbH, www.intersolutions.ch
#
#
# History:
#        19.03.2009 V1.00 DCA   Ersterstellung
#        28.07.2009 V1.01 DCA   Überarbeitung Parameter
#        05.08.2009 V1.02 DCA   $authentication als Unterscheidung hinzugefügt, Kommentar hinzugefügt
#
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------

authentication=$1

echo $authentication|grep "expect" >/dev/null
if [ $? -eq 0 ]; then

	username=$2
	password=$3
	ipaddr=$4
	scriptname=$5

	echo scriptname="$scriptname"

	expect -c "set timeout -1;\
	spawn -noecho ssh -o StrictHostKeyChecking=no $ipaddr -l $username \"$scriptname\";\
	match_max 100000;\
	expect *assword:*;\
	send -- $password\r\n;\
	expect eof;"
else
	username=$2
	password=$3
	ipaddr=$4
	scriptname=$5
	ssh -o StrictHostKeyChecking=no $ipaddr -l $username "$scriptname"
fi

