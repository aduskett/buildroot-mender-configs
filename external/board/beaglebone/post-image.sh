#!/usr/bin/env bash
set -e
CWD=$(pwd)
BOARD_DIR=$(realpath "$(dirname "$0")")
BOARD_NAME="$(basename "${BOARD_DIR}")"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
FACTORY_PART_SIZE="32M"
DEVICE_TYPE="beaglebone"
GENERATE_MENDER_IMAGE="false"
BUILD_VERSION="2021.02.2"
IMAGES_DIR="${CWD}/external/images/${DEVICE_TYPE}"

# Parse arguments.
function parse_args(){
    local o O opts
    o='d:f:g:v:'
    O='device-type:,factory-part-size:,generate-mender-image:,build-version:'
    opts="$(getopt -o "${o}" -l "${O}" -- "${@}")"
    eval set -- "${opts}"
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        (-d|--device-type)
            DEVICE_TYPE="${2}"; shift 2
            ;;
        (-f|--factory-part-size)
            FACTORY_PART_SIZE="${2}"; shift 2
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


# Generate the SDCard image.
function generate_image(){
  sed "s/DEVICE_TYPE/${DEVICE_TYPE}.img/g" ${BOARD_DIR}/genimage.cfg > "${BINARIES_DIR}/genimage.cfg"
  mkdir -p "${IMAGES_DIR}"
  ${CWD}/support/scripts/genimage.sh -c "${BINARIES_DIR}"/genimage.cfg
  echo "cp ${BINARIES_DIR}/${DEVICE_TYPE}.img ${IMAGES_DIR}/${DEVICE_TYPE}.img"
  cp "${BINARIES_DIR}/${DEVICE_TYPE}.img" "${IMAGES_DIR}/${DEVICE_TYPE}.img"
  rm "${BINARIES_DIR}"/genimage.cfg
}


make_ext4_image(){
  PART_DIR="${1}"
  PART_LABEL="${2}"
  PART_SIZE="${3}"
  PART_NAME="${PART_LABEL}-part.ext4"

  cd "${BINARIES_DIR}"
  rm -rf "${PART_DIR}"
  rm -rf "${PART_NAME}"

  mkdir -p "${PART_DIR}"
  "${HOST_DIR}/sbin/mkfs.ext4" \
    -d "${PART_DIR}" \
    -r 1 \
    -m 5 \
    -L "${PART_LABEL}" \
    -O 64bit \
    "${BINARIES_DIR}/${PART_NAME}" "${PART_SIZE}"
  rm -rf "${BINARIES_DIR}/${PART_DIR}"
}


# Create a mender image.
function create_mender_image(){
  if [[ ${GENERATE_MENDER_IMAGE} == "true" ]]; then
    echo "Creating ${BINARIES_DIR}/${DEVICE_TYPE}-${BUILD_VERSION}.mender"
    "${HOST_DIR}"/bin/mender-artifact \
      --compression lzma \
      write rootfs-image \
      -t "${DEVICE_TYPE}" \
      -n "${BR2_VERSION}" \
      -f "${BINARIES_DIR}"/rootfs.ext2 \
      -o "${IMAGES_DIR}"/"${DEVICE_TYPE}"-"${BUILD_VERSION}".mender
  fi
}

# Main function.
function main(){
  parse_args "${@}"
  make_ext4_image "${BINARIES_DIR}/factory_part" "factory" "${FACTORY_PART_SIZE}"
  make_ext4_image "${BINARIES_DIR}/data_part" "data" "16M"
  generate_image
  create_mender_image
  exit $?

}
main "${@}"
