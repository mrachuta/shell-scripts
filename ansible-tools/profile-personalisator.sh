#!/usr/bin/env bash

PACKAGE_URL=https://github.com/mrachuta/dev-null/raw/master/profile-files.tar
arch_name=$(echo $PACKAGE_URL | rev | cut -d'/' -f 1 | rev)
folder_name=$(echo "$arch_name" | rev | cut -d'.' -f 2 | rev)

get_package() {

  echo "Downloading package with pre-configured files..."

  wget -O "/tmp/$arch_name" $PACKAGE_URL
  mkdir "/tmp/$folder_name"
  tar -xvf "/tmp/$arch_name" -C "/tmp/$folder_name"

  echo "Package downloaded!"
}

configure_bashrc() {

  echo "Copying bashrc"

  cp "/tmp/$folder_name/.bashrc" "/home/$1/.bashrc"

  echo "bashrc copied!"

}

configure_bash_aliases() {

  echo "Copying bash_aliases..."

  cp "/tmp/$folder_name/.bash_aliases" "/home/$1/.bash_aliases"

  echo "bash_aliases copied!"
}

configure_vim() {

  # Good source
  # https://vimawesome.com/

  plugin_list=(
    "https://github.com/luochen1990/rainbow"
    "https://github.com/martinda/jenkinsfile-vim-syntax"
    "https://github.com/ekalinin/dockerfile.vim"
    "https://github.com/python-mode/python-mode"
    "https://github.com/scrooloose/nerdcommenter"
    "https://github.com/itchyny/lightline.vim"
    "https://github.com/pangloss/vim-javascript"
    "https://github.com/chr4/nginx.vim"
  )

  echo "Configuring vim..."

  cp "/tmp/$folder_name/.vimrc" "/home/$1/.vimrc"

  # Install pathogen
  mkdir -p "/home/$1/.vim/autoload" "/home/$1/.vim/bundle" "/home/$1/.vim/colors"
  curl -LSso "/home/$1/.vim/autoload/pathogen.vim" "https://tpo.pe/pathogen.vim"

  # Install molokai theme
  wget -P "/home/$1/.vim/colors" \
    "https://github.com/tomasr/molokai/raw/master/colors/molokai.vim"

  # Install molokayo theme
  wget -P "/home/$1/.vim/colors" \
    "https://github.com/fmoralesc/molokayo/raw/master/colors/molokayo.vim"

  # Install plugins
  # Do not change!
  plugin_list_len=${#plugin_list[@]}

  for i in $(seq 0 $((plugin_list_len - 1))); do
    plugin_name=$(echo "${plugin_list[$i]}" | rev | cut -d'/' -f 1 | rev)
    echo "Installing plugin: $plugin_name"
    cd "/home/$1/.vim/bundle" && git clone "${plugin_list[$i]}"
  done

  echo "Configuration of vim finished!"
}

usage() {

  echo -e "Script for personalisation bash & other tools\n"
  echo "Usage: profile-personalisator.sh user"
  echo "Replace 'user' with your username"

}

main() {

  usage

  if [[ -n "$1" ]]; then
    get_package
    configure_bashrc "$1"
    configure_bash_aliases "$1"
    configure_vim "$1"
    echo "Run 'source ~/.bashrc' to see the changes"
  else
    usage
  fi
}

main "$1"
