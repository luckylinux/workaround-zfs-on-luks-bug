#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# If /etc/looptab does NOT exist yet, copy Example File
if [ ! -f "/etc/looptab" ]
then
   # Copy Example File
   cp etc/looptab /etc/looptab
fi

# Copy initramfs-tools Hooks
cp -r etc/initramfs-tools/hooks/* /etc/initramfs-tools/hooks/

# Copy initramfs-tools Scripts
cp -r etc/initramfs-tools/scripts/* /etc/initramfs-tools/scripts/
