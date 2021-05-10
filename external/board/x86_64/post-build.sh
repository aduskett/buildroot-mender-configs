#!/usr/bin/env bash
set -e
DEVICE_TYPE="buildroot-x86_64"
ARTIFACT_NAME="2021.02.1"

function parse_args(){
    local o O opts
    o='a:o:d:g:'
    O='artifact-name:,data-part-size:,device-type:,generate-mender-image:'
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
        (-a|--artifact-name)
            ARTIFACT_NAME="${2}"; shift 2
            ;;
        (--)
            shift; break
            ;;
        esac
    done
}

function main(){
  parse_args "${@}"
  mkdir -p "${TARGET_DIR}/var/run/mender"
  echo "device_type=${DEVICE_TYPE}" > "${TARGET_DIR}"/etc/mender/device_type
  echo "artifact_name=${ARTIFACT_NAME}" > "${TARGET_DIR}"/etc/mender/artifact_info
}

main "${@}"
