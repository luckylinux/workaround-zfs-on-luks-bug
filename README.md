# workaround-zfs-on-luks-bug
workaround-zfs-on-luks-bug

# Introduction
Workaround from https://github.com/openzfs/zfs/issues/15646#issuecomment-1870937865 to fix a barrage of `zio` Errors in cases where Pool Free Space is heavilty fragmented (apparently).

There are some Limitations of the `losetup` Executable/Binary included by default in the Initramfs: it only provides a very lightweight Implementation, probably in order to limit the RAM Disk Size.

In particular the `--show` Option is NOT recognized, which makes it difficult to tell `losetup` to automatically do its Stuff (with `-f`) but NOT knowing which device it decided to use in the End.

For this reason, the Loop Device ID will need to be manually specified in the `/etc/looptab` Configuration File.

# Setup
Clone Repository:
```
git clone https://github.com/luckylinux/workaround-zfs-on-luks-bug.git
```

Run Setup (also in case of Updates):
```
./setup.sh
```

In case the Configuration File `/etc/looptab` does NOT exist, it will be created based on the Example File `etc/looptab` in this Repository.

# Configuration File
The File `/etc/looptab` is used to define the List of Devices to be setup.

```
# Configured Loop Devices
# The Separator between each Column (ID, Crypt Device / "Source", Loop Device Alias) **MUST** be a TAB (\t)
# ID    Source                                 			Symlink
0	/dev/mapper/ata-CT1000MX500SSD1_2XXXEXXXXXXX_crypt	/dev/loop/ata-CT1000MX500SSD1_2XXXEXXXXXXX_loop
1	/dev/mapper/ata-CT1000MX500SSD1_2XXXEXXXXXXX_crypt	/dev/loop/ata-CT1000MX500SSD1_2XXXEXXXXXXX_loop
...	...							...
```

You must do this for ALL Device that you want to be set up during Boot.

# Converting Devices
## Introduction
In order to switch from LUKS Device (`/dev/mapper/XXXX`) to Loop Device (`/dev/loop/XXXX`) as VDEV (Disk) member of a ZFS Pool, the following Commands can be used on ZFS 2.2+ in order to replace the Disks **WITHOUT**:
- Requiring a LiveUSB (`zpool export rpool; zpool import rpool -d /dev/loop/XXXX -d /dev/loop/YYYY`)
- Requiring a Resilver (`zpool offline XXXX; zpool detach XXXX; zpool attach rpool /dev/YYYY /dev/loop/XXXX`) - you [cannot replace a Disk with itself](https://github.com/openzfs/zfs/issues/2076)

## Get the Current Pool Information
In order to get the `vdev` Names to be Converted/Replaced/Migrated to Loop Devices, one can see the List of VDEVS in the `status` Output of `zpool`:
```
zpool status -v
```

Or alternatively by running:
```
zpool get path rpool all-vdevs
```

Make sure that ALL Devices you want to be set up during Boot are configured in the `/etc/looptab` File, then Issue:
```
/usr/sbin/looptab
```

In order to have an easy Copy-Paste Text, list all these newly created Devices:
```
ls -l /dev/loop/*
```

## Change Path of Disks/Devices/VDEVs
Set New Path for the First Disk:
```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2301E6992CB7_loop rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```

Set New Path for the Second Disk:
```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2302E69AD9D0_loop rpool ata-CT1000MX500SSD1_2302E69AD9D0_crypt
```

## (Optional) Run Scrub after changing Paths
(Optional) Run a Scrub after Changing Path(s):
```
zpool scrub rpool
```

Monitor Scrub Status:
```
watch 'zpool status -v'
```

## Change ZFS Boot/Import Options
Set Options in `/etc/default/zfs`:
```
# Setting ZPOOL_CACHE to an empty string ('') AND setting ZPOOL_IMPORT_OPTS to
# "-c /etc/zfs/zpool.cache" will _enforce_ the use of a cache file.
# This is needed in some cases (extreme amounts of VDEVs, multipath etc).
# Generally, the use of a cache file is usually not recommended on Linux
# because it sometimes is more trouble than it's worth (laptops with external
# devices or when/if device nodes changes names).
ZPOOL_IMPORT_OPTS="-c /etc/zfs/zpool.cache"
ZPOOL_CACHE=""
```

Make sure that all other `ZPOOL_IMPORT_OPTS` and `ZPOOL_CACHE` Lines are Commented !!!


## (Re)generate Pool Cachefile

### From the System itself (Live System)
From the System itself, (re)generate `/etc/zfs/zpool.cache`:
```
zpool set cachefile=/etc/zfs/zpool.cache rpool
```

Regenerate initramfs:
```
update-initramfs -v -k all -u
```

### From LiveCD/LiveUSB (Chroot)
From within the **Chroot**, (re)generate `/etc/zfs/zpool.cache`:
```
zpool set cachefile=/etc/zfs/zpool.cache rpool
```

Regenerate initramfs:
```
update-initramfs -v -k all -u
```



## Complementary Information


## References
Documentation References:
- `man vdevprops`: The following native properties can be used to change the behavior of a vdev. 
                   `path`        The path to the device for this vdev
- `man zpool-get`: `zpool get all rpool all-vdevs`
- `man zpool-set`: `zpool set property=value rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt`


For Instance:
```
zpool get all rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```

Get the Current Path:
```
zpool get path rpool ata-CT1000MX500SSD1_2301E6992CB7_crypt
```


# Replace Drives and Fix Path (Second Attempt - Device Paths were changed back to devid since the Loop Device couldn't be found)

```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2301E6992CB7_loop rpool dm-uuid-CRYPT-LUKS2-b5ed1ef4aecb4404b68229f2a8a253c3-ata-CT1000MX500SSD1_2301E6992CB7_crypt
```

```
zpool set path=/dev/loop/ata-CT1000MX500SSD1_2302E69AD9D0_loop rpool dm-uuid-CRYPT-LUKS2-471885256c014364874b5ddc0ee2dca3-ata-CT1000MX500SSD1_2302E69AD9D0_crypt
```

Regenerate Cachefile
```
zpool set cachefile=/etc/zfs/zpool.cache rpool
```

Regenerate initramfs:
```
update-initramfs -v -k all -u
```
