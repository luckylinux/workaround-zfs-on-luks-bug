#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# List of systems
REMOTE_SYSTEMS=()

REMOTE_SYSTEMS+=("pve12")
REMOTE_SYSTEMS+=("pve13")
REMOTE_SYSTEMS+=("pve16")

# Create Folder
mkdir -p analysis

# Change Folder
cd ${toolpath}/analysis || exit

# Loop
for REMOTE_SYSTEM in "${REMOTE_SYSTEMS[@]}"
do
    # Create Folder
    mkdir -p ${toolpath}/analysis/${REMOTE_SYSTEM}

    # Change Folder
    cd ${toolpath}/analysis/${REMOTE_SYSTEM} || exit

    # List Installed Packages
    #ssh root@${REMOTE_SYSTEM} "dpkg -l --no-pager | grep -E ^ii" > packages.txt
    ssh root@${REMOTE_SYSTEM} "dpkg -l --no-pager" > packages.txt

    # List Systemd Units
    ssh root@${REMOTE_SYSTEM} "systemctl list-units --no-pager" > systemctl-list-units.txt

    # List Systemd Unit Files
    ssh root@${REMOTE_SYSTEM} "systemctl list-unit-files --no-pager" > systemctl-list-unit-files.txt
done
