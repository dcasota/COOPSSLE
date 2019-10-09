#!/bin/bash

# --------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------
#
# Information: Das remotemanager.sh Skript wird immer als erste Instanz auf dem Zielsystem aufgerufen und
#              managt alle weiteren Schritte.
#
# Autor(en): D.Casota (DCA), daniel.casota@intersolutions.ch
#            InterSolutions GmbH, www.intersolutions.ch
#
#
# History:
#        07.08.2009 V1.00 DCA   Ersterstellung
#        08.08.2009 V1.01 DCA   Diverse Bugfixes
#        13.08.2009 V1.02 DCA   Diverse Bugfixes
#        25.08.2009 V1.03 DCA   Verbessertes Errorhandling
#
#
#
# --------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
croncmd()
# --------------------------------------------------------------------------------------------------------------
{
	local COMMAND=$1
	local CRONLINE=$2

	if [ "$CRONLINE" != "" ]; then

		RANDOM=$$
		cronfile=$remotescanletpath/cron.$RANDOM.sh
		if [ -f $cronfile ]; then
			rm -f $cronfile
		fi

		case "$COMMAND" in
			add)
				# create cron command file
				echo "#!/bin/sh"									>$cronfile
				echo "EDITOR=ed"									>>$cronfile
				echo "export EDITOR"									>>$cronfile
				echo "crontab -e << EOF > /dev/null"							>>$cronfile
				echo "a"										>>$cronfile
				echo "* * * * * $CRONLINE"								>>$cronfile
				echo "."										>>$cronfile
				echo "w"										>>$cronfile
				echo "q"										>>$cronfile
				echo "EOF"										>>$cronfile
				echo "EDITOR=vi"									>>$cronfile
				echo "export EDITOR"									>>$cronfile
				;;

			del)
				# create cron command file
				echo "#!/bin/sh"									>$cronfile
				echo "currentpath=\$remotescanletpath"							>>$cronfile
				echo "filename1=\$remotescanletpath.\$RANDOM"						>>$cronfile
				echo "filename2=\$filename1.2"								>>$cronfile
				echo "filename3=\$filename1.3"								>>$cronfile
				echo "crontab -l >\$filename1"								>>$cronfile
				echo "grep -v \"$CRONLINE\" \$filename1 >\$filename2"					>>$cronfile
				echo "grep -v \"# \" \$filename2 >\$filename3"						>>$cronfile
				echo "crontab \$filename3"								>>$cronfile
				echo "rm -f \$filename1"								>>$cronfile
				echo "rm -f \$filename2"								>>$cronfile
				echo "rm -f \$filename3"								>>$cronfile
				;;

			*)
			;;
		esac

		if [ -f $cronfile ]; then
			chmod a+x $cronfile
			# Execute the cron command file
			if [ -f $cronfile ]; then
				. $cronfile
				if [ $? -eq 0 ]; then
					if [ "$debug" -eq "0" ]; then
						rm -f $cronfile
					fi
				fi
			fi
		fi
	fi
}
# --------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
activate_certificate_rsa()
# -------------------------------------------------------------------------------------------------------------
{
# der aktuell eingeloggte user ist root. Daher wird explizit $remote_connection_user verwendet.
if [ ! -d "/home/$remote_connection_user" ]; then
	echo "No /home/$remote_connection_user  found!"
	return 1
else
	if [ ! -d "/home/$remote_connection_user/.ssh" ]; then
		mkdir /home/$remote_connection_user/.ssh
		chown $remote_connection_user:users /home/$remote_connection_user/.ssh
	fi
	cp -f $remotescanletpath/$sshkey_rsa_public /home/$remote_connection_user/.ssh
	chown $remote_connection_user:users /home/$remote_connection_user/.ssh/$sshkey_rsa_public
	cat /home/$remote_connection_user/.ssh/$sshkey_rsa_public >>/home/$remote_connection_user/.ssh/authorized_keys
	# Restanz aufgrund copy im remotescanlet.sh
	if [ "$debug" -eq "0" ]; then
		rm -f $remotescanletpath/$sshkey_rsa_public
	fi

	# Mit dem Aktivieren des Zertifikats werden gleichzeitig auch die sudo-Rechte gesetzt, sofern notwendig.
	VISUDOCHECK="$remote_connection_user ALL = NOPASSWD:$remotetoolspath/$remotescanletfilename"
	cat /etc/sudoers| grep -i "$VISUDOCHECK" >/dev/null
	if [ $? -ne 0 ]; then
		visudofile=$remotescanletpath/visudo.$RANDOM.sh
		create_visudo_file
		. $visudofile
		if [ "$debug" -eq "0" ]; then
			rm -f $visudofile
		fi
	else
		echo sudo rights already active.
	fi

	return 0
fi
}
# -------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------
sudo_permission_check()
# -------------------------------------------------------------------------------------------------------------
{
	echo Check sudo permission:
	# Umgehungslösung: Einen direkten Check, ob  sudo-Rechte vorhanden sind, ist nicht bekannt.
	# Allerdings gibt es die Möglichkeit mittels sudo -S -l die Rechte abzufragen.
	# Via ssh wird allerdings nur "ALL" angezeigt, sollten Rechte vorhanden sein. Ohne Rechte bleibt das
	# File leer.
	VISUDOCHECK="ALL"
	tmpfile=$remotescanletpath/sudocheck.$RANDOM
	echo ""|sudo -S -l 1>$tmpfile
	cat $tmpfile|grep -i "$VISUDOCHECK" >/dev/null
	if [ $? -eq 0 ]; then
		echo sudo rights are already set.
		# sudo rights already set
		if [ "$debug" -eq "0" ]; then
			rm -f $tmpfile
		fi
		return 0
	else
		echo sudo rights are not set.
		if [ "$debug" -eq "0" ]; then
			rm -f $tmpfile
		fi
		return 1
	fi
}
# --------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
create_visudo_file()
# --------------------------------------------------------------------------------------------------------------
{
	VISUDOADD="$remote_connection_user ALL = NOPASSWD:$remotetoolspath/$remotescanletfilename"
	# create cron command file
	echo "#!/bin/sh"											>$visudofile
	echo "EDITOR=ed"											>>$visudofile
	echo "export EDITOR"											>>$visudofile
	echo "visudo << EOF > /dev/null"									>>$visudofile
	echo "a"												>>$visudofile
	echo "$VISUDOADD"											>>$visudofile
	echo "."												>>$visudofile
	echo "w"												>>$visudofile
	echo "q"												>>$visudofile
	echo "EOF"												>>$visudofile
	echo "EDITOR=vi"											>>$visudofile
	echo "export EDITOR"											>>$visudofile
	chmod a+x $visudofile
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
sudo_permission_set()
# --------------------------------------------------------------------------------------------------------------
{
	echo Setting sudo rights ...
	visudofile=$remotescanletpath/visudo.$RANDOM.sh
	create_visudo_file
	tmpsuloginfile=$remotescanletpath/sulogin.$RANDOM.sh
	create_su_script $tmpsuloginfile
	. $tmpsuloginfile $remote_root_password $visudofile &
	sleep 2
	if [ "$debug" -eq "0" ]; then
		rm -f $visudofile
		rm -f $tmpsuloginfile
	fi
	echo Setting sudo rights done.
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
su_method_sudo()
# --------------------------------------------------------------------------------------------------------------
{
	sudo_permission_check
	if [ $? -ne 0 ]; then
		# Wird festgestellt, dass noch keine sudo-Rechte vorliegen, dann darf nur im Fall, dass
		# ein authentication_type mit "expect" ausgewählt wurde, der sudo direkt gesetzt werden.
		echo $authentication_type|grep "expect" >/dev/null
		if [ $? -eq 0 ]; then
			sudo_permission_set
		else
			echo "`hostname -f`"$delimiter"no_permission_for_sudo"					>>"$remoteerrorlogfile"
			return 1
		fi
	fi
	echo Starting $remotetoolspath/$remotescanletfilename with sudo ...
	sudo "$remotetoolspath/$remotescanletfilename" "$filetorun" su_done
	echo Starting $remotetoolspath/$remotescanletfilename with sudo done.
}
# --------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
create_su_script()
# --------------------------------------------------------------------------------------------------------------
{
tmpsuloginfile=$1

echo "#!/bin/sh"												>$tmpsuloginfile
echo "password=\$1"												>>$tmpsuloginfile
echo "startfile=\$2"												>>$tmpsuloginfile
echo "param1=\$3"												>>$tmpsuloginfile
echo "param2=\$4"												>>$tmpsuloginfile
echo "expect -c \"set timeout -1;\\"										>>$tmpsuloginfile
echo "spawn su -l root -c \\\"\$startfile \$param1 \$param2\\\";\\"						>>$tmpsuloginfile
echo "expect *assword:*;\\"											>>$tmpsuloginfile
echo "send -- \$password\r\n;\\"										>>$tmpsuloginfile
echo "expect eof;\""												>>$tmpsuloginfile
chmod a+x "$tmpsuloginfile"
}
# --------------------------------------------------------------------------------------------------------------



# --------------------------------------------------------------------------------------------------------------
su_method_expect()
# --------------------------------------------------------------------------------------------------------------
{
	tmpsuloginfile=$remotescanletpath/sulogin.$RANDOM.sh
	create_su_script $tmpsuloginfile
	. $tmpsuloginfile $remote_root_password $remotetoolspath/$remotescanletfilename $filetorun su_done &
	timewaited=0
	while [ ! -f "$remotedonetagfile" ];
	do
		sleep 2
		timewaited=$[timewaited + 2]
		if [ $timewaited -gt $waittime ]; then
			break
		fi
	done
	if [ -f "$remotedonetagfile" ]; then
		# Ist das remotedonetagfile vorhanden, ist das Skript beendet, sodass nun das tmpsuloginfile
		# gelöscht werden kann.
		if [ "$debug" -eq "0" ]; then
			rm -f $tmpsuloginfile
		fi
	fi
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
started_directly()
# --------------------------------------------------------------------------------------------------------------
{
echo remote_su_method = $remote_su_method
	case "$remote_su_method" in
		sudo)
			su_method_sudo
			;;

		expect)
			su_method_expect
			;;

		*)
			echo "`hostname -f`"$delimiter"remote_su_method_$remote_su_method_is_unknown"		>>"$remoteerrorlogfile"
			;;
	esac
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
remotestart_directly()
# --------------------------------------------------------------------------------------------------------------
{
	. "$remotetoolspath/$remotescanletfilename" "$filetorun" started_directly
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
started_by_cron()
# --------------------------------------------------------------------------------------------------------------
{
	# Cleanup crontab
	croncmd del "$remotetoolspath/$remotescanletfilename $filetorun started_by_cron"

	case "$remote_su_method" in
		sudo)
			su_method_sudo
			;;

		expect)
			echo "`hostname -f`"$delimiter"expect_is_not_allowed_after_cron"			>>"$remoteerrorlogfile"
			;;

		*)
			echo "`hostname -f`"$delimiter"remote_su_method_$remote_su_method_is_unknown"		>>"$remoteerrorlogfile"
			;;
	esac
}
# -------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
remotestart_by_cron()
# --------------------------------------------------------------------------------------------------------------
{
	croncmd add "$remotetoolspath/$remotescanletfilename $filetorun started_by_cron"
}
# -------------------------------------------------------------------------------------------------------------



# --------------------------------------------------------------------------------------------------------------
su_done()
# --------------------------------------------------------------------------------------------------------------
{
echo su_done: modus = $modus
	if [ "$modus" == "DISTRIBUTING" ]; then
		if [ -f "$remotedonetagfile" ]; then
			echo $remotedonetagfile found. Waiting 30 seconds ...
			sleep 30
			echo Waiting 30 seconds done.
		fi
		if [ -f "$remotedonetagfile" ]; then
			echo Deleting $remotedonetagfile ...
			rm -f "$remotedonetagfile"
			echo Deleting $remotedonetagfile done.
		fi

		#  Löschen der Steuerungsfiles, falls vorhanden
		if [ -f "$remotelogfile" ]; then
			echo Deleting $remotelogfile ...
			rm -f "$remotelogfile"
			echo Deleting $remotelogfile done.
		fi

		if [ -f "$remoteerrorlogfile" ]; then
			echo Deleting $remoteerrorlogfile ...
			rm -f "$remoteerrorlogfile"
			echo Deleting $remoteerrorlogfile done.
		fi

		echo Copying $remotetoolspath into $remotescanletpath ...
		cp -a -f $remotetoolspath/* $remotescanletpath
		sleep 1
		echo Copying $remotetoolspath into $remotescanletpath done.

		if [ "$authentication_type" == "expect_create_new_ssh_rsa_key" ]; then
			echo Activating certificate_rsa ...
			activate_certificate_rsa
			echo Activating certificate_rsa done.
		fi

		. "$remotescanletpath/$remotestartfilename"  &>"$remotelogfile"

		echo DONE>"$remotedonetagfile"
	else
		if [ "$remotedonetagfile" != "" ]; then
			if [ "$remotescanletpath" != "" ]; then
				if [ "$remotedonetagfilename" != "" ]; then
					if [ -f "$remotedonetagfile" ]; then
						rm -f $remotescanletpath/$remotedonetagfilename
					fi
				fi
			fi
		fi

		if [ "$remotescanletpath" != "" ]; then
			if [ "$cleanupremotepath" == "Y" ]; then
				rm -r -f $remotescanletpath
			fi
		fi
	fi
}
# --------------------------------------------------------------------------------------------------------------


# --------------------------------------------------------------------------------------------------------------
#  Startup
# --------------------------------------------------------------------------------------------------------------
filetorun=$1

command=$2
echo command = $command

if [ "$command" == "DISTRIBUTING" ]; then
	echo "modus=$command"											>>"$filetorun"
	command=""
fi
if [ "$command" == "COLLECTING" ]; then
	echo "modus=$command"											>>"$filetorun"
	command=""
fi

. "$filetorun"

remotedonetagfile=$remotescanletpath/$remotedonetagfilename
remoteerrorlogfile=$remotescanletpath/$remoteerrorlogfilename
remotelogfile=$remotescanletpath/$remotelogfilename

if [ "$command" != "" ]; then
	case "$command" in
		started_directly)
			started_directly
			;;

		started_by_cron)
			started_by_cron
			;;

		su_done)
			su_done
			;;

		*)
			echo "`hostname -f`"$delimiter"command_$command_is_unknown"				>>"$remoteerrorlogfile"
			;;
	esac
else
	case "$remote_start_method" in
		direct)
			remotestart_directly
			;;

		cron)
			remotestart_by_cron
			;;

		*)
			echo "`hostname -f`"$delimiter"remote_start_method_$remote_start_method_is_unknown"	>>"$remoteerrorlogfile"
			;;
	esac
fi

