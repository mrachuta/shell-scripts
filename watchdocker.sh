#!/usr/bin/env bash

# Define containers for observing.
# If container is build from official image
# Set second parameter to None.
# If custom image is available, set second
# parameter as path to Dockerfile, keeping
# Dockerfile at the end, for example
# /home/user/docker/configs/custimg/Dockerfile

# Set propper absolute path to docker-compose-yml file
compose_file=/home/user/projectname/docker-compose.yml
# Set tag gor syslog
logger_tag="watchdocker"
# Set container list
cont_list=(
  "cont_one=/home/user/projectname/config/service_name/Dockerfile"
  "cont_twoNone"
)

write_log () {

  sudo logger -t "$logger_tag" "$1"

}

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
    service_name=$(sudo docker inspect $container_name \
    --format '{{ index .Config.Labels "com.docker.compose.service"}}')
    container_latest_stable_img_id=$(sudo docker inspect "$container_img_name-stable" \
    --format {{.Id}} 2>/dev/null)
    case ${c[1]} in
      *"Dockerfile"|*"dockerfile")
        base_img_name=$(cat ${c[1]} | \
        awk 'match($0, /^FROM\s*(.*)$/, ary) {print ary[1]}')
        latest_base_img_id=$(sudo docker inspect $base_img_name \
        --format {{.Id}})
        echo -e "\nContainer:"
        echo "- $container_name"
        echo "service name:"
        echo "- $service_name"
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
        echo "service name:"
        echo "- $service_name"
        echo "container image:"
        echo "- $container_img_name"
        echo "Trying to download latest image for $container_img_name"
        # Update container image
        update_status=$(sudo docker pull $container_img_name | \
        awk 'match($0, /^Status:\s*(.*)$/, ary) {print ary[1]}')
        ;;
    esac
    if [[ "$update_status" == "Image is up to date for"* ]]
    then
      echo "Container's image already in newest version"
      echo "Performing in-container update"
      sudo docker exec -it tx_py bash -c "apt-get update && apt-get dist-upgrade <<< 'Y'"
      write_log "Container $container_name - image is up to date, update via apt performed"
    elif [[ "$update_status" == "Downloaded newer image for"* ]]
    then
      echo "New version of container's image available"
      echo "Performing image update"
      # Service name must be provided to rebuild using new image
      sudo docker-compose -f $compose_file up -d --no-deps --build $service_name
      # Make backup of new latest-stable
      sudo docker tag $container_img_id "$container_img_name-stable"
      # Delete old latest-stable
      if [[ -n "$container_latest_stable_img_id" ]]
      then
        echo "Deleting old-latest-stable version of $container_img_name image"
        sudo docker image rm $container_latest_stable_img_id
      fi
      wite_log \
      "Container $container_name - image was updated, container rebuild using new image"
    else
      echo "Unknown status"
      write_log \
      "Container $container_name - unknown status, check image updates manually (update_status=$update_status)"
    fi
  done

}

echo "=Watchdocker="
echo "Script checking, wheter updated image"
echo "is available for specific container."
echo "Could be used with containers made from"
echo "official repo images and custom images"

update
