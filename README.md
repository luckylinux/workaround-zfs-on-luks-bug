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

