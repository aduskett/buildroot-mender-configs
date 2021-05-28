#!/usr/bin/env bash
set -e
BOARD_DIR=$(realpath "$(dirname "$0")")
SSH_KEY_DIR="/factory/ssh"
DEVICE_TYPE="beaglebone"
BUILD_VERSION="2021.02.2"

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

setup_mender(){
  cd "${TARGET_DIR}"
  rm -rf var/lib/mender
  # fw_printenv needs /var/lock
  mkdir -p var/lock
  cd var/lib
  ln -s ../../data/ mender
  cd ${CWD}
  echo "artifact_name=${BUILD_VERSION}" > "${TARGET_DIR}"/etc/mender/artifact_info
  echo "device_type=${DEVICE_TYPE}" > "${TARGET_DIR}"/etc/mender/device_type
}

function main(){
  parse_args "${@}"
  setup_mender
}

main "${@}"









