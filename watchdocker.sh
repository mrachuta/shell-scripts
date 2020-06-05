#!/usr/bin/env bash

# Uncomment line below for debugging
#set -x

# Define containers for observing.
# If container is build from official image
# Set second parameter to None.
# If custom image is available, set second
# parameter as path to Dockerfile, keeping
# Dockerfile at the end, for example
# /home/user/docker/configs/custimg/Dockerfile

# Set propper absolute path to docker-compose-yml file
compose_file=/home/user/projectname/docker-compose.yml
# Set logging tag
logging_tag="watchdocker"
# Set container list
cont_list=(
  "cont_one=/home/user/projectname/config/service_name/Dockerfile"
  "cont_two=None"
)

write_log() {

  logger -t "$logging_tag" "$1"

}

update() {

  cont_list_len=${#cont_list[@]}

  for i in $(seq 0 $((cont_list_len - 1))); do
    IFS="=" read -r -a c <<< "${cont_list[i]}"
    ctr_name=${c[0]}
    ctr_img_id=$(docker inspect "$ctr_name" \
      --format '{{.Image}}')
    ctr_img_name=$(docker inspect "$ctr_img_id" \
      --format '{{join .RepoTags ", "}}')
    serv_name=$(docker inspect "$ctr_name" \
      --format '{{ index .Config.Labels "com.docker.compose.service"}}')
    ctr_ls_img_id=$(docker inspect "$ctr_img_name-stable" \
      --format '{{.Id}}' 2>/dev/null)

    case ${c[1]} in
    *"Dockerfile" | *"dockerfile")
      ctr_base_img_name=$(cat "${c[1]}" | \
        awk 'match($0, /^FROM\s*(.*)$/, ary) {print ary[1]}')
      ctr_l_base_img_id=$(docker inspect "$ctr_base_img_name" \
        --format '{{.Id}}')
      ctr_ls_base_img_id=$(docker inspect "$ctr_base_img_name-stable" \
        --format '{{.Id}}' 2>/dev/null)
      echo -e "\nContainer:"
      echo "- $ctr_name"
      echo "service name:"
      echo "- $serv_name"
      echo "container image:"
      echo "- $ctr_img_name"
      echo "base image:"
      echo "- $ctr_base_img_name"
      # Update base image, not directly container image
      echo "Trying to download latest image for $ctr_base_img_name"
      echo "and then update $ctr_img_name"
      update_status=$(docker pull "$ctr_base_img_name" | \
        awk 'match($0, /^Status:\s*(.*)$/, ary) {print ary[1]}')
      ;;
    "None" | "none" | "")
      echo -e "\nContainer:"
      echo "- $ctr_name"
      echo "service name:"
      echo "- $serv_name"
      echo "container image:"
      echo "- $ctr_img_name"
      echo "Trying to download latest image for $ctr_img_name"
      # Update container image
      update_status=$(docker pull "$ctr_img_name" | \
        awk 'match($0, /^Status:\s*(.*)$/, ary) {print ary[1]}')
      ;;
    esac

    if [[ "$update_status" == "Image is up to date for"* ]]; then
      echo "Container's image already in newest version"
      echo "Performing in-container update"
      docker exec -it "$ctr_name" /bin/bash -c "apt-get update && apt-get dist-upgrade <<< 'Y'"
      if [[ $? != 0 ]]; then
        echo "Container $ctr_name - image is up to date but no permissions to update via apt"
        write_log "Container $ctr_name - image is up to date but no permissions to update via apt"
      else
        echo "Container $ctr_name - image is up to date, update via apt performed"
        write_log "Container $ctr_name - image is up to date, update via apt performed"
      fi
    elif [[ "$update_status" == "Downloaded newer image for"* ]]; then
      if [[ -n "$ctr_base_img_name" ]]; then
        echo "Container image will be updated, because new version of base image is available"
      else
        echo "Container image will be updated to latest available version"
      fi
      # Rebuild container to use new base image; service name must be provided
      docker-compose -f $compose_file up -d --no-deps --build --force-recreate "$serv_name"
      # Move previously used container image from latest to latest-stable
      echo "Retaging previously used image: $ctr_img_name to $ctr_img_name-stable"
      docker tag "$ctr_img_id" "$ctr_img_name-stable"
      # Delete old latest-stable container image if exist
      if [[ -n "$ctr_ls_img_id" ]]; then
        echo "Deleting old version of $ctr_img_name-stable image (from previoius run of script)"
        docker image rm "$ctr_ls_img_id" 2>/dev/null
      fi
      # Move previously used container base image from latest to latest-stable
      if [[ -n "$ctr_l_base_img_id" ]]; then
        echo "Retaging previously used base image: $ctr_base_img_name to $ctr_base_img_name-stable"
        docker tag "$ctr_l_base_img_id" "$ctr_base_img_name-stable"
        # Delete old latest-stable container base image if exist
        if [[ -n "$ctr_ls_base_img_id" ]]; then
          echo "Deleting old $ctr_base_img_name-stable"
          docker image rm "$ctr_ls_base_img_id" 2>/dev/null
        fi
      fi
      write_log \
        "Container $ctr_name - image was updated, container rebuild using new image"
    else
      echo "Unknown status"
      write_log \
        "Container $ctr_name - unknown status, check image updates manually (update_status=$update_status)"
    fi
  done

}

echo "=Watchdocker="
echo "Script checking, wheter updated image"
echo "is available for specific container."
echo "Could be used with containers made from"
echo "official repo images and custom images"

update
