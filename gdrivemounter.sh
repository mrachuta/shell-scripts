#!/usr/bin/env bash

# Script mounts multiple google-drives
# Install google-drive-ocamlfuse package:
# https://github.com/astrada/google-drive-ocamlfuse
# Usage: add username(s) to 'accounts' array: e.g. ("jon" "jon2")
# Run script manually to login to each account
# Add script to autostart to keep drives available each login

accounts=(
  "rah6061"
  "rah60611"
  "rah606111"
)

# If you use script as systemd service, you ned to
# add path to google-drive-ocamlfuse manually

check_connection() {

  max_try=3
  curr_try=1

  while [ $max_try -gt 0 ]
  do
    echo "Checking internet connection, try $curr_try"
    wget -q --spider https://google.com
    if [ $? -eq 0 ]
    then
      echo "Online, drives will be mounted"
      export GDRIVEMOUNTER_NET_CONNECTION=true
      return 0
    else
      echo "Offline"
      let max_try=max_try-1
      let curr_try=curr_try+1
      sleep 60
    fi
  done

  echo "Offline, unable to mount drives"
  xmessage -buttons Ok:0 -center -default Ok "Offline, unable to mount drives" -timeout 10

  return 1
}

unmount_drives() {

  for i in ${!accounts[*]}
  do
    echo "Unmounting drive related to account: ${accounts[$i]}"
    fusermount -u /media/${accounts[$i]}
    sleep 5
  done

  echo "All drives unmounted"

}

mount_drives() {

  check_connection

  if [ "$GDRIVEMOUNTER_NET_CONNECTION" == "true" ]
  then
    for i in ${!accounts[*]}
    do
      echo "Mounting drive related to account: ${accounts[$i]}"
      sleep 15
      google-drive-ocamlfuse -label ${accounts[$i]} /media/${accounts[$i]}
    done
    echo "All google-drives mounted"
    xmessage -buttons Ok:0 -center -default Ok "All google-drives mounted" -timeout 10
    return 0
  fi

}

display_help() {

  echo "Script mounts multiple google-drives"
  echo "google-drive-ocamlfuse must be installed"
  echo "for more information see sourcel"
  echo ""
  echo "Use -m or --mount to mount drives"
  echo "Use -u or --unmount to unmount drives"
  echo "Use -h or --help to display this help"

}


if [ ! "$(which google-drive-ocamlfuse)" ]
then
  echo "Install google-drive-ocamlfuse first!"
  exit 1
fi

case "$1" in
  "")
  mount_drives
  ;;
  -m|--mount)
  mount_drives
  ;;
  -u|--unmount)
  unmount_drives
  ;;
  -h|--help)
  display_help
  ;;
  *)
  echo "Unknown option, type -h for help"
  ;;
esac

