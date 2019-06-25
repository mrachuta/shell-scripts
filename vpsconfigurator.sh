#!/bin/bash

# Script configure remote VPS (basic confiuguration)

hostname=$(hostname)
kernel=$(uname -r)
currusername=$(whoami)

function newuser {
	
	echo "Configuring user..."
	
	echo "Enter username for your new user:"
	read newusername

	echo "Creating new user $newusername"

	case $(grep -c "^$newusername:" /etc/passwd) in
		1)
			echo "User already exists, skipping..."
			read -p \
			"Do you want to change password for $newusername? [y/n] " \
			changepassword
			case $changepassword in
				y)
					passwd $newusername
					;;
				*)
					echo \
					"Password for user $newusername will stay unchanged"
					;;
			esac
			read -p \
			"Do you want to add your key to authorized_keys? [y/n] " \
			addkey
			case $addkey in
				y)
					read -p "Enter url to key: " keyurl
					if [ ! -d "/home/$newusername/.ssh/" ]
					then
						mkdir /home/$newusername/.ssh/
					fi
					wget -O - $keyurl >> /home/$newusername/.ssh/authorized_keys
					if [ "$?" = 0 ]
					then
						echo "Key added"
						chown $newusername:$newusername /home/$newusername/.ssh/authorized_keys
					else
						echo "Failed to add key"
					fi
					;;
				*)
					echo "Key will be not added"
					;;
			esac
			;;
		0)
			useradd $newusername
			echo "Type password for new user $newusername:"
			passwd $newusername
			;;
	esac

	echo "Adding user $newusername to sudo"
	sudo adduser $newusername sudo

}

function confssh {
	
	echo "Configuring SSH service..."

	# List of params can be modified
	sshparams=(PasswordAuthentication=yes PermitRootLogin=no)

	# Do not change!
	sshparamslen=${#sshparams[@]}

	# Standard path to config
	conff="/etc/ssh/sshd_config"

	for e in $(seq 0 $[sshparamslen-1])
	do
		par=${sshparams[$e]}
		
		# Convert to array
		IFS="=" read -r -a i <<< "${par}"
		
		repto="## Changed by vpsconfigurator ##\n${i[0]} ${i[1]}"
		if [ "${i[1]}" == "yes" ]
		then
			search=$(sed -n -e "/^${i[0]}[ ]*no$/p" $conff)
		else
			search=$(sed -n -e "/^${i[0]}[ ]*yes$/p" $conff)
		fi
		
		if [ "$search" ]
		then
			echo "Setting ${i[0]}=${i[1]}"
			if [ "${i[1]}" == "yes" ]
			then
				sed -i -e "s/^${i[0]}[ ]*no$/## Manually ##\n${i[0]} ${i[1]}/g" $conff
			else
				sed -i -e "s/^${i[0]}[ ]*yes$/## Manually ##\n${i[0]} ${i[1]}/g" $conff
			fi
		else
			echo "${i[0]}=${i[1]} already presented, not overrided"
		fi
	done

	echo "Restarting SSH service"
	sudo service ssh restart

	if [ "$?" != 0 ]
	then
		echo \
		"WARNING: service SSH not restarted properly, check it manually!"
	else
		echo "Service SSH restarted properly"
	fi

}

function software {
	
	echo "Configuring software..."
	
	# List of apps to be installed can be modified
	applist=(nano htop iputils-ping traceroute)
	
	# Do not change!
	applistlen=${#applist[@]}
	
	echo "Performing package manager update"
	sudo apt-get update
	echo "Performing system update"
	sudo apt-get dist-upgrade
	echo "Installing software"
	
	for i in $(seq 0 $[applist-1])
	do
		echo "- ${applist[$i]}"
		sudo apt-get install ${applist[$i]}
	done
	
}	

echo "Host configuration script for Debian-based systems"
echo "Configuring $hostname on $kernel"

if [ "$currusername" != "root" ]
then
	read -p "Did you already set root password? [y/n] " \
	changerootpassword
	case $changerootpassword in
		n)
			sudo passwd
			
			# Re-run script as root
			echo "Login as root using previously created password"
			echo "Script will be re-executed"
			su root "$0"
			
			# Prevent from create infinite-loop and exit after run
			exit 0
			;;
		*)	
			echo "Skipping, logging-in as root"
			echo "Script will be re-executed"
			su root "$0"
			exit 0
			;;
	esac
fi

# Execute main functions 

newuser
confssh
software

echo "Configuration completed"
