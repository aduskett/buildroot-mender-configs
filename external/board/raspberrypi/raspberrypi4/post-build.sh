#!/usr/bin/env bash
set -e
BOARD_DIR=$(realpath "$(dirname "$0")")
OPENSSH=$(grep "BR2_PACKAGE_OPENSSH" "${BR2_CONFIG}" |cut -d'=' -f2)
SSH_KEY_DIR="/data/ssh"
DEVICE_TYPE="raspberrypi4"
BUILD_VERSION="2021.02.1"

INITD="y"
if [[ ${SYSTEMD} == "y" ]]; then
  INITD="n"
fi


# Parse arguments.
function parse_args(){
    local o O opts
    o='o:d:g:v:'
    O='data-part-size:,device-type:,generate-mender-image:,build-version:'
    opts="$(getopt -o "${o}" -l "${O}" -- "${@}")"
    eval set -- "${opts}"
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        (-o|--data-part-size)
            DATA_PART_SIZE="${2}"; shift 2
            ;;
        (-d|--device-type)
            DEVICE_TYPE="${2}"; shift 2
            ;;
        (-g|--generate-mender-image)
            GENERATE_MENDER_IMAGE="${2}"; shift 2
            ;;
        (-v|--build-version)
            BUILD_VERSION="${2}"; shift 2
            ;;
        (--)
            shift; break
            ;;
        esac
    done
}


# If openssh is selected, we should change the ssh key directory to a place
# that won't be overwritten with every new update.
# Idealy, on a system with an eMMC, for security purposes these keys should
# live in a seperate partition that isn't wiped with a factory reset
# (IE: /factory or /persistent).However, in the case of the RPi, there is no
# eMMC, so /data/ is fine.
function sshd_fixup(){
  if [[ ${OPENSSH} == "y" ]]; then
    SSHD_CONFIG=${TARGET_DIR}/etc/ssh/sshd_config
    sed s#@SSH_KEY_DIR@#${SSH_KEY_DIR}#g -i "${TARGET_DIR}"/usr/bin/generate_new_ssh_host_keys
    sed "/AuthorizedKeysFile/c\AuthorizedKeysFile ${SSH_KEY_DIR}/authorized_keys" -i "${SSHD_CONFIG}"
    sed "/ssh_host_rsa_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_rsa_key" -i "${SSHD_CONFIG}"
    sed "/ssh_host_ed25519_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_ed25519_key" -i "${SSHD_CONFIG}"
    sed "/ssh_host_ecdsa_key/c\HostKey ${SSH_KEY_DIR}/ssh_host_ecdsa_key" -i "${SSHD_CONFIG}"
  fi
}

function main(){
  parse_args "${@}"
  sshd_fixup
  echo "device_type=${DEVICE_TYPE}" > "${TARGET_DIR}"/etc/mender/device_type
}

main "${@}"









