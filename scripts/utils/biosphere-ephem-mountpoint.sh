#!/bin/bash

ifb_ephem_mountpoint="/ifb/data/local"
ephem_vdisk="vdb"

# Check if ephemeral disk is already mounted, and where
ephem_mountpoint=`df | grep $ephem_vdisk |awk '{print $6}'`
[ -z $ephem_mountpoint ]
exit

# Change ephemeral disk mountpoint
umount $ephem_mountpoint
mkdir -p ${ifb_ephem_mountpoint}
mount /dev/${ephem_vdisk} $ephem_mountpoint
