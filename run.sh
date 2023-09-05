#!/bin/sh
CODE_NAME=$(  lsb_release -cs )
SRC_MIRROR="http://ftp.de.debian.org/debian/"
mydir="jail-debian-${CODE_NAME}-rootfs"
my_parent_dir="/root"
rootfs_dir="${my_parent_dir}/${mydir}"
[ -d ${rootfs_dir} ] && rm -rf ${rootfs_dir}
[ ! -d ${rootfs_dir} ] && mkdir -p ${rootfs_dir}

DEBOOTSTRAP_CMD=$( which debootstrap )

if [ -z "${DEBOOTSTRAP_CMD}" -o ! -x "${DEBOOTSTRAP_CMD}" ]; then
	echo "No such debootstrap"
	exit 1
fi

echo "/bin/bash ${DEBOOTSTRAP_CMD} --include=openssh-server,locales,rsync,sharutils,psmisc,patch,less,apt,init-system-helpers,iproute2,isc-dhcp-client --components main,contrib --arch=amd64 --no-check-gpg ${CODE_NAME} ${rootfs_dir} ${SRC_MIRROR}"
/bin/bash ${DEBOOTSTRAP_CMD} --include=openssh-server,locales,rsync,sharutils,psmisc,patch,less,apt,init-system-helpers,iproute2,isc-dhcp-client --components main,contrib --arch=amd64 --no-check-gpg ${CODE_NAME} ${rootfs_dir} ${SRC_MIRROR}
ret=$?
if [ ${ret} -ne 0 ]; then
	echo "debootstrap failed"
	exit ${ret}
fi

printf "APT::Cache-Start 251658240;" > ${rootfs_dir}/etc/apt/apt.conf.d/00freebsd
cat > ${rootfs_dir}/etc/apt/sources.list <<EOF
deb http://%%SRC_MIRROR%%/debian/ ${CODE_NAME} main
deb-src http://%%SRC_MIRROR%%/debian/ ${CODE_NAME} main

deb http://security.debian.org/debian-security ${CODE_NAME}-security main contrib
deb-src http://security.debian.org/debian-security ${CODE_NAME}-security main contrib

deb http://%%SRC_MIRROR%%/debian/ ${CODE_NAME}-updates main contrib
deb-src http://%%SRC_MIRROR%%/debian/ ${CODE_NAME}-updates main contrib

#deb http://%%SRC_MIRROR%%/debian/ ${CODE_NAME}-backports main
#deb-src http://%%SRC_MIRROR%%/debian/ ${CODE_NAME}-backports main
EOF

if [ ! -f ${rootfs_dir}/bin/bash ]; then
	echo "No such distribution (bash not found) in ${rootfs_dir}"
	exit 1
fi

truncate -s0 ${rootfs_dir}/etc/resolv.conf

cd ${my_parent_dir}
tar cfz ${mydir}.tgz ${mydir}
