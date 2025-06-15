#!/bin/bash

# Print every Command being executed
# set -x

# Automatically Remove Lines in /etc/looptab based on /etc/crypttab Contents
# Iterate over each Device
cat /etc/crypttab | grep -vE "^#" | while IFS= read -r line;
do
    # Extract Crypt Device Name
    cryptDeviceName=`echo $line | sed -E "s|^\s*?([0-9a-zA-Z_-]+)\s*?.*$|\1|"`

    # Build Crypt Device Path
    cryptDevicePath="/dev/mapper/$cryptDeviceName"

    # Check if Crypt Device Actually Exists (and that line was NOT empty)
    if [ -b "$cryptDevicePath" ]
    then
        # Build Loop Device Name
        loopDeviceName=`echo $cryptDeviceName | sed -E "s|^([0-9a-zA-Z_-]+)_crypt$|\1_loop|"`

        # Build Loop Device Path
        loopDevicePath="/dev/loop/$loopDeviceName"

        # Remove Line to /etc/looptab
        sed -Ei "s|^[0-9]+	$cryptDevicePath	$loopDevicePath.*||g" /etc/looptab
    fi
done

# Perform "path" replacement for each vdev
zpool get -H -o value path rpool all-vdevs | while IFS= read -r value;
do
    # Echo
    echo "Processing Path $value"

    # Check if it's a Block Device
    if [ -b "$value" ]
    then
       # Echo
       echo "$value is a valid Block Device"

       # Check if it's the original LUKS Device Name
       if [[ "$value" == *"_loop" ]]
       then
           # Set LUKS Device Name to initial Value
           luksDeviceName="$value"

           # Set LUKS Device Name
           luksDeviceName=`echo $luksDeviceName | sed -E "s|^(/dev/loop/)?([0-9a-zA-Z_-]+)_loop$|\2_crypt|"`

           # If Device Name still ends with _loop, replace it with _crypt
           luksDeviceName=`echo $luksDeviceName | sed -E "s|^([0-9a-zA-Z_-]+)_(loop)?$|\1_crypt|"`

           # Build LUKS Device Path
           luksDevicePath="/dev/mapper/$luksDeviceName"

           # Echo
           echo "Assess whether to replace path=$value with path=$luksDevicePath in zpool"

           # Check that Loop Device Path / Symlink Exists
           if [ -L "$luksDevicePath" ]
           then
               # Echo
               echo "$luksDevicePath exists and is a Symlink. Performing Replacement."

               # Perform Replacement
               zpool set path=$luksDevicePath rpool $value

               # Wait a bit
               sleep 5
           else
               # Echo
               echo "$luksDevicePath does NOT exists and/or is NOT a Symlink. Skip Replacement."
           fi
       else
           # Echo
           echo "Device Path $value doesn't seem to indicate a LUKS Crypt Device"
       fi
    fi
done

# Force ZFS to use the newly configured path
zpool reopen
zpool reopen rpool

# Configure /etc/default/zfs automatically
sed -Ei "s|^ZPOOL_IMPORT_OPTS=\"\"|#ZPOOL_IMPORT_OPTS=\"\"|" /etc/default/zfs
sed -Ei "s|^#ZPOOL_IMPORT_OPTS=\"-c /etc/zfs/zpool.cache\"|ZPOOL_IMPORT_OPTS=\"-c /etc/zfs/zpool.cache\"|" /etc/default/zfs
sed -Ei "s|^#ZPOOL_CACHE=\"\"|ZPOOL_CACHE=\"\"|" /etc/default/zfs

# Regenerate Cachefile
zpool set cachefile=/etc/zfs/zpool.cache rpool

# Mount /boot if not mounted yet
if mountpoint -q "/boot"
then
   # Already Mounted
   x=1
else
   # Mount /boot
   mount /boot
fi

# Regenerate Initramfs
update-initramfs -k all -u

# Update GRUB
update-grub
