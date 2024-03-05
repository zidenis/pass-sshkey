#!/usr/bin/env bash

# pass-sshkey : Enhancing SSH Keys Management Workflow. 
# 2024 Denis Albuquerque https://github.com/zidenis/pass-sshkey

# pass-sshkey is a Password Store extension. See https://www.passwordstore.org/
# This extension augments the functionality of pass, the standard Unix password
# manager, in order to provide an enhanced SSH keys management workflow.

# Designed to streamline SSH key-pair management, this extension leverage 
# pass's robust encryption and organizational capabilities.
# Keys are managed both in Password Store and $HOME/.ssh/, while the 
# passphrase is securely encrypted only in Password Store.
# It seamlessly integrates with pass to generate random passphrases by default.
# Moreover, users retain the flexibility to define custom passphrases or opt
# for passphrase-less key generation. 

# For heightened security and convenience, users can utilize pass in conjunction
# with Tomb (the Crypto Undertaker) to create locked folders with their 
# password store. This enables safe transportation and concealment of SSH keys.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GPLv2. See http://www.gnu.org/licenses/ .
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY.

set -o pipefail 

SSHKEY_VERSION="pass-extension-sshkey v1.0.0"
SSHKEY_URL="https://github.com/zidenis/pass-sshkey"
SSHKEY_TYPES="dsa|ecdsa|ecdsa-sk|ed25519|ed25519-sk|rsa"

cmd_sshkey_usage() {
  cat <<-_EOF
Usage: 
    $(cmd_sshkey_generate_usage)
    $(cmd_sshkey_rm_usage)
    $(cmd_sshkey_restore_usage)
    $(cmd_sshkey_version_usage)
    $(cmd_sshkey_help_usage)
_EOF
}

cmd_sshkey_generate_usage() {
  echo "${PROGRAM} ${COMMAND} generate pass-name [-t keytype] [-b bits] [-p[passphrase], --pass[=passphrase]] [-c comment] [-v]"
}

cmd_sshkey_rm_usage() {
  echo "${PROGRAM} ${COMMAND} rm pass-name [-y] [-v]"
}

cmd_sshkey_restore_usage() {
  echo "${PROGRAM} ${COMMAND} restore [pass-name]"
}

cmd_sshkey_version_usage() {
  echo "${PROGRAM} ${COMMAND} version"
}

cmd_sshkey_help_usage() {
  echo "${PROGRAM} ${COMMAND} help [generate | rm | restore | ALL ]"
}

cmd_sshkey_help() {
  case "$1" in
    generate) cmd_sshkey_generate_help ;;
          rm) cmd_sshkey_rm_help ;;
     restore) cmd_sshkey_restore_help ;;
     version) cmd_sshkey_version_help ;;
          "") cmd_sshkey_usage ;;
         ALL) cmd_sshkey_version; echo; cmd_sshkey_generate_help; echo; cmd_sshkey_rm_help; echo; cmd_sshkey_restore_help; ;;
           *) die "Error: $1 is not a valid subcommand." ;;
  esac
}

cmd_sshkey_generate_help() {
  cat <<-_EOF
    $(cmd_sshkey_generate_usage)

        Creates an SSH key-pair and securely stores it in both 'Password Store' and '\$HOME/.ssh/'
        By default, the private key is created with a randomly generated passphrase provided by pass.
        The random passphrase properties are defined by pass environment variables like 
        \$PASSWORD_STORE_GENERATED_LENGTH and \$PASSWORD_STORE_CHARACTER_SET.

        However, you can specify a custom passphrase using '-p,--pass' option. If used without 
        an argument, the script prompts you to enter the passphrase interactively.
        A passphrase file is then saved in 'pass-name/passphrase' location.
        To create a key without a passphrase, use '-n, --nopass' option.
        The script outputs the generated SSH public key.

        Options:
            -b, --keybits           The number of bits in the key.
            -c, --clip              Put the passphrase on the clipboard and clear th board 
                                    after \$PASSWORD_STORE_CLIP_TIME seconds.
            -C, --comment           Provide a comment to help identify the key. 
            -n, --nopass            Creates a private key without a passphrase. 
            -p, --pass              Defines a custom passphrase for the private key.
                                    If used without an argument, the passphrase is prompted.
            -t, --keytype           Specifies the type of the key.
                                    Valid types: $SSHKEY_TYPES
            -v, --verbose           Enables verbose output.
_EOF
}

cmd_sshkey_rm_help() {
  cat <<-_EOF
    $(cmd_sshkey_rm_usage)

      Remove existing ssh key-pairs and passphrases from 'Password Store' and also from '\$HOME/.ssh/' directory.
      Caution: likewise 'pass rm --recursive pass-name', 'sshkey rm' removes the entire pass-name directory tree.

      Options:
          -y                        Remove the key-pairs without confirmation. 
          -v, --verbose    
_EOF
}

cmd_sshkey_restore_help() {
  cat <<-_EOF
    $(cmd_sshkey_restore_usage)

      Restore ssh keys found in 'Password Store' to '\$HOME/.ssh/' directory.
      Only private and public keys are restored. Passphrases files remains in 'Password Store' only.
      Usefull to, for example, after moving your Password Store to a new machine.
      If provided, 'pass-name' will specify which keys should be restored.
      Otherwise, all keys found in 'Password Store' will be restored.
          
_EOF
}

cmd_sshkey_version() {
  echo "${SSHKEY_VERSION}"
  echo "${SSHKEY_URL}"
}

cmd_sshkey_generate() {
  # Parsing arguments
  local opts keytype="rsa" keybits=4096 passphrase="" comment="" verbose=0 pass=0 nopass=0 clip=0
  opts="$($GETOPT -o t:b:p::C:vnc -l keytype:,keybits:,pass::,comment:,verbose,nopass,clip -n "$PROGRAM $COMMAND" -- "$@")"
  local err=$?
  [[ $err -ne 0 ]] && die
  eval set -- "$opts"
  while true; do case $1 in
    -b|--keybits) keybits=$2; shift 2 ;;
       -c|--clip) clip=1; shift ;;
    -C|--comment) comment=$2; shift 2 ;;
    -t|--keytype) keytype="$2"; shift 2 ;;
     -n|--nopass) nopass=1; shift ;;
       -p|--pass) pass=1
                  passphrase="$2"
                  shift 2 ;;
    -v|--verbose) verbose=1; shift ;;
              --) shift; break ;;
  esac done

  # Arguments validation
  [[ ${keybits} != ?(-)+([[:digit:]]) ]] && die "Error: ${keybits} is an invalid value for keybits (-b) option."
  eval "case \"${keytype}\" in
    ${SSHKEY_TYPES}) ;;
                  *) die \"Error: ${keytype} is an invalid value for keytype (-t) option.\"
  esac"
  [[ $# -eq 0 ]] && die "Error: one pass-name should be provided."
  [[ $# -ne 1 ]] && die "Error: wrong number of arguments."
  [[ ${pass} -eq 1 && ${nopass} -eq 1 ]] && die "Error: can't use both -p,--pass and -n,--nopass."

  local pass_name="$1"
  check_sneaky_paths "${pass_name}"

  # Define ssh key-pair names and test if files already exists
  local keyname privkey local_privkey local_pubkey datastore_privkey datastore_pubkey
  privkey=$(realpath -m -q -s --relative-base="$(pwd)" "${pass_name}") # canonicalize file path
  privkey="${privkey#/}" # Remove optional leading slash
  privkey=$(tr '/' '-' <<< "${privkey}")-id_${keytype} # convert slash to dash
  local_privkey="${HOME}/.ssh/${privkey}"
  local_pubkey="${HOME}/.ssh/${privkey}.pub"
  keyname="id_${keytype}"
  datastore_privkey="${PREFIX}/${pass_name}/${keyname}.gpg"
  datastore_pubkey="${PREFIX}/${pass_name}/${keyname}.pub.gpg"

  [[ -e "${local_privkey}" ]] && die "Error: private key ${local_privkey} already exists."
  [[ -e "${local_pubkey}" ]] && die "Error: public key ${local_pubkey} alteady exists." 
  [[ -e "${datastore_privkey}" ]] && die "Error: private key ${datastore_privkey} alteady exists."
  [[ -e "${datastore_pubkey}" ]] && die "Error: public key ${datastore_pubkey} alteady exists."

  # passphrase generation
  if [ "${nopass}" -eq 1 ]; then
    [[ "${verbose}" -eq 1 ]] && echo "Creating key without a passphrase ..."
  else
    if [ "${pass}" -eq 1 ]; then
      if [ -z "${passphrase}" ]; then
        [[ "${verbose}" -eq 1 ]] && echo "Prompting for custom passphrase ..."
        read -r -p "Enter passphrase for ${pass_name}: " -s passphrase
      fi
      [[ "${verbose}" -eq 1 ]] && echo "Creating key with custom passphrase ..."
      mkdir -p -v "${PREFIX}/${pass_name}"
      set_gpg_recipients "$(dirname "${pass_name}")"
      echo "${passphrase}" | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "${PREFIX}/${pass_name}/passphrase.gpg" "${GPG_OPTS[@]}" || die "Password encryption aborted." 
    else
      [[ "${verbose}" -eq 1 ]] && echo "Creating key with a random ${GENERATED_LENGTH} length passphrase ..."
      pass generate "${pass_name}/passphrase" > /dev/null      
    fi
    if [ "${clip}" -eq 1 ]; then
      pass "${pass_name}/passphrase" -c > /dev/null
      [[ "${verbose}" -eq 1 ]] && echo "Copied ${pass_name}/passphrase to clipboard. Will clear in ${CLIP_TIME} seconds."
    fi
    passphrase=$(pass "${pass_name}/passphrase")
  fi

  # keys generation
  [[ "${verbose}" -eq 1 ]] && echo "Generating ssh key-pair ..."
  ssh-keygen -b "${keybits}" -t "${keytype}" -f "${local_privkey}" -N "${passphrase}" -q -C "${comment}" || die "Error: key generation failed" 
  [[ "${verbose}" -eq 1 ]] && [[ -f "${local_privkey}" ]] && [[ -f "${local_pubkey}" ]] && echo "SSH key-pair saved in ~/.ssh/ ."
  pass insert -m "${pass_name}/${keyname}" < "${local_privkey}" > /dev/null
  pass insert -m "${pass_name}/${keyname}.pub" < "${local_pubkey}" > /dev/null
  [[ "${verbose}" -eq 1 ]] && [[ -f "${datastore_privkey}" ]] && [[ -f "${datastore_pubkey}" ]] && echo "SSH key-pair saved in password store."

  # Managing git repo
  set_git "${datastore_privkey}"
  if [[ -n $INNER_GIT_DIR ]]; then
		git -C "$INNER_GIT_DIR" add "${datastore_privkey}" "${datastore_pubkey}" 
		git_commit "Add ssh key-pair for ${pass_name}" > /dev/null
	fi

  # Output
  cat "${local_pubkey}"
}

cmd_sshkey_find() {
  echo "Password Store"
  pass find id_ passphrase | tail +2
}

cmd_sshkey_rm() {
  # Parsing arguments
  local opts force=0
  opts="$($GETOPT -o yv -n "$PROGRAM $COMMAND" -- "$@")"
  local err=$?
  [[ $err -ne 0 ]] && die
  eval set -- "$opts"
  while true; do case $1 in
      -f|--force) force=1; shift ;;
              --) shift; break ;;
  esac done

  # Arguments validation
  [[ $# -eq 0 ]] && die "Error: one pass-name should be informed."
  [[ $# -ne 1 ]] && die "Error: wrong number of arguments."
  local pass_name="$1"
  check_sneaky_paths "${pass_name}"

  # Deleting pass-name files
  if [ -d "${PREFIX}/${pass_name}" ]; then
    echo "${pass_name} found in the Password Store"
    if [ ${force} -eq 1 ]; then pass rm -r -f "${pass_name}"
    elif ! pass rm -r "${pass_name}"; then exit $?
    fi
  else
    echo "${pass_name} not found in the Password Store"
    exit 0
  fi

  # Deleting local keys files
  local local_keys_pattern local_keys_files
  local_keys_pattern=$(realpath -m -q -s --relative-base="$(pwd)" "${pass_name}") # canonicalize file path
  local_keys_pattern="${local_keys_pattern#/}" # Remove optional leading slash
  local_keys_pattern=$(tr '/' '-' <<< "${local_keys_pattern}")
  local_keys_files=$(find ~/.ssh -type f -regextype posix-egrep -regex ".*/${local_keys_pattern}.*-id_(${SSHKEY_TYPES})(\.pub)?" -exec basename {} -print0 \; | xargs)
  if [ -n "${local_keys_files}" ]; then
    echo "Keys files in ~/.ssh/ to be deleted:"
    echo "    ${local_keys_files}"
    if [ ${force} -eq 1 ]; then find ~/.ssh -type f -regextype posix-egrep -regex ".*/${local_keys_pattern}.*-id_(${SSHKEY_TYPES})(\.pub)?" -exec rm -fv {} \;
    else
      yesno "Are you sure you would like to delete?"
      find ~/.ssh -type f -regextype posix-egrep -regex ".*/${local_keys_pattern}.*-id_(${SSHKEY_TYPES})(\.pub)?" -exec rm -fv {} \;
    fi
  fi
}

cmd_sshkey_restore() {
  local pass_filter
  [[ -n $1 ]] && pass_filter="$1/"
  for pass_name in $(find "${PREFIX}" -type f -regextype posix-egrep -regex ".*/${pass_filter}id_(${SSHKEY_TYPES})(\.pub)?\.gpg" -exec realpath --relative-to "${PREFIX}" {} \; | rev | cut -c5- | rev | xargs); do
    local keyname 
    keyname=$(tr '/' '-' <<< "${pass_name}") # convert slash to dash
    [[ -e "${HOME}/.ssh/${keyname}" ]] && echo "${HOME}/.ssh/${keyname} already exists." >&2 && continue
    pass show "${pass_name}" > "${HOME}/.ssh/${keyname}"
    echo "${pass_name} restored to ${HOME}/.ssh/${keyname}"
  done
}

main() {
  [[ ! -f "${PREFIX}/.gpg-id" ]] && die "Error: password store not found in ${PREFIX}. Check if password store was properly initialized."
  
  case "$1" in
          generate) shift; cmd_sshkey_generate "$@" ;;
                rm) shift; cmd_sshkey_rm "$@" ;;
           restore) shift; cmd_sshkey_restore "$@" ;;
           version) shift; cmd_sshkey_version ;;
    help|--help|-h) shift; cmd_sshkey_help "$@" ;;
                "") shift; cmd_sshkey_find ;;
    *)                     die "Error: $1 is not a valid command." ;;
  esac
}

main "$@"
exit 0
