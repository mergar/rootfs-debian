#!/bin/sh
VERSION_CODENAME=$(  lsb_release -cs )
SRC_MIRROR="http://ftp.de.debian.org/debian/"
mydir="jail-debian-${VERSION_CODENAME}-rootfs"
my_parent_dir="/root"
rootfs_dir="${my_parent_dir}/${mydir}"
[ -d ${rootfs_dir} ] && rm -rf ${rootfs_dir}
[ ! -d ${rootfs_dir} ] && mkdir -p ${rootfs_dir}

DEBOOTSTRAP_CMD=$( which debootstrap )

if [ -z "${DEBOOTSTRAP_CMD}" -o ! -x "${DEBOOTSTRAP_CMD}" ]; then
	echo "No such debootstrap"
	exit 1
fi

set -o xtrace
/bin/bash ${DEBOOTSTRAP_CMD} --include=openssh-server,locales,rsync,sharutils,psmisc,patch,less,apt,init-system-helpers,iproute2,isc-dhcp-client --components main,contrib --arch=amd64 --no-check-gpg ${VERSION_CODENAME} ${rootfs_dir} ${SRC_MIRROR}
ret=$?
set +o xtrace
if [ ${ret} -ne 0 ]; then
	echo "debootstrap failed"
	exit ${ret}
fi

printf "APT::Cache-Start 251658240;" > ${rootfs_dir}/etc/apt/apt.conf.d/00freebsd

cat > ${rootfs_dir}/etc/apt/sources.list <<EOF
deb http://ftp.de.debian.org/debian/ ${VERSION_CODENAME} main
deb-src http://ftp.de.debian.org/debian/ ${VERSION_CODENAME} main

deb http://ftp.de.debian.org/debian/ ${VERSION_CODENAME}-updates main contrib
deb-src http://ftp.de.debian.org/debian/ ${VERSION_CODENAME}-updates main contrib

deb http://security.debian.org/debian-security ${VERSION_CODENAME}-security main contrib
deb-src http://security.debian.org/debian-security ${VERSION_CODENAME}-security main contrib
EOF

# template for CBSD preparebase (replace %%VERSION_CODENAME/SRC_MIRROR%%)
cat > ${rootfs_dir}/etc/apt/sources.list-tpl <<EOF
deb %%SRC_MIRROR%%/debian/ %%VERSION_CODENAME%% main
deb-src %%SRC_MIRROR%%/debian/ %%VERSION_CODENAME%% main

deb %%SRC_MIRROR%%/debian/ %%VERSION_CODENAME%%-updates main contrib
deb-src %%SRC_MIRROR%%/debian/ %%VERSION_CODENAME%%-updates main contrib

deb http://security.debian.org/debian-security %%VERSION_CODENAME%%-security main contrib
deb-src http://security.debian.org/debian-security %%VERSION_CODENAME%%-security main contrib
EOF

if [ ! -f ${rootfs_dir}/bin/bash ]; then
	echo "No such distribution (bash not found) in ${rootfs_dir}"
	exit 1
fi

truncate -s0 ${rootfs_dir}/etc/resolv.conf

if [ -r /proc/cpuinfo ]; then
	_hwnum=$( grep -c ^processor /proc/cpuinfo )
fi

[ -z "${_hwnum}" ] && _hwnum="4"
set -o xtrace
cd ${rootfs_dir}
env XZ_OPT="--threads=${_hwnum} --best" tar -cJf ${my_parent_dir}/${mydir}.txz . --numeric-owner
ret=$?
set +o xtrace
exit ${ret}
