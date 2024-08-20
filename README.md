# workaround-zfs-on-luks-bug
workaround-zfs-on-luks-bug

# Introduction
Workaround from https://github.com/openzfs/zfs/issues/15646#issuecomment-1870937865 to fix a barrage of `zio` Errors in cases where Pool Free Space is heavilty fragmented (apparently).

# Setup
Clone Repository:
```
git clone https://github.com/luckylinux/workaround-zfs-on-luks-bug.git
```

Run Setup:
```
./setup.sh
```

# Configuration File
The File `/etc/looptab` is used to define the List of Devices to be setup.

```
# Configured Loop Devices
# The Separator between the crypt device ("Source") and the Loop Device to be Created **MUST** be a TAB (\t)
/dev/mapper/ata-CT1000MX500SSD1_2XXXEXXXXXXX_crypt	/dev/loop/ata-CT1000MX500SSD1_2XXXEXXXXXXX_loop
/dev/mapper/ata-CT1000MX500SSD1_2XXXEXXXXXXX_crypt	/dev/loop/ata-CT1000MX500SSD1_2XXXEXXXXXXX_loop
```

# Converting Devices
In order to switch from LUKS Device (`/dev/mapper/XXXX`) to Loop Device (`/dev/loop/XXXX`) as VDEV (Disk) member of a ZFS Pool, the following Commands can be used on ZFS 2.2+ in order to replace the Disks **WITHOUT**:
- Requiring a LiveUSB (`zpool export rpool; zpool import rpool -d /dev/loop/XXXX -d /dev/loop/YYYY`)
- Requiring a Resilver (`zpool offline XXXX; zpool detach XXXX; zpool attach rpool /dev/YYYY /dev/loop/XXXX`) - you [cannot replace a Disk with itself](https://github.com/openzfs/zfs/issues/2076)

Documentation References:
- `man vdevprops`: The following native properties can be used to change the behavior of a vdev. 
                   `path`        The path to the device for this vdev
- `man zpool-get`: `zpool get all rpool all-vdevs`
- `man zpool-set`: `zpool set property=value rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt`

For Instance:
```
zpool get all rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```


Get Current Path:
```
zpool get path rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```

Set New Path for the First Disk:
```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2301E6992CB7_loop rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```

Set New Path for the Second Disk:
```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2302E69AD9D0_loop rpool ata-CT1000MX500SSD1_2302E69AD9D0_crypt
```

Run a Scrub after Changing Path(s):
```
zpool scrub rpool
```

Monitor Scrub Status:
```
watch 'zpool status -v'
```

LiveUSB: (Re)generate `/etc/zfs/zpool.cache` by forcing `zed` to restart:
```
killall zed; zed -F;
```

Force ZFS to generate cachefile:
```
zpool set cachefile=/etc/zfs/zpool.cache rpool
```

System Itself: using `systemctl`:
```
systemctl restart zfs-zed
```

Regenerate initramfs:
```
update-initramfs -v -k all -u
```
