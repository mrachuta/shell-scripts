#!/bin/bash

# Script mounts multiple google-drives.
# First, install google-drive-ocamlfuse package:
# https://github.com/astrada/google-drive-ocamlfuse
# Usage: add username(s) to 'accounts' array: e.g. ("jon" "jon2")
# Run script manually to login to each account (as your user)
# Add script to autostart/systemd/initd to keep drives available 
# each login.

accounts=("typeyourusernamehere")

# If you use script as systemd service, you need to
# add path to google-drive-ocamlfuse manually.

#gdo=$(whereis google-drive-ocamlfuse | cut -d" " -f2-)
gdo="/path/to/google-drive-ocamlfuse"

function checkconnection {
	
	maxtries=3
	currtry=1
	while [ $maxtries -gt 0 ]
	do
		
		echo "Checking internet connection, try $currtry"
		wget -q --spider http://google.com

		if [ $? -eq 0 ] 
		then
			echo "Online, drives will be mounted"
			export ISCONNECTED=true
			return 0
		else
			echo "Offline"
			let maxtries=maxtries-1
			let currtry=currtry+1
			sleep 60
		fi
	done
	echo "Offline, unable to mount drives"
	xmessage -buttons Ok:0 -center -default Ok "Offline, unable to mount drives" -timeout 10
	return 1
}

function umountdrives {
	
	for i in ${!accounts[*]}
	do
		echo "Umounting drive related to account: ${accounts[$i]}"
		fusermount -u /media/${accounts[$i]}
		sleep 5
	done
	echo "All drives umounted"
	
}

function mountdrives {
	
	checkconnection
	if [ "$ISCONNECTED" == "true" ]
	then
		for i in ${!accounts[*]}
		do
			echo "Mounting drive related to account: ${accounts[$i]}"
			sleep 15
			$gdo -label ${accounts[$i]} /media/${accounts[$i]}
		done
		echo "All google-drives mounted"
		xmessage -buttons Ok:0 -center -default Ok "All google-drives mounted" -timeout 10
		return 0
	fi

}

function displayhelp {
	
	echo "Script mounts multiple google-drives"
	echo "for more information see source."
	echo ""
	echo "Use -m to mount drives"
	echo "Use -u to umount drives"
	echo "Use -h to display this help"

}

case "$1" in
	"") mountdrives
	;;
	"-m") mountdrives
	;;
	"-u") umountdrives
	;;
	"-h") displayhelp
	;;
	*) echo "Unknown option, type -h for help"
esac
	
