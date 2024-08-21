#!/bin/bash

# Print every Command being executed
#set -x

# Initialize Counter
loopDeviceCounter=0

# Automatically Convert based on /etc/crypttab Contents
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

        # Add Line to /etc/looptab
        echo -e "$loopDeviceCounter	$cryptDevicePath	$loopDevicePath" >> /etc/looptab

        # Increase Counter
        loopDeviceCounter=$((loopDeviceCounter+1))
    fi
done

# Setup Loop Devices on Live System
/usr/sbin/looptab

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
       if [[ "$value" == *"_crypt" ]]
       then
           # Build LOOP Device Name
           loopDeviceName=`echo $value | sed -E "s|^(/dev/mapper/)?([0-9a-zA-Z_-]+)_crypt$|\2_loop|"`

           # In some cases /dev/disk/by-id is also prefixed - remove it as well
           loopDeviceName=`echo $loopDeviceName | sed -E "s|^(/dev/disk/by-id/)?([0-9a-zA-Z_-]+)|\2|"`

           # If Device Name still ends with _crypt, replace it with _loop
           loopDeviceName=`echo $loopDeviceName | sed -E "s|^([0-9a-zA-Z_-]+)_(crypt)?$|\1_loop|"`

           # If the name contains something like "dm-uuid-CRYPT-LUKS2-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-" prior to the REAL name of the LUKS Device Name matching in /etc/crypttab, then remove that part
           # That usually indicates a previous Attempt to use the /dev/loop/xxx Device which unfortunately "zpool import" couldn't find
           loopDeviceName=`echo $loopDeviceName | sed -E "s|^(dm-uuid-CRYPT-LUKS[1-2]-[0-9a-fA-F]+-)?([0-9a-zA-Z_-]+)|\2|"`

           # Build LOOP Device Path
           loopDevicePath="/dev/loop/$loopDeviceName"

           # Echo
           echo "Assess whether to replace path=$value with path=$loopDevicePath in zpool"

           # Check that Loop Device Path / Symlink Exists
           if [ -L "$loopDevicePath" ]
           then
               # Echo
               echo "$loopDevicePath exists and is a Symlink. Performing Replacement."

               # Perform Replacement
               zpool set path=$loopDevicePath rpool $value

               # Wait a bit
               sleep 5
           else
               # Echo
               echo "$loopDevicePath does NOT exists and/or is NOT a Symlink. Skip Replacement."
           fi
       else
           # Echo
           echo "Device Path $value doesn't seem to indicate a LUKS Crypt Device"
       fi
    fi
done

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
