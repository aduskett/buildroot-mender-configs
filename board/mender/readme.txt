Mender UEFI PC sample config
=====================

1. Build

  $ make mender_x86_64_efi_defconfig

  Add any additional packages required and build:

  $ make

2. Write the Pendrive

  The build process will create a Pendrive image called disk.img in
  output/images.

  Write the image to a pendrive:

  $ dd if=output/images/disk.img of=/dev/${pendrive}; sync

  Once the process is complete, insert it into the target PC and boot.

  Remember that if said PC has another boot device you might need to
  select this alternative for it to boot.

  You might need to disable Secure Boot from the setup as well.

3. Enjoy

Emulation in qemu
========================

Run the emulation with:

qemu-system-x86_64 \
    -M pc \
    -bios </path/to/OVMF_CODE.fd> \
    -drive file=output/images/disk.img,if=virtio,format=raw \
    -net nic,model=virtio \
    -net user

Note that </path/to/OVMF.fd> needs to point to a valid x86_64 UEFI
firmware image for qemu. It may be provided by your distribution as an
edk2 or OVMF package, in a path such as /usr/share/edk2/ovmf/OVMF_CODE.fd.

Optional arguments:
 - -enable-kvm to speed up qemu. This requires a loaded kvm module on the host
    system.
 - Add -smp N to emulate an SMP system with N CPUs.

The login prompt will appear in the serial window.

Tested with QEMU 3.1.1 on Fedora 30

Creating a mender-artifact
========================
Edit board/mender/post-image-efi.sh and uncomment the line:
create_mender_image "update-${BR2_VERSION}.mender" to create a mender file
automatically at the end of a build.

Using mender
========================
Please read the mender documentation at:
https://docs.mender.io/2.0/getting-started
