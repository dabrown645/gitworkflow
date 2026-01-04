#!/usr/bin/env bash

CONFIGDIR="${XDG_CONFIG_DIR:-$HOME/.config}"
BRANCH=main

main() {
  clone_configuration

  # Setup links
  checkfiles=".gitconfig .gitalias.txt .gitmessage.txt"

  check_link_files "${checkfiles}" "${CONFIGDIR}/gitworkflow/${BRANCH}" "${HOME}"
}

clone_configuration() {
  # Clone the configuration
  if [[ -d "${CONFIGDIR}/gitworkflow" ]]; then
    echo "❌ ${CONFIGDIR}/gitworkflow already exists rename or remove it and run again"
    exit 1
  else
    git clone --depth 1 git@github.com:dabrown645/gitworkflow.git "${CONFIGDIR}/gitworkflow"
    cd "${CONFIGDIR}/gitworkfile" || exit
    git worktree add "${BRANCH}"
    cd - || exit
  fi

  # Setup github gitconfig file
  # shellcheck disable=SC2034 # used for template substition with envsubstr
  read -rp "Enter name: " GNAME
  # shellcheck disable=SC2034 # used for template substition with envsubstr
  read -rp "Enter email: " GEMAIL
  # shellcheck disable=SC2034 # used for template substition with envsubstr
  read -rp "Enter user: " GUSER

  envsubst <gitconfig.tmpl >gitconfig
}

check_link_files() {
  fileslist=${1}
  link_from=${2}
  link_to=${3}

  for file in ${fileslist}; do
    if [[ -f "${link_to}/${file}" ]]; then
      cp "${link_to}/${file}" "${link_to}/${file}.$(date --iso)-bkp"
    else
      if [[ -L "${link_to}/${file}" ]]; then
        rm "${link_to}/${file}"
      else
        "❌ ${link_to}/${file} not found"
      fi
    fi

    if [[ "${file:0:1}" == "." ]]; then
      ln -sf "${link_from}/${file:1}" "${link_to}/${file}"
    else
      ln -sf "${link_from}/${file}" "${link_to}/${file}"
    fi

  done
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "${@}"
fi
