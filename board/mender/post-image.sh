#!/usr/bin/env bash
set -e

BOARD_DIR="$(realpath $(dirname $0))"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
DATA_PART_SIZE="32M"
DEVICE_TYPE="raspberrypi3"
GENERATE_MENDER_IMAGE="false"
BUILD_VERSION="2019.11.1"

# Parse arguments.
function parse_args(){
    local o O opts
    o='o:d:g:v:'
    O='data-part-size:,device-type:,generate-mender-image:,build-version:'
    opts="$(getopt -n "${my_name}" -o "${o}" -l "${O}" -- "${@}")"
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


# Copy relevant boot files.
function copy_boot_files(){
  if [[ -e ${BINARIES_DIR}/u-boot.bin ]]; then
    cp ${BINARIES_DIR}/u-boot.bin ${BINARIES_DIR}/kernel7.img
  fi

  if [[ -e ${BINARIES_DIR}/config.txt ]]; then
    rm -rf ${BINARIES_DIR}/config.txt
  fi

  if [[ -e ${BINARIES_DIR}/cmdline.txt ]]; then
    rm -rf ${BINARIES_DIR}/cmdline.txt
  fi

  cp -drpf ${BOARD_DIR}/config.txt ${BINARIES_DIR}/config.txt
  cp -drpf ${BOARD_DIR}/cmdline.txt ${BINARIES_DIR}/cmdline.txt
}

# Generate the SDCard image.
function generate_image(){
  trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
  ROOTPATH_TMP="$(mktemp -d)"
  rm -rf "${GENIMAGE_TMP}"

  genimage                           \
    --rootpath "${ROOTPATH_TMP}"   \
    --tmppath "${GENIMAGE_TMP}"    \
    --inputpath "${BINARIES_DIR}"  \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"
}


function make_data_partition(){
  # Create the data partition
  if [[ -e ${BINARIES_DIR}/data-part.ext4 ]]; then
    rm -rf ${BINARIES_DIR}/data-part.ext4
  fi

  if [[ -d ${BINARIES_DIR}/data_part ]]; then
    rm -rf ${BINARIES_DIR}/data_part
  fi


  mkdir -p ${BINARIES_DIR}/data_part

  ${HOST_DIR}/sbin/mkfs.ext4 \
  -d ${BINARIES_DIR}/data_part \
  -r 1 \
  -N 0 \
  -m 5 \
  -L "data" \
  -O ^64bit ${BINARIES_DIR}/data-part.ext4 "${DATA_PART_SIZE}"
}


# Create a mender image.
function create_mender_image(){
  if [[ ${GENERATE_MENDER_IMAGE} == "true" ]]; then
    echo "Creating ${BINARIES_DIR}/${DEVICE_TYPE}-${BUILD_VERSION}.mender"
    ${HOST_DIR}/bin/mender-artifact \
      --compression lzma \
      write rootfs-image \
      -t ${DEVICE_TYPE} \
      -n ${BR2_VERSION} \
      -f ${BINARIES_DIR}/rootfs.ext2 \
      -o ${BINARIES_DIR}/${DEVICE_TYPE}-${BUILD_VERSION}.mender
  fi
}

# Main function.
function main(){
  parse_args "${@}"
  make_data_partition
  copy_boot_files
  generate_image
  create_mender_image
  exit $?

}
main "${@}"