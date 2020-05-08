#!/usr/bin/env bash

# Script for getting an new certificate/renewing
# an old certificate, using Let's Encrypt as
# certificate supplier.
# Script prepared for containerized environment
# with docker-compose.yml file.
# Works only with nginx.
# Based on https://github.com/wmnnd/nginx-certbot

# Set here necessary variables
init_path=/home/user/projectname
# Set below main domain (for example: mydomain.com as first element)
# this allow script to create valid directories
domains=(mydomain.com test.mydomain.com)
# Set e-mail for receiving info from letsencrypt
user_email="user@domain.com"
# Set to 1 if you would not to exceed query limit
# for example if you testing your solution
staging=1
# Changes here not recommended;
# biggest possible size already set
rsa_key_size=4096
# Set path for certbot configuration folder
cfg_path=$init_path/config/certbot
# Set path for docker-compose file
dc_path=$init_path/docker-compose.yml
# Set certbot's container name
cont_name="certbot_container"
# Set syslog tag
syslog_tag="certbot"

# Check wether config path exists
if ! [[ -d $cfg_path ]]; then
  mkdir -p $cfg_path
fi

# Check wheter docker/docker-compose is installed
if ! [[ -x "$(command -v docker)" ]] && [[ -x "$(command -v docker-compose)" ]]; then
  echo "Error: docker and/or docker-compose not installed"
  exit 1
fi

#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Set staging argument
if [[ $staging != "0" ]]; then
  staging_arg="--staging"
else
  staging_arg=""
fi

# Select appropriate email argument
case "$user_email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $user_email" ;;
esac

mount_points="-v $cfg_path:/etc/letsencrypt -v $cfg_path/www:/var/www/_letsencrypt"
log_cfg="--log-driver syslog --log-opt tag=$syslog_tag"

firstcert() {

  echo "Checking wheter nginx is running in container..."
  if [[ $(sudo docker ps | grep -c nginx) != "0" ]]; then
    sudo docker-compose -f "$dc_path" stop
    echo "Nginx container is stopped"
  else
    echo "Nginx container is not running"
  fi

  echo "Creating fake certificates for nginx..."

  virt_certp="/etc/letsencrypt/live/$domains"
  phy_certp="$cfg_path/live/$domains"
  mkdir -p "$phy_certp"

  sudo docker run --rm --name "$cont_name" \
    "$mount_points" "$log_cfg" \
    --entrypoint openssl certbot/certbot req \
    -x509 -nodes -newkey rsa:1024 -days 1 -keyout "$virt_certp/privkey.pem" \
    -out "$virt_certp/fullchain.pem" \
    -subj "/CN=localhost"
  # Copy fake certificate for OCSP Stapling
  sudo cp "$phy_certp/fullchain.pem" "$phy_certp/chain.pem"

  echo "Fake certificates for nginx created"

  echo "Starting nginx with fake certificates..."
  docker-compose -f "$dc_path up" -d

  echo "Nginx is running"

  echo "Deleting fake certificates..."

  sudo docker run --rm --name "$cont_name" \
    "$mount_points" "$log_cfg" \
    --entrypoint rm certbot/certbot \
    -Rf /etc/letsencrypt/live/$domains \
    /etc/letsencrypt/archive/$domains \
    /etc/letsencrypt/renewal/$domains.conf

  echo "Fake certs deleted"

  echo "Obtaining valid certificates for nginx..."
  sudo docker run --rm --name "$cont_name" \
    "$mount_points" "$log_cfg" \
    --entrypoint certbot certbot/certbot certonly \
    --webroot -w /var/www/_letsencrypt \
    "$staging_arg" \
    "$email_arg" \
    "$domain_args" \
    --rsa-key-size "$rsa_key_size" \
    --agree-tos \
    --force-renewal

  echo "If your browser still have problem with"
  echo "the certificate, reload nginx to see the changes"

}

renewcert() {

  echo "Renenewing certificates for $domains..."
  sudo docker run --rm --name "$cont_name" \
    "$mount_points" "$log_cfg" \
    --entrypoint certbot certbot/certbot renew \
    --webroot -w /var/www/_letsencrypt

  echo "Waiting 10 seconds to check syslog"
  sleep 10

  if [[ $(sudo tail -n 50 /var/log/syslog | grep -q "The following certs have been renewed") ]]; then
    echo "It seems, that certificate(s) were renewed; restarting services"
    sudo docker-compose -f "$dc_path" restart
  else
    echo "It seems, that certificates were not renewed; no restart required"
  fi

}

main() {

  echo "getcert.sh script for obtain/renew SSL certificate from letsencrypt.com"
  echo "use only for containerized nginx & certbot"
  echo ""

  case $1 in
    "-n" | "--newcert")
      echo "Starting job: get first certificates for $domains..."
      firstcert
      echo "Job finished!"
      ;;
    "-r" | "--renewcert")
      echo "Starting job: renew certificates for $domains..."
      renewcert
      echo "Job finished!"
      ;;
    *)
      echo "Unrecognized argument: $1"
      exit 1
      ;;
  esac

}

# Pass $1 as function argument
# for recognize job
main "$1"
