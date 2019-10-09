#!/bin/sh
set +o verbose
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
#
# Information: Scanletstarter
#
# Autor(en): D.Casota (DCA), daniel.casota@intersolutions.ch
#            InterSolutions GmbH, www.intersolutions.ch
#
#
# History:
#        24.02.2009 V0.8  DCA   Erstdraft ab Windows-Version
#        17.03.2009 V0.9  DCA   Komplette Überarbeitung
#        19.03.2009 V1.0  DCA   Anpassungen ping-Befehl im switcher.sh und rsync in sshrobocopy.sh
#        19.03.2009 V1.1  DCA   Check für root privilege eingebaut
#        21.03.2009 V1.2  DCA   Bugfix bei Info_MachineBUSY, direkter Start des scanletjob.sh als root
#        22.07.2009 V1.3  DCA   Dynamisierung Scanletname
#        27.07.2009 V1.4  DCA   authentication Modi expect/create_ssh_rsa/expectless, debug, Remotecleanup
#        05.08.2009 V1.41 DCA   Modus expectless bereinigt
#        13.08.2009 V2.00 DCA   Komplette Überarbeitung des Remote Handlings (Einführung remotemanager.sh)
#        25.08.2009 V2.01 DCA   Erweitertes Errorhandling bei create_sshkey_rsa, Einmalstart-Check
#
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
writeline()
# -------------------------------------------------------------------------------------------------------------
{
	echo "$(date +"%d.%m.%Y %H:%M:%S"): $@"
	if [ "$logfiletmp" != "" ]; then
		echo "$(date +"%d.%m.%Y %H:%M:%S"): $@"								>>"$logfiletmp"
	fi
}
# -------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------
raiseerror()
# -------------------------------------------------------------------------------------------------------------
{
	writeline $error
	read -p "press a key."
	exit 1
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
header()
# -------------------------------------------------------------------------------------------------------------
{
echo -en "\033[34;1m"
echo --------------------------------------
echo Coop Scanlet for Suse Linux Enterprise
echo --------------------------------------
echo System information
cat /etc/SuSE-release
uname -a
echo -en "\033[0m"
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
pruning()
# -------------------------------------------------------------------------------------------------------------
{
	prunfile=$1
	pruningage=$2

	for a in `seq $pruningage -1 1`
	do
		if [ -f $prunfile.$a ]; then
			if [ $a -eq $pruningage ]; then
				rm -f $prunfile.$a
			else
				mv -f $prunfile.$a $prunfile.$[a+1]
			fi
		fi
	done
	if [ -f $prunfile ]; then
		mv -f $prunfile $prunfile.1
	fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
logfile_create()
# -------------------------------------------------------------------------------------------------------------
{
pruningage=10

# logfile specific definitions
logfilename=log.out
logfile=$rootdir/$logfilename
pruning $logfile $pruningage

errorlogfilename=err.out
errorlogfile=$rootdir/$errorlogfilename
pruning $errorlogfile $pruningage

logfilenametmp=$logfilename.tmp
logfiletmp=$rootdir/$logfilenametmp
if [ -f "$logfiletmp" ]; then
	rm -f "$logfiletmp"
fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
initialization()
# -------------------------------------------------------------------------------------------------------------
{
thisbash="scanletstarter.sh"
rootdir=$PWD

if [ "$rootdir" == "/root" ]; then
	# Dies ist das Indiz, dass der scanletstarter via cron gestartet wurde.
	# Der Pfad wird manuell erstellt.
	PATH=$PATH:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/bin:/usr/bin
	# Unter cron muss das rootdir via BASH_SOURCE extrahiert werden.
	bashsource=$BASH_SOURCE
	bashsource=${bashsource/#'([0]="'/''}
	bashsource=${bashsource/%'")'/''}
	rootdir=${bashsource%/*}
fi
scanletname=${rootdir##*/}

writeline rootdir = $rootdir
writeline scanletname = $scanletname

running="`ps -ef|grep -i -c "$rootdir/$thisbash"`"
echo $running
if [ $running -gt 2 ]; then
	writeline This scanlet is already running!
	exit
fi

cfgfilename=scanletcfg.sh
cfgfile=$rootdir/$cfgfilename
if [ ! -f "$cfgfile" ]; then
	raiseerror "'$cfgfile' does not exist!"
fi

. "$cfgfile"
# TODO: integrity check

logfile_create
}
# -------------------------------------------------------------------------------------------------------------



# -------------------------------------------------------------------------------------------------------------
settings()
# -------------------------------------------------------------------------------------------------------------
{
writeline Reading settings ...
delimiter=";"


temppath=$rootdir/tmp
if [ -d "$temppath" ]; then
	rm -r -f "$temppath"
fi
mkdir -p "$temppath"

toolsdirname=tools
rscriptsdirname=remotescripts
rtoolsdirname=remotetools

toolsroot=$rootdir/$toolsdirname
if [ ! -d "$toolsroot" ]; then
	raiseerror "'$toolsroot' does not exist!"
fi

rtoolsroot=$rootdir/$rtoolsdirname
if [ ! -d $rtoolsroot ]; then
	raiseerror "'$rscriptsroot' does not exist!"
fi

rscriptsroot=$rootdir/$rscriptsdirname
if [ ! -d $rscriptsroot ]; then
	raiseerror "'$rscriptsroot' does not exist!"
fi

switcherfilename=switcher.sh
switcherfile=$toolsroot/$switcherfilename
if [ ! -f "$switcherfile" ]; then
	raiseerror "'$switcherfile' does not exist!"
fi

sshrobocopyfilename=sshrobocopy.sh
echo $authentication_type|grep "expect" >/dev/null
if [ $? -ne 0 ]; then
	sshrobocopyfilename=sshrobocopy-expectless.sh
fi
sshrobocopyfile=$toolsroot/$sshrobocopyfilename
if [ ! -f "$sshrobocopyfile" ]; then
	raiseerror "'$sshrobocopyfile' does not exist!"
fi

sshloginfilename=sshlogin.sh
sshloginfile=$toolsroot/$sshloginfilename
if [ ! -f "$sshloginfile" ]; then
	raiseerror "'$sshloginfile' does not exist!"
fi

remotescanletfilename=remotemanager.sh
remotescanletfile=$rtoolsroot/$remotescanletfilename
if [ ! -f "$remotescanletfile" ]; then
	raiseerror "'$remotescanletfile' does not exist!"
fi

scanletjobfilename=scanletjob.sh
scanletjobfile=$rscriptsroot/$scanletjobfilename
if [ ! -f "$scanletjobfile" ]; then
	raiseerror "'$scanletjobfile' does not exist!"
fi

distrsrv=$HOSTNAME

sshkey_rsa_private=id_rsa
sshkey_rsa_public=id_rsa.pub

# thread rotator specific information
separatecollectingtagname=separatecollecting.tag
separatecollectingtagfile=$rootdir/$separatecollectingtagname

# slot specific definitions
slotlogfilename=log.out
sloterrorlogfilename=err.out
slotstatusfilename=status.sh
slotendtagfilename=end.tag

# remote specific definitions
remotestartfilename=scanletjob.sh
remotelogfilename=remotelog.out
remoteerrorlogfilename=remoteerr.out
remotecfgfilename=cfg_scanletjob.sh
remotedonetagfilename=remotedone.tag
remotetemppath=/tmp
remotetoolspath=$remotetemppath/tools
remotescanletpath=$remotetemppath/$scanletname

writeline Reading settings done.
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
threadslot()
# -------------------------------------------------------------------------------------------------------------
{
slotID=$1
writeline create slot $slotID ...

pathslotID=$temppath/$slotID
slotinitfilename=slotinit.sh

mkdir -p "$pathslotID" >/dev/null
mkdir -p  $pathslotID/$toolsdirname >/dev/null
mkdir -p  $pathslotID/$rtoolsdirname >/dev/null
mkdir -p  $pathslotID/$rscriptsdirname >/dev/null
cp -a -f $toolsroot/* $pathslotID/$toolsdirname  >/dev/null
cp -a -f $rtoolsroot/* $pathslotID/$rtoolsdirname >/dev/null
cp -a -f $rscriptsroot/* $pathslotID/$rscriptsdirname >/dev/null

chmod a+x "$pathslotID/$toolsdirname/$switcherfilename" >/dev/null
chmod a+x "$pathslotID/$toolsdirname/$sshloginfilename" >/dev/null
chmod a+x "$pathslotID/$toolsdirname/$sshrobocopyfilename" >/dev/null
chmod a+x "$pathslotID/$rtoolsdirname/$remotescanletfilename" >/dev/null
chmod a+x "$pathslotID/$rscriptsdirname/$scanletjobfilename" >/dev/null

slotinitfile=$pathslotID/$slotinitfilename
echo #!/bin/sh										>"$slotinitfile"
echo # Do not delete!									>>"$slotinitfile"

echo debug=$debug									>>"$slotinitfile"
echo authentication_type=$authentication_type						>>"$slotinitfile"
echo remote_start_method=$remote_start_method						>>"$slotinitfile"
echo remote_su_method=$remote_su_method							>>"$slotinitfile"

echo remote_connection_user=$remote_connection_user					>>"$slotinitfile"
echo remote_connection_password=$remote_connection_password				>>"$slotinitfile"
echo remote_root_password=$remote_root_password						>>"$slotinitfile"

echo scanletname=$scanletname								>>"$slotinitfile"

echo toolsdirname=$toolsdirname								>>"$slotinitfile"
echo rtoolsdirname=$rtoolsdirname							>>"$slotinitfile"
echo rscriptsdirname=$rscriptsdirname							>>"$slotinitfile"

echo slotID=$slotID									>>"$slotinitfile"
echo pathslotID=$pathslotID								>>"$slotinitfile"
echo slotinitfilename=$slotinitfilename							>>"$slotinitfile"

echo slotstatusfilename=$slotstatusfilename						>>"$slotinitfile"
echo slotlogfilename=$slotlogfilename							>>"$slotinitfile"
echo sloterrorlogfilename=$sloterrorlogfilename						>>"$slotinitfile"
echo slotendtagfilename=$slotendtagfilename						>>"$slotinitfile"

echo remotestartfilename=$remotestartfilename						>>"$slotinitfile"
echo remotelogfilename=$remotelogfilename						>>"$slotinitfile"
echo remoteerrorlogfilename=$remoteerrorlogfilename					>>"$slotinitfile"
echo remotecfgfilename=$remotecfgfilename						>>"$slotinitfile"
echo remotedonetagfilename=$remotedonetagfilename					>>"$slotinitfile"
echo remotetoolspath=$remotetoolspath							>>"$slotinitfile"
echo remotescanletpath=$remotescanletpath						>>"$slotinitfile"
echo activatecertificatefilename=$activatecertificatefilename				>>"$slotinitfile"

echo sshrobocopyfilename=$sshrobocopyfilename						>>"$slotinitfile"
echo sshloginfilename=$sshloginfilename							>>"$slotinitfile"
echo remotescanletfilename=$remotescanletfilename					>>"$slotinitfile"
echo scanletjobfilename=$scanletjobfilename						>>"$slotinitfile"
echo waittime=$waittime									>>"$slotinitfile"


echo distrsrv=$distrsrv									>>"$slotinitfile"

echo sshkey_rsa_public=$sshkey_rsa_public						>>"$slotinitfile"
echo delimiter=\"$delimiter\"								>>"$slotinitfile"

echo cleanupremotepath=$cleanupremotepath						>>"$slotinitfile"


chmod a+x "$slotinitfile" >/dev/null

nohup "$pathslotID/$toolsdirname/$switcherfilename" "$slotinitfile" &>"$pathslotID/$slotlogfilename" &
PID=$!
echo "$PID"													>$slotinitfile.pid
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
createthreads()
# -------------------------------------------------------------------------------------------------------------
{
writeline create slots ...
for a in `seq $maxslots`
do
	threadslot $a
done
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
threadswitchprocessing()
# -------------------------------------------------------------------------------------------------------------
{
	while [ 1 ]
	do
		statusflagfile=$temppath/$slotpointer/$slotstatusfilename
		if [ -f "$statusflagfile" ]; then
			frisbeeslice=$[frisbeeslice+1]
			if [ "$slotpointer" -ge "$maxslots" ]; then
				slotpointer=0
				if [ "$frisbeeslice" -gt "0" ]; then
					sleep 2
					frisbeeslice=0
				fi
			fi
			slotpointer=$[slotpointer+1]
		else
			echo #!/bin/sh			>"$statusflagfile"
			echo modus=$threadrotatormode	>>"$statusflagfile"
			echo ipaddr=$ipaddr		>>"$statusflagfile"
			writeline $threadrotatormode: $ipaddr will be processed in slot $slotpointer.
			frisbeeslice=0
			break
		fi
	done
}
# -------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------
threadswitch()
# -------------------------------------------------------------------------------------------------------------
{
ipaddr=$1
threadrotatormode=$2

local slotpointer=1
local frisbeeslice=0

if [ "$threadrotatormode" = "DISTRIBUTING" ]; then
	threadswitchprocessing
else
	if [ -f "$errorlogfile" ]; then
		cat $errorlogfile|grep -i "$ipaddr" >/dev/null
		if [ $? -gt 0 ]; then
			threadswitchprocessing
		else
			writeline Server $ipaddr failed already in mode DISTRIBUTING!
		fi
	else
		threadswitchprocessing
	fi
fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
waitthreadrotatorend()
# -------------------------------------------------------------------------------------------------------------
{
threadrotatormode=$1
waitmaxslotending=600
waitslotending=0
writeline Waiting until all threads are finished in mode $threadrotatormode ...
while [ 1 ];
do
	if [ $waitslotending -ge $waitmaxslotending ]; then
		allslots="TIMEOUT"
		break
	else
		waitslotending=$[waitslotending+1]
		sleep 1
		allslots="IDLE"
		for a in `seq $maxslots`
		do
			if [ -f "$temppath/$a/$slotstatusfilename" ]; then
				allslots=BUSY
				break
			fi
		done
		if [ $allslots = "IDLE" ]; then
			break
		fi
	fi
done

if [ $allslots = "TIMEOUT" ]; then
	writeline Warning: Some threads are still running!
else
	writeline All threads finished in mode $threadrotatormode.
fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
writeerrorlog()
# -------------------------------------------------------------------------------------------------------------
{
for a in `seq $maxslots`
do
	if [ -f "$temppath/$a/$sloterrorlogfilename" ]; then
		cat $temppath/$a/$sloterrorlogfilename								>>$errorlogfile
		if [ "$debug" -eq "0" ]; then
			rm -f $temppath/$a/$sloterrorlogfilename
		fi
	fi
done
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
distribute()
# -------------------------------------------------------------------------------------------------------------
{
threadrotatormode=DISTRIBUTING
writeline Processing files with thread rotator in mode $threadrotatormode ...
for file in `cat "$rootdir/list"`
do
    threadswitch $file $threadrotatormode
done
writeline Processing files with thread rotator in mode $threadrotatormode  done.
waitthreadrotatorend $threadrotatormode
writeerrorlog
}
# -------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------
collect()
# -------------------------------------------------------------------------------------------------------------
{
threadrotatormode=COLLECTING
writeline Processing files with thread rotator in mode $threadrotatormode ...
for file in `cat "$rootdir/list"`
do
    threadswitch $file $threadrotatormode
done
writeline Processing files with thread rotator in mode $threadrotatormode  done.
waitthreadrotatorend $threadrotatormode
writeerrorlog
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
destroythreads()
# -------------------------------------------------------------------------------------------------------------
{
for a in `seq $maxslots`
do
	echo DONE>$temppath/$a/$slotendtagfilename
done
sleep 1
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
mail()
# -------------------------------------------------------------------------------------------------------------
{
if [ -f "$errorlogfile" ]; then
	mailattach=$rootdir/$scanletname.csv
	cp -f $errorlogfile $mailattach

	maildir=$toolsroot/mail
	# global customer specific variables
	. $maildir/mailcfg.sh

	messagebody=$maildir/mailinfo
	subject="CoopSSLE alert mail from $scanletname on $HOSTNAME"

	# http://caspian.dotconf.net/menu/Software/SendEmail/
	tar -xzvf $maildir/sendEmail-v1.55.tar.gz -C $maildir

	for recipient in `cat "$rootdir/recipients"`
	do
		perl $maildir/sendEmail-v1.55/sendEmail -f $sender -t $recipient -u $subject -o message-file=$messagebody -s $smtpserver:$smtpport -a $mailattach -o tls=auto
	done

	if [ "$debug" -eq "0" ]; then
		rm -f $mailattach
	fi
fi

}
# -------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------
create_sshkey_rsa()
# -------------------------------------------------------------------------------------------------------------
{
ssh-keygen -f $temppath/$sshkey_rsa_private -t rsa
# Nun müsste ein private key und ein public key erstellt worden sein.
if [ -f "$temppath/$sshkey_rsa_public" ]; then
	if [ -d "/home/$remote_connection_user" ]; then
		if [ ! -d "/home/$remote_connection_user/.ssh" ]; then
			mkdir "/home/$remote_connection_user/.ssh"
			chown $remote_connection_user:users "/home/$remote_connection_user/.ssh"
		fi
		cp -f "$temppath/$sshkey_rsa_private" "/home/$remote_connection_user/.ssh"
		if [ "$debug" -eq "0" ]; then
			rm -f "$temppath/$sshkey_rsa_private"
		fi
		chown $remote_connection_user:users "/home/$remote_connection_user/.ssh/$sshkey_rsa_private"
		if [ $? -eq 0 ]; then
			cp -f "$temppath/$sshkey_rsa_public" "$rscriptsroot"
			if [ "$debug" -eq "0" ]; then
				rm -f "$temppath/$sshkey_rsa_public"
			fi
		else
			return 3
		fi
	else
		return 2
	fi
else
	return 1
fi
}
# -------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------
cleanup()
# -------------------------------------------------------------------------------------------------------------
{
	writeline cleanup
	mv -f $logfiletmp $logfile
	if [ "$debug" -eq "0" ]; then
		rm -r -f "$temppath"
	fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
# --------------------------------------------- main ----------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
trap 'normalplease'  1 2 3 15
# Siehe http://de.wikibooks.org/wiki/Linux-Kompendium:_Shellprogrammierung

header
ROOT_UID=0
if [ "$UID" -eq "$ROOT_UID" ]
then
	echo -en "\033[38;1m"
	initialization
	writeline Scanlet started.
	settings
	if [ "$authentication_type" == "expect_create_new_ssh_rsa_key" ]; then
		create_sshkey_rsa
		if [ $? -ne 0 ]; then
			raiseerror "create_ssh_key_rsa terminated with error!"
		fi
	fi
	createthreads
	distribute
	writeline Waiting $waittime seconds between DISTRIBUTING and COLLECTING
	sleep $waittime
	collect
	destroythreads
	mail
	cleanup
else
	echo -en "\033[33;1m"
	echo CoopSSLE needs root privileges. Please switch to root context.
fi
echo -en "\033[0m"








