#!/usr/bin/expect -f



# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
#
# Information: Automatisiertes Kopieren von Dateien ähnlich zu robocopy mittels rsync und expect
#
# Autor(en): D.Casota (DCA), daniel.casota@intersolutions.ch
#            InterSolutions GmbH, www.intersolutions.ch
#
#
# History:
#        17.03.2009 V1.00 DCA   Ersterstellung
#        27.07.2009 V1.01 DCA   Parametersplittung
#
# ------------------------------------- hilfreiche links ------------------------------------------------------
#
# http://blog.tuxcoder.com/2009/02/automated-file-synchronization-with.html
# http://bash.cyberciti.biz
# http://chrisclymer.com/articles/expect/
# http://kelpi.com/script/e815ad
# http://bagus.wordpress.com/2008/03/01/automatic-login-for-ssh/
# http://stackoverflow.com/questions/271090/automate-ssh-without-using-public-key-authentication-or-expect1
# http://forum.mikrotik.com/viewtopic.php?f=9&t=1245
# http://en.wikipedia.org/wiki/Expect
#
#
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------

set rsynclogfile [lrange $argv 0 0]
set param1 [lrange $argv 1 1]
set param2 [lrange $argv 2 2]
set username [lrange $argv 3 3]
set password [lrange $argv 4 4]
set timeout 10
spawn -noecho rsync -azuvWh -e "ssh -o StrictHostKeyChecking=no" $param1 $param2
# ab rsync version 3.04: --log-file
# ebenso einsetzbar: --exclude-from=$excludefile --include-from=$includefile
match_max 100000
# Look for password prompt
expect {
	"*?assword:*" {
	# Send password aka $password
		send -- "$password\r"
		# kein timeout für rsync-Vorgang
		set timeout -1
		# send blank line (\r) to make sure we get back to gui
		send -- "\r"
		expect eof
		exit 0
	}
}
exit 1

