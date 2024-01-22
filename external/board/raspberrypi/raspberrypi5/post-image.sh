#!/usr/bin/env bash
set -e
CWD=$(pwd)
BOARD_DIR=$(realpath "$(dirname "$0")")
BUILD_VERSION="2023.11.1"
CONFIG_TXT="${BOARD_DIR}/config.txt"
DATA_PART_SIZE="64M"
DEVICE_TYPE="raspberrypi5"
GENERATE_MENDER_IMAGE="false"
GENIMAGE_CFG="${BINARIES_DIR}/genimage.cfg"
IMAGES_DIR="${CWD}/external/images/${DEVICE_TYPE}"
RPI_FIRMWARE_OVERLAY_FILES_DIR="${BINARIES_DIR}/rpi-firmware/overlays"

# See https://northerntech.atlassian.net/browse/MEN-2585
generate_mender_bootstrap_artifact() {
  rm -rf "${BINARIES_DIR}"/data-part
  rm -rf "${BINARIES_DIR}"/data-part.ext4
  mkdir -p "${BINARIES_DIR}"/data-part
  img_checksum=$(sha256sum "${BINARIES_DIR}"/rootfs.ext4 |awk '{print $1}')
  "${HOST_DIR}"/bin/mender-artifact \
    write bootstrap-artifact \
    --artifact-name "${ARTIFACT_NAME}" \
    --device-type "${DEVICE_TYPE}" \
    --provides "rootfs-image.version:${ARTIFACT_NAME}" \
    --provides "rootfs-image.checksum:${img_checksum}" \
    --clears-provides "rootfs-image.*" \
    --output-path "${BINARIES_DIR}"/data-part/bootstrap.mender \
    --version 3
}


make_data_partition(){
  "${HOST_DIR}"/sbin/mkfs.ext4 \
  -d "${BINARIES_DIR}"/data-part \
  -r 1 \
  -N 0 \
  -m 5 \
  -L "data" \
  -O ^64bit "${BINARIES_DIR}"/data-part.ext4 "${DATA_PART_SIZE}"
}


generate_sdcard_image(){
  rm -rf "${BINARIES_DIR}"/boot.vfat
  sed "s/DEVICE_TYPE/${DEVICE_TYPE}.img/g" -i "${GENIMAGE_CFG}"
  mkdir -p "${IMAGES_DIR}"
  "${CWD}"/support/scripts/genimage.sh -c "${BINARIES_DIR}/genimage.cfg"
  echo "cp ${BINARIES_DIR}/${DEVICE_TYPE}.img ${IMAGES_DIR}/${DEVICE_TYPE}.img"
  cp "${BINARIES_DIR}/${DEVICE_TYPE}.img" "${IMAGES_DIR}/${DEVICE_TYPE}.img"
}


create_mender_image(){
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

# Check config.txt for dtoverlay= lines and do the following:
# - Ensure that a matching .dtbo file exists in rpi-firmware/overlays
# - Set #OVERLAY_DIR# to "overlays" if dtoverlay= lines are in config.txt
# - Remove the #OVERLAY_DIR# line completely if no dtoverlay= lines are in config.txt
#
# Essentially, this is a sanity check to make sure the dtoverlay lines will,
# at the very least, load a dtbo file.
parse_rpi_firmware_overlay_files() {
  overlay_files="False"
  while IFS= read -r line; do
    if [ "${line:0:1}" == "#" ]; then
      continue
    fi
    line=$(echo "${line}" |awk -F'=' '{print $2}' |awk -F',' '{print $1}')
    overlay_file="${RPI_FIRMWARE_OVERLAY_FILES_DIR}/${line}.dtbo"
    if [ ! -e "${overlay_file}" ]; then
      echo "Error: dtoverlay=${line} in ${BOARD_DIR}/config.txt but ${overlay_file} does not exist!"
      exit 1
    fi
    overlay_files="True"
  done < <(/usr/bin/grep "dtoverlay" "${CONFIG_TXT}")

  if [ "${overlay_files}" == "True" ]; then
    sed "s%#OVERLAY_DIR#%rpi-firmware/overlays%" "${BOARD_DIR}/genimage.cfg.in" > "${GENIMAGE_CFG}"
  else
    sed '/"#OVERLAY_DIR#",/d' "${BOARD_DIR}/genimage.cfg.in" > "${GENIMAGE_CFG}"
  fi
}

parse_args(){
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


main(){
  parse_args "${@}"
  parse_rpi_firmware_overlay_files
  generate_mender_bootstrap_artifact
  make_data_partition
  generate_sdcard_image
  create_mender_image
  exit $?
}
main "${@}"
