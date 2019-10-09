#!/bin/sh


# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
#
# Information: Abarbeitungsmeccano pro Slot
#
# Autor(en): D.Casota (DCA), daniel.casota@intersolutions.ch
#            InterSolutions GmbH, www.intersolutions.ch
#
#
# History:
#        24.02.2009 V1.00 DCA   Ersterstellung
#        17.03.2009 V2.00 DCA   Überarbeitung proceed-Routine
#        21.03.2009 V2.01 DCA   Bugfix Info_MachineBUSY
#        23.07.2009 V2.02 DCA   Delimiter von , auf ; geändert
#        27.07.2009 V2.03 DCA   Delimiter dynamisiert
#        29.07.2009 V2.10 DCA   Einbau zertifikatsbasierende Methode (expectless)
#        13.08.2009 V2.11 DCA   Bugfix remotestart bei COLLECTING
#        25.08.2009 V2.12 DCA   Auslagerung von remotestart und Bugfixes Protokollierung
#
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
remotestart()
# -------------------------------------------------------------------------------------------------------------
{

	echo Starting remote scanlet script ...
	su -l $remote_connection_user --command=". $pathslotID/$toolsdirname/$sshloginfilename $authentication_type \"$remote_connection_user\" \"$remote_connection_password\" $ipaddr \". $remotetoolspath/$remotescanletfilename $remotescanletpath/$slotinitfilename $modus\""
	if [ $? -eq 0 ]; then
		echo Remote script successfully started.
	else
		echo Could not start remote script!
		echo "$ipaddr"$delimiter"remotescript_"$modus"_notstarted"					>>$pathslotID/$sloterrorlogfilename
	fi

}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
distributing()
# -------------------------------------------------------------------------------------------------------------
{
	# Mit rsync konnten neue Subverzeichnisse nicht automatisch erstellt werden.
	# Deswegen werden die notwendigen Verzeichnisse explizit und vorab per mkdir erstellt.
	su -l $remote_connection_user --command=". $pathslotID/$toolsdirname/$sshloginfilename $authentication_type $remote_connection_user $remote_connection_password $ipaddr \"mkdir -p $remotescanletpath\""
	su -l $remote_connection_user --command=". $pathslotID/$toolsdirname/$sshloginfilename $authentication_type $remote_connection_user $remote_connection_password $ipaddr \"mkdir -p $remotetoolspath\""

	$pathslotID/$toolsdirname/$sshrobocopyfilename $slottmplogfile $pathslotID/$rtoolsdirname/ $remote_connection_user@$ipaddr:$remotetoolspath $remote_connection_user $remote_connection_password
	if [ $? -eq 0 ]; then
		$pathslotID/$toolsdirname/$sshrobocopyfilename $slottmplogfile $pathslotID/$rscriptsdirname/ $remote_connection_user@$ipaddr:$remotescanletpath $remote_connection_user $remote_connection_password
		if [ $? -eq 0 ]; then
			$pathslotID/$toolsdirname/$sshrobocopyfilename $slottmplogfile $pathslotID/$slotinitfilename $remote_connection_user@$ipaddr:$remotescanletpath/$slotinitfilename $remote_connection_user $remote_connection_password
			if [ $? -eq 0 ]; then
				remotestart
			else
				echo Could not copy $remotescanletpath/$slotinitfilename to server $ipaddr!
				echo "$ipaddr"$delimiter"slotinitfilename_notcopied"				>>$pathslotID/$sloterrorlogfilename
			fi
		else
			echo Could not copy $rscriptsdirname to server $ipaddr!
			echo "$ipaddr"$delimiter"rscriptsdir_notcopied"						>>$pathslotID/$sloterrorlogfilename
		fi
	else
		echo Could not copy $rtoolsdirname to server $ipaddr!
		echo "$ipaddr"$delimiter"rtoolsdir_notcopied"							>>$pathslotID/$sloterrorlogfilename
	fi
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
collecting()
# --------------------------------------------------------------------------------------------------------------
{
	# Check donetagfile
	$pathslotID/$toolsdirname/$sshrobocopyfilename $slottmplogfile $remote_connection_user@$ipaddr:$remotescanletpath/$remotedonetagfilename $pathslotID/$remotedonetagfilename $remote_connection_user $remote_connection_password
	if [ -f "$pathslotID/$remotedonetagfilename" ]; then
		# Get remotelogfile
		$pathslotID/$toolsdirname/$sshrobocopyfilename $slottmplogfile $remote_connection_user@$ipaddr:$remotescanletpath/$remoteerrorlogfilename $pathslotID/$remoteerrorlogfilename $remote_connection_user $remote_connection_password
		if [ -f "$pathslotID/$remoteerrorlogfilename" ]; then
			# Write remotelogfile
			cat $pathslotID/$remoteerrorlogfilename							>>$pathslotID/$sloterrorlogfilename
			sleep 1
			rm -f $pathslotID/$remoteerrorlogfilename
		fi
		remotestart
	else
		echo "$ipaddr"$delimiter"INFO_MachineBUSY"							>>$pathslotID/$sloterrorlogfilename
	fi
	rm -f $pathslotID/$remotedonetagfilename
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
proceed()
# --------------------------------------------------------------------------------------------------------------
{
echo Pinging $ipaddr ...
ping -c 1 $ipaddr|grep -i "ttl=" > /dev/null
if [ $? -eq 0 ]; then
	echo Pinging $ipaddr successfully done.

	if [ "$modus" == "DISTRIBUTING" ]; then
		echo distributing
		distributing
	else
		echo collecting
		collecting
	fi
else
	echo Link is offline.
	echo "$ipaddr"$delimiter"offline_"$modus""								>>$pathslotID/$sloterrorlogfilename
fi
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------------------------------------------

# evtl. von Nutzen
processID=$$

# Get slot information from initialization file
slotinitializationfile=$1
. "$slotinitializationfile"

slotendtagfile=$pathslotID/$slotendtagfilename
slotstatusflagfile=$pathslotID/$slotstatusfilename

slottmplogfile=$pathslotID/tmp.out

while [ 1 ]
do
	if [ -f "$slotstatusflagfile" ]; then
		sleep 1
		chmod a+x "$slotstatusflagfile"
		. "$slotstatusflagfile"
		proceed
		if [ -f "$slottmplogfile" ]; then
			cat "$slottmplogfile"
			rm -f "$slottmplogfile"
		fi
		rm -f "$slotstatusflagfile"
	else
		echo Slot $slotID is IDLE.
		sleep 1
	fi
	if [ -f "$slotendtagfile" ]; then
		break
	fi
done
