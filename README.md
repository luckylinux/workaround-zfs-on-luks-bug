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

# Automatic Conversion
An Automatic Conversion Script has been written for Convenience.

**Keep in Mind that this is based on my Setup and Naming Convention / Scheme so it will not / may not work for you.**
```
./auto_convert.sh
```

This takes care of Everything **except running the Setup Script**, namely:
- Generate Configuration File `/etc/looptab`
- Convert Devices using `zpool set path=xxxx rpool yyyy`
- Set Options in `/etc/default/zfs` to enforce the use of Cachefile
- (Re)generate Pool Cachefile in `/etc/zfs/zpool.cache`
- Regenerate Initramfs

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

This yields:
```
  pool: rpool
 state: ONLINE
status: One or more features are enabled on the pool despite not being
	requested by the 'compatibility' property.
action: Consider setting 'compatibility' to an appropriate value, or
	adding needed features to the relevant file in
	/etc/zfs/compatibility.d or /usr/share/zfs/compatibility.d.
  scan: scrub repaired 0B in 01:07:23 with 0 errors on Mon Aug 19 21:27:33 2024
config:

	NAME                                            STATE     READ WRITE CKSUM
	rpool                                           ONLINE       0     0     0
	  mirror-0                                      ONLINE       0     0     0
	    ata-CT1000MX500SSD1_2301E6992CB7_crypt      ONLINE       0     0     0
	    ata-CT1000MX500SSD1_2302E69AD9D0_crypt      ONLINE       0     0     0

errors: No known data errors

```


Or alternatively by running:
```
zpool get path rpool all-vdevs
```

This yields:
```
NAME    PROPERTY  VALUE  SOURCE
root-0  path      -      default
mirror-0  path      -      default
ata-CT1000MX500SSD1_2301E6992CB7_crypt  path      /dev/mapper/ata-CT1000MX500SSD1_2301E6992CB7_crypt  -
ata-CT1000MX500SSD1_2302E69AD9D0_crypt  path      /dev/mapper/ata-CT1000MX500SSD1_2302E69AD9D0_crypt  -
```

Make sure that ALL Devices you want to be set up during Boot are configured in the `/etc/looptab` File, then Issue:
```
/usr/sbin/looptab
```

In order to have an easy Copy-Paste Text, list all these newly created Devices:
```
ls -l /dev/loop/*
```

```
lrwxrwxrwx 1 root root 10 Aug 20 14:50 /dev/loop/ata-CT1000MX500SSD1_2301E6992CB7_loop -> /dev/loop1
lrwxrwxrwx 1 root root 10 Aug 20 14:50 /dev/loop/ata-CT1000MX500SSD1_2302E69AD9D0_loop -> /dev/loop0
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

## Force ZFS to start using the new Devices
This is probably a BUG. See [BUG Report](https://github.com/openzfs/zfs/issues/16465).

In order for ZFS to **ACTUALLY** start using the newly introduced loop Devices, it is/might be (in all/some Circumstances) required to issue:
```
zpool reopen
```

and/or:

```
zpool reopen rpool
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

## (Probably not needed anymore) Need to modify ZFS/OpenZFS initramfs Script
~~
This is required because, even if `PREREQ` is used correctly, for some Reason (to be investigated) the `looptab` Script (this Project) is executed BEFORE `clevis` even unlocks the Disks, so ZFS will either fall back to the `devid` or, in case the Cachefile is enfored, most likely just panic.
~~

This should **in principle** no longer be needed, since the Script is Stored in the `local-premount` Subfolder and NOT in the `local-top` Subfolder anymore !

Manually Open `/usr/share/initramfs-tools/scripts/zfs` and Change according to the Provided Diff File:
```diff
--- /usr/share/initramfs-tools/scripts/zfs.orig	2024-08-20 15:14:18.170417535 +0200
+++ /usr/share/initramfs-tools/scripts/zfs	2024-08-20 15:17:11.195822061 +0200
@@ -228,6 +228,12 @@
 	[ "$quiet" != "y" ] && zfs_log_begin_msg \
 		"Importing pool '${pool}' using defaults"
 
+        # Setup Loopback Devices first
+        if [ -x "/usr/sbin/looptab" ]
+        then
+            echo "!!!! START /usr/sbin/looptab USING FALLBACK METHOD FROM ZFS INITRAMFS SCRIPT !!!!"
+            /usr/sbin/looptab
+            echo "!!!! END /usr/sbin/looptab USING FALLBACK METHOD FROM ZFS INITRAMFS SCRIPT !!!!"
+        fi
+
 	ZFS_CMD="${ZPOOL} import -N ${ZPOOL_FORCE} ${ZPOOL_IMPORT_OPTS}"
 	ZFS_STDERR="$($ZFS_CMD "$pool" 2>&1)"
 	ZFS_ERROR="$?"

```


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
