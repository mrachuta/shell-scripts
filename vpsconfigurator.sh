#!/bin/bash

# Script configure remote VPS (basic confiuguration)

echo "Host configuration script for Debian-based systems"

hostname=$(hostname)
kernel=$(uname -r)
currusername=$(whoami)

echo "Configuring $HOSTNAME on $KERNEL"
echo "Checking that script is running as root..."

if [ "$currusername" != "root" ]
then
        echo "Run on root account"
        exit 1
fi

echo "Enter username for your new user:"
read newusername

echo "Creating new user $newusername"

case $(grep -c "^$USERNAME:" /etc/passwd) in
        1)
                echo "User already exists, skipping..."
                ;;
        0)      useradd $newusername
                echo "Type password for new user $newusername:"
                passwd $newusername
                echo "Adding user $newusername to sudo"
                sudo adduser $newusername sudo
                ;;
esac

echo "Performing package manager update"
sudo apt-get update
echo "Performing system update"
sudo apt-get dist-upgrade
echo "Installing software"
echo "- nano"
sudo apt-get install nano
echo "- htop"
sudo apt-get install htop
echo "- iputils-ping"
sudo apt-get install iputils-ping
echo "- traceroute"
sudo apt-get install traceroute

echo "Configuration completed"
return 0

