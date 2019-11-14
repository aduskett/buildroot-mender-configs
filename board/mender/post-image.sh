#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
DATA_PART_SIZE="32M"

function parse_args(){
    local o O opts
    o='o:'
    O='data-part-size:'
    opts="$(getopt -n "${my_name}" -o "${o}" -l "${O}" -- "${@}")"
    eval set -- "${opts}"
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        (-o|--data-part-size)
            DATA_PART_SIZE="${2}"; shift 2
            ;;
        (--)
            shift; break
            ;;
        esac
    done
}
parse_args "${@}"



trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"
rm -rf "${GENIMAGE_TMP}"

function make_data_partition(){
  # Create the data partition
  if [[ -e ${BINARIES_DIR}/data-part.ext4 ]]; then
    rm -rf ${BINARIES_DIR}/data-part.ext4
  fi

  if [[ -d ${BINARIES_DIR}/data_part ]]; then
    rm -rf ${BINARIES_DIR}/data_part
  fi


  mkdir -p ${BINARIES_DIR}/data_part
  ${HOST_DIR}/sbin/mkfs.ext4 -d ${BINARIES_DIR}/data_part -r 1 -N 0 -m 5 -L "data" -O ^64bit ${BINARIES_DIR}/data-part.ext4 "${DATA_PART_SIZE}"
}


function create_mender_image(){
  echo "Creating ${BINARIES_DIR}/${1}"
  ${HOST_DIR}/bin/mender-artifact \
    --compression lzma \
    write rootfs-image \
    -t BUILDROOT_DEVICE \
    -n ${BR2_VERSION} \
    -f ${BINARIES_DIR}/rootfs.ext2 \
    -o ${BINARIES_DIR}/${1}
}

make_data_partition

genimage                           \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"


# Uncomment this line to generate a mender artifact after the image is built.
# create_mender_image "buildroot-nanopi-neo-core2-${BR2_VERSION}.mender"

exit $?
