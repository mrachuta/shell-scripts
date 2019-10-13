#!/usr/bin/env bash

# Script configure remote VPS (basic configuration)

HOSTNAME=$(hostname)
KERNEL=$(uname -r)
CURR_USER=$(whoami)

add_user() {
	
	echo "Configuring an user..."
	
	echo "Enter username of your new or existing user: "
	read new_user
	
	_pass_key() {
	
		read -p \
		"Do you want to add/change password for user $new_user? [y/n] " \
		change_pass
		case $change_pass in
			y|Y)
				passwd $new_user
				echo "Password for user $new_user was changed"
				;;
			*)
				echo \
				"Password for user $new_user will stay unchanged"
				;;
		esac
		read -p \
		"Do you want to add new ssh key to authorized_keys for user $new_user? [y/n] " \
		add_key
		case $add_key in
			y|Y)
				read -p "Enter url to key: " key_url
				if [ ! -d "/home/$new_user/.ssh/" ]
				then
					mkdir /home/$new_user/.ssh/
				fi
        
				# Option "-q" can be added to wget to completely hide an output
				wget -O - $key_url >> /home/$new_user/.ssh/authorized_keys
				if [ "$?" = 0 ]
				then
					echo "Key added for $new_user"
					chown $new_user:$new_user /home/$new_user/.ssh/authorized_keys
				else
					echo "Failed to add key for user $new_user"
				fi
				;;
			*)
				echo "Key will be not added for user $new_user"
				;;
		esac
    echo "Adding user $new_user to sudoers..."
    sudo adduser $new_user sudo
		read -p \
		"Do you want to set sudo for user $new_user passwordless? [y/n] " \
		passwordless_sudo
		case $passwordless_sudo in
			y|Y)
				echo -e "## Added by vpsconfigurator ##\n" >> /etc/sudoers
				echo -e "$new_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
				echo "Sudo will be passwordless for user $new_user"
				;;
			*)
				echo "Sudo will be password-protected for user $new_user"
				;;
		esac
		
	}

	case $(grep -c "^$new_user:" /etc/passwd) in
		1)
			echo "User $new_user already exists, skipping..."
			_pass_key
			;;
		0)
			echo "Creating new user $new_user"
			useradd -m -s $(which bash) $new_user
			_pass_key
			;;
	esac

}

configure_ssh() {
	
	echo "Configuring SSH service..."

	# List of params can be modified
	# source: https://medium.com/@jasonrigden/hardening-ssh-1bcb99cd4cef
	
	ssh_params=(
		"PasswordAuthentication=yes"
		"PermitRootLogin=no"
		"X11Forwarding=no"
		"IgnoreRhosts=yes"
		"UseDNS=yes"
		"PermitEmptyPasswords=no"
		"MaxAuthTries=3"
		"Protocol=2"
		"LogLevel=VERBOSE"
		"UsePrivilegeSeparation=sandbox"
		"KexAlgorithms=curve25519-sha256@libssh.org"
		"Ciphers=chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
		"MACs=hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com"
		"HostKey=/etc/ssh/ssh_host_ed25519_key"
		"HostKey=/etc/ssh/ssh_host_rsa_key"
	)
	
	# Do not change!
	ssh_params_len=${#ssh_params[@]}

	# Standard path to config
	conf_file=/etc/ssh/sshd_config
	
	echo "Backup of file is available in $conf_file.bak"
	cp $conf_file $conf_file.bak

	for e in $(seq 0 $[ssh_params_len-1])
	do
		param=${ssh_params[$e]}
		
		# Convert to array
		IFS="=" read -r -a i <<< "${param}"
		
		# Single lines allow to multiline
		new_value="## Changed by VPSConfigurator\n${i[0]} ${i[1]}"
		
    # Case if param already exists
		case_a="${i[0]}[[:blank:]]${i[1]}$"
    # Case for enabling two params with the same name but
    # another argument, (if param exists with required argument
    # uncomment them
		case_b="#${i[0]}[[:blank:]]${i[1]}$"
    # If param is commented and/or has another argument
		case_c="#*${i[0]}[[:blank:]].*$"
		
    # Custom delimiters added
    # https://unix.stackexchange.com/a/211838
		echo "Setting ${i[0]} param..."
		if [[ $(sed -n -e "\~^$case_a~p" $conf_file) ]]
		then
		  echo "${i[0]}=${i[1]} already presented, not overrided"
		elif [[ $(sed -n -e "\~^$case_b~p" $conf_file) ]]
		then
		  sed -i -e "s~^$case_b~$new_value~" $conf_file
		  echo "Changed to: ${i[0]}=${i[1]}"	
		elif [[ $(sed -n -e "\~^$case_c~p" $conf_file) ]]
		then
		  sed -i -e "s~^$case_c~$new_value~" $conf_file
		  echo "Changed to: ${i[0]}=${i[1]}"		
		else
		  # Parameter -e allow to escape newline character
		  echo -e "## Added by VPSConfigurator\n${i[0]} ${i[1]}" \
		  >> $conf_file
		  echo "${i[0]}=${i[1]} not presented, added"
		fi
		
	done
	
	read -p \
	"Do you want to rebuild moduli? This can take some time [y/n] " \
	rebuild_moduli
	
	case $rebuild_moduli in
	
		y|Y)
			echo "Rebuiliding moduli..."
			ssh-keygen -G moduli-2048.candidates -b 2048
			ssh-keygen -T moduli-2048 -f moduli-2048.candidates
			cp moduli-2048 /etc/ssh/moduli
			rm moduli-2048
			echo "Moduli rebuilded"
			;;
		*)
			echo "Moduli will be not rebuild"
			;;
			
	esac
		
	echo "Restarting SSH service..."
	sudo service ssh restart

	if [ "$?" != 0 ]
	then
		echo \
		"WARNING: service SSH not restarted properly, restart it manually!"
	else
		echo "Service SSH restarted properly"
	fi

}

install_soft() {
	
	echo "Configuring software..."
	
	# List of apps to be installed can be modified
	app_list=(
		"nano"
		"htop"
		"iputils-ping"
		"traceroute"
		)
	
	# Do not change!
	app_list_len=${#app_list[@]}
	
	echo "Performing package manager update..."
	sudo apt-get update
	echo "Performing system update..."
	sudo apt-get dist-upgrade
	echo "Installing software..."
	
	for i in $(seq 0 $[app_list_len-1])
	do
		echo "- ${app_list[$i]}"
		sudo apt-get install ${app_list[$i]}
	done

}	

echo "= VPSConfigurator ="
echo "Script performs basic system configuration for Debian"
echo "and Debian-based distros"
echo "Configuring $HOSTNAME on $KERNEL"

if [ "$CURR_USER" != "root" ]
then
	read -p "Did you already set root password? [y/n] " \
	change_root_pass
	case $change_root_pass in
		n|N)
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

add_user
configure_ssh
install_soft

echo "Configuration completed"
