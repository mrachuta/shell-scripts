#!/usr/bin/env bash


# $1- user list(required)
# for single user pass: user1
# for more than one user pass: user1,user2,user3

# $2 - rebuild moduli (optional)
# if yes, pass: -m

# $3 - restart service (optional)
# if yes, pass -r

# List of params can be modified
# source: https://medium.com/@jasonrigden/hardening-ssh-1bcb99cd4cef

ssh_params=(
    "Port=28828"
    "PasswordAuthentication=no"
    "PermitRootLogin=no"
    "X11Forwarding=no"
    "IgnoreRhosts=yes"
    "UseDNS=yes"
    "PermitEmptyPasswords=no"
    "MaxAuthTries=3"
    "Protocol=2"
    "LogLevel=VERBOSE"
    "KexAlgorithms=curve25519-sha256@libssh.org"
    "Ciphers=chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
    "MACs=hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com"
    "HostKey=/etc/ssh/ssh_host_ed25519_key"
    "HostKey=/etc/ssh/ssh_host_rsa_key"
    "ClientAliveInterval=120"
    "ClientAliveCountMax=30"
    "IgnoreRhosts=yes"
    "GatewayPorts=yes"
    "AllowUsers=$1"
)

change_ssh_params() {

  echo "Changing SSHD params..."

  curr_datetime=$(date +%Y-%m-%d-%H_%M_%S)
  # Do not change!
  ssh_params_len=${#ssh_params[@]}

  # Standard path to config
  conf_file=/etc/ssh/sshd_config

  echo "Backup of file is available in $conf_file-$curr_datetime.bak"
  cp "$conf_file" "$conf_file-$curr_datetime.bak"

  for e in $(seq 0 $((ssh_params_len - 1))); do
    param=${ssh_params[$e]}

    # Convert to array
    IFS="=" read -r -a i <<<"${param}"

    # Single lines allow to multiline
    new_value="## Changed by ssh-configurator.sh\n${i[0]} ${i[1]}"

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
    if [[ $(sed -n -e "\~^$case_a~p" $conf_file) ]]; then
      echo "${i[0]}=${i[1]} already presented, not overrided"
    elif [[ $(sed -n -e "\~^$case_b~p" $conf_file) ]]; then
      sed -i -e "s~^$case_b~$new_value~" $conf_file
      echo "Changed to: ${i[0]}=${i[1]}"
    elif [[ $(sed -n -e "\~^$case_c~p" $conf_file) ]]; then
      sed -i -e "s~^$case_c~$new_value~" $conf_file
      echo "Changed to: ${i[0]}=${i[1]}"
    else
      # Parameter -e allow to escape newline character
      echo -e "## Added by ssh-configurator.sh\n${i[0]} ${i[1]}" \
        >>$conf_file
      echo "${i[0]}=${i[1]} not presented, added"
    fi

  done

  echo "All params changed!"

}

rebuild_moduli() {

    echo "Rebuiliding moduli..."
    # Check version of ssh-keygen and use proper command
    if ssh-keygen --help 2>&1 >/dev/null | grep 'M'; then
      echo "New version of ssh-keygen available"
      ssh-keygen -M generate -O bits=2048 moduli-2048.candidates
      ssh-keygen -M screen -f moduli-2048.candidates moduli-2048
    else
      echo "Old version of ssh-keygen available"
      ssh-keygen -G moduli-2048.candidates -b 2048
      ssh-keygen -T moduli-2048 -f moduli-2048.candidates
    fi
    cp moduli-2048 /etc/ssh/moduli
    rm moduli-2048
    echo "Moduli rebuilded!"

}

restart_ssh_service() {

    echo "Restarting SSH service..."
    sudo service ssh restart

    if [[ $? != 0 ]]; then
        echo \
        "WARNING: service SSH not restarted properly, restart it manually!"
        exit 1
    else
        echo "Service SSH restarted properly!"
    fi

}

usage() {

    echo -e "Script perform changes in SSH service\n"
    echo "Use as root!"
    echo "Usage: ssh-configurator.sh user [-m] [-r]"
    echo "Replace 'user' with your username (allow to login via SSH)"
    echo "You can also pass list of users, for example: user1,user2,user3"
    echo "-m - rebuild moduli (optional)"
    echo "-r - restart service (optional)"
    
}

main() {

    usage

    if [ -n "$1" ]; then
      change_ssh_params
    else
      exit 1
    fi

    case $2 in
    -m)
      rebuild_moduli
      ;;
    -r)
      restart_ssh_service
      ;;
    *)
      # https://unix.stackexchange.com/questions/287866/a-do-nothing-line-in-a-bash-script
      :
      ;;
    esac

    case $3 in
    -m)
      rebuild_moduli
      ;;
    -r)
      restart_ssh_service
      ;;
    *)
      exit 0
      ;;
    esac

}

# Pass arguments to function
main "$1" "$2" "$3"