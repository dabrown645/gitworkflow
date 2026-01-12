#!/usr/bin/env bash

# BRANCH=main

main() {
  CONFIGDIR="${XDG_CONFIG_DIR:-$HOME/.config}"
  PKGNAME=gitworkflow

  clone_pkg_to_configdir "${CONFIGDIR}" "${PKGNAME}"
  install_git_links "${CONFIGDIR}" "${PKGNAME}"
  install_script_links "${CONFIGDIR}" "${PKGNAME}"
}

clone_pkg_to_configdir() {
  local configdir=${1}
  local pkgname=${2}

  if [[ -d "${configdir}/${pkgname}" ]]; then
    echo "❌ ${configdir}/${pkgname} already exists rename or remove it and run again"
    exit 1
  else
    git clone --depth 1 --branch feature/worktree-scripts git@github.com:dabrown645/"${pkgname}".git "${configdir}/${pkgname}"
  fi

  # shellcheck disable=SC2034 # used for template substitution with envsubst
  read -rp "Enter name: " gname </dev/tty # needed to get input when executed via pipe
  # shellcheck disable=SC2034 # used for template substitution with envsubst
  read -rp "Enter email: " gemail </dev/tty # needed to get input when executed via pipe
  # shellcheck disable=SC2034 # used for template substitution with envsubst
  read -rp "Enter user: " guser </dev/tty # needed to get input when executed via pipe

  export gname gemail guser
  envsubst <"${configdir}/${pkgname}/gitconfig.tmpl" >"${configdir}/${pkgname}/gitconfig"
}

install_git_links() {
  local configdir=${1}
  local pkgname=${2}
  local checkfiles=".gitconfig .gitalias.txt .gitmessage.txt"

  setup_file_links "${checkfiles}" "${configdir}/${pkgname}" "${HOME}"
  echo "✅ git configs linked"
}

install_script_links() {
  local configdir=${1}
  local pkgname=${2}
  local bindir
  bindir=$(get_bin_dir)

  if ! mkdir -p "$bindir"; then
    echo "Error: Creating ${bindir}" >&2
    exit 1
  fi

  local scripts
  scripts=$(get_executable_scripts "${configdir}" "${pkgname}")

  setup_file_links "${scripts}" "${configdir}/${pkgname}/bin" "${bindir}"
  echo "✅ Scripts linked in ${bindir}"
}

setup_file_links() {
  local fileslist=${1}
  local link_from=${2}
  local link_to=${3}

  for file in ${fileslist}; do
    if [[ -L "${link_to}/${file}" ]]; then
      rm "${link_to}/${file}"
    else
      if [[ -f "${link_to}/${file}" ]]; then
        cp "${link_to}/${file}" "${link_to}/${file}.$(date --iso)-bkp"
      fi
    fi

    if [[ "${file:0:1}" == "." ]]; then
      ln -sf "${link_from}/${file:1}" "${link_to}/${file}"
    else
      ln -sf "${link_from}/${file}" "${link_to}/${file}"
    fi
  done
}

get_bin_dir() {
  # Prefer ~/.local/bin if it exists or is in PATH, otherwise use ~/bin
  if [[ -d "${HOME}/.local/bin" ]] || echo "${PATH}" | grep -q "${HOME}/.local/bin"; then
    echo "${HOME}/.local/bin"
  elif [[ -d "${HOME}/bin" ]] || echo "${PATH}" | grep -q "${HOME}/bin"; then
    echo "${HOME}/bin"
  else
    # Default to ~/.local/bin and create it
    echo "${HOME}/.local/bin"
  fi
}

get_executable_scripts() {
  local config_dir=${1}
  local pkgname=${2}
  local scripts_dir="${config_dir}/${pkgname}/bin"

  if [[ ! -d "${scripts_dir}" ]]; then
    echo "Error: Scripts directory not found: ${scripts_dir}" >&2
    exit 1
  fi

  local scripts
  scripts=$(find "${scripts_dir}" -type f -executable -exec basename {} \; | tr '\n' ' ')

  if [[ -z "${scripts}" ]]; then
    echo "Error: No executable scripts found in ${scripts_dir}" >&2
    exit 1
  fi

  echo "${scripts}"
}

# shellcheck disable=SC2317 # Safety to make sure we exit
if [[ -n "${BASH_SOURCE[0]}" && ${BASH_SOURCE[0]} != "${0}" ]]; then
  return 0 2>/dev/null || exit 0 # This block will exit if file was sourced
fi

main "${@}" # If not sourced run main
