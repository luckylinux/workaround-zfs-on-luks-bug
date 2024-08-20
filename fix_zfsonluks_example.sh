#!/bin/bash

# Change First Disk's Path
zpool set path=/dev/loop/scsi-0QEMU_QEMU_HARDDISK_2ffa4b6e-dd82-4889-8_loop rpool dm-uuid-CRYPT-LUKS2-598ba15b7804484d925a153f47835664-scsi-0QEMU_QEMU_HARDDISK_2ffa4b6e-dd82-4889-8_crypt

# Change Second Disk's Path
zpool set path=/dev/loop/scsi-0QEMU_QEMU_HARDDISK_9ada2183-a2db-4937-a_loop rpool dm-uuid-CRYPT-LUKS2-ac03ed5e9cdf491aac236204501f6bec-scsi-0QEMU_QEMU_HARDDISK_9ada2183-a2db-4937-a_crypt

# Regenerate Cachefile
zpool set cachefile=/etc/zfs/zpool.cache rpool

# Regenerate Initramfs
update-initramfs -k all -u
