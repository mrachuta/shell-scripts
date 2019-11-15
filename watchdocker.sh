#!/usr/bin/env bash

# Define containers for observing.
# If container is build from official image
# Set second parameter to None.
# If custom image is available, set second
# parameter as path to Dockerfile, keeping
# Dockerfile at the end, for example
# /home/user/docker/configs/custimg/Dockerfile

cont_list=(
  "tx_py=./config/uwsgi/Dockerfile"
  "tx_ng=None"
  "tx_pg=None"
  "tx_ad=None"
)

update () {

  cont_list_len=${#cont_list[@]}

  for i in $(seq 0 $[cont_list_len-1])
  do
    IFS="=" read -r -a c <<< "${cont_list[i]}"
    container_name=${c[0]}
    container_img_id=$(sudo docker inspect $container_name \
    --format {{.Image}})
    container_img_name=$(sudo docker inspect $container_img_id \
    --format '{{join .RepoTags ", "}}')
    case ${c[1]} in
      *"Dockerfile"|*"dockerfile")
        base_img_name=$(cat ${c[1]} | \
        awk 'match($0, /^FROM\s*(.*)$/, ary) {print ary[1]}')
        latest_base_img_id=$(sudo docker inspect $base_img_name \
        --format {{.Id}})
        echo -e "\nContainer:"
        echo "- $container_name"
        echo "container image:"
        echo "- $container_img_name"
        echo "base image:"
        echo "- $base_img_name"
        # Update base image, not directly container image
        echo "Trying to download latest image for $base_img_name"
        update_status=$(sudo docker pull $base_img_name | \
        awk 'match($0, /^Status:\s*(.*)$/, ary) {print ary[1]}')
        ;;
      "None"|"none"|"")
        echo -e "\nContainer:"
        echo "- $container_name"
        echo "container image:"
        echo "- $container_img_name"
        echo "Trying to download latest image for $container_img_name"
        # Update container image
        update_status=$(sudo docker pull $container_img_name | \
        awk 'match($0, /^Status:\s*(.*)$/, ary) {print ary[1]}')
        ;;
    esac

    # TODO: What with pip updates?

    if [[ "$update_status" == "Image is up to date for"* ]]
    then
      echo "Already in newest version"
      echo "Performing in-container update"
      sudo docker exec -it tx_py bash -c "apt-get update && apt-get dist-upgrade"
      #sudo docker-compose up -d --no-deps --build uwsgi
      sudo logger -t "thinkbox.pl_watchdocker" \
      "Container $container_name - image is up to date, update via apt performed"
    elif [[ "$update_status" == "Downloaded newer image for"* ]]
    then
      echo "New version available"
      echo "Performing container update"
      sudo docker-compose up -d --no-deps --build uwsgi
      # If variable is set
      if [[ -n "$base_img_name" ]]
      then
        echo "Deleting previous version of $container_img_name image"
        sudo docker image rm $container_img_id
      fi
      sudo logger -t "thinkbox.pl_watchdocker" \
      "Container $container_name - image was updated, container rebuild using new image"
    else
      echo "Unknown status"
      sudo logger -t "thinkbox.pl_watchdocker" \
      "Container $container_name - unknown status, check image updates manually"
    fi
  done

}

echo "=Watchdocker="
echo "Script checking, wheter updated image"
echo "is available for specific container."
echo "Could be used with containers made from"
echo "official repo images and custom images"

update
