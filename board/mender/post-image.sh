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

if [[ -e ${BINARIES_DIR}/u-boot.bin ]]; then
  mv ${BINARIES_DIR}/u-boot.bin ${BINARIES_DIR}/kernel7l.img
fi

if [[ -e ${BINARIES_DIR}/config.txt ]]; then
  rm -rf ${BINARIES_DIR}/config.txt
fi

if [[ -e ${BINARIES_DIR}/cmdline.txt ]]; then
  rm -rf ${BINARIES_DIR}/cmdline.txt
fi


cat << __EOF__ >> "${BINARIES_DIR}/config.txt"
dtoverlay=vc4-fkms-v3d
dtoverlay=pi3-miniuart-bt
enable_uart=1

__EOF__

cat << __EOF__ >> "${BINARIES_DIR}/cmdline.txt"
root=\${mender_kernel_root} rootwait console=tty1 console=ttyAMA0,115200
__EOF__

function make_data_partition(){
  # Create the data partition
  if [[ -e ${BINARIES_DIR}/data-part.ext4 ]]; then
    rm -rf ${BINARIES_DIR}/data-part.ext4
  fi

  if [[ -d ${BINARIES_DIR}/data_part ]]; then
    rm -rf ${BINARIES_DIR}/data_part
  fi


  mkdir -p ${BINARIES_DIR}/data_part
  echo "device_type=raspberrypi4" > ${BINARIES_DIR}/data_part/device_type
  ${HOST_DIR}/sbin/mkfs.ext4 -d ${BINARIES_DIR}/data_part -r 1 -N 0 -m 5 -L "data" -O ^64bit ${BINARIES_DIR}/data-part.ext4 "${DATA_PART_SIZE}"
}

genimage                           \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"

exit $?
