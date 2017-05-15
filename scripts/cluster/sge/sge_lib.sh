#!/bin/bash
if [ -d "/opt/sge/default/common/" ]; then
	. /opt/sge/default/common/settings.sh
	LD_LIBRARY_PATH=/opt/rh/python27/root/usr/lib64::/ifb/lib::$SGE_ROOT/lib/`$SGE_ROOT/util/arch`
	export DRMAA_LIBRARY_PATH=$SGE_ROOT/lib/lx-amd64/libdrmaa.so.1.0
fi