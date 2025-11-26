#!/bin/sh
VERSION_CODENAME=$(  lsb_release -cs )
SRC_MIRROR="http://de.deb.devuan.org/merged/"
mydir="jail-devuan-${VERSION_CODENAME}-rootfs"
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
/bin/bash ${DEBOOTSTRAP_CMD} --include=openssh-server,locales,rsync,sharutils,psmisc,patch,less,apt,init-system-helpers,iproute2,isc-dhcp-client,openssl,ca-certificates --components main,contrib --arch=amd64 --no-check-gpg ${VERSION_CODENAME} ${rootfs_dir} ${SRC_MIRROR}
ret=$?
set +o xtrace
if [ ${ret} -ne 0 ]; then
	echo "debootstrap failed"
	exit ${ret}
fi

printf "APT::Cache-Start 251658240;" > ${rootfs_dir}/etc/apt/apt.conf.d/00freebsd

cat > ${rootfs_dir}/etc/apt/sources.list <<EOF
deb http://de.deb.devuan.org/merged ${VERSION_CODENAME} main non-free-firmware
deb-src http://de.deb.devuan.org/merged ${VERSION_CODENAME} main non-free-firmware

deb http://de.deb.devuan.org/merged ${VERSION_CODENAME}-security main non-free-firmware
deb-src http://de.deb.devuan.org/merged ${VERSION_CODENAME}-security main non-free-firmware

# ${VERSION_CODENAME}-updates, to get updates before a point release is made;
# see https://www.debian.org/doc/manuals/debian-reference/ch02.en.html#_updates_and_backports
deb http://de.deb.devuan.org/merged ${VERSION_CODENAME}-updates main non-free-firmware
deb-src http://de.deb.devuan.org/merged ${VERSION_CODENAME}-updates main non-free-firmware

EOF

# template for CBSD preparebase (replace %%VERSION_CODENAME/SRC_MIRROR%%)
cat > ${rootfs_dir}/etc/apt/sources.list-tpl <<EOF
deb %%SRC_MIRROR%%/merged ${VERSION_CODENAME} main non-free-firmware
deb-src %%SRC_MIRROR%%/merged ${VERSION_CODENAME} main non-free-firmware

deb %%SRC_MIRROR%%/merged ${VERSION_CODENAME}-security main non-free-firmware
deb-src %%SRC_MIRROR%%/merged ${VERSION_CODENAME}-security main non-free-firmware

# ${VERSION_CODENAME}-updates, to get updates before a point release is made;
# see https://www.debian.org/doc/manuals/debian-reference/ch02.en.html#_updates_and_backports
deb %%SRC_MIRROR%%/merged ${VERSION_CODENAME}-updates main non-free-firmware
deb-src %%SRC_MIRROR%%/merged ${VERSION_CODENAME}-updates main non-free-firmware

EOF

if [ ! -f ${rootfs_dir}/bin/bash ]; then
	echo "No such distribution (bash not found) in ${rootfs_dir}"
	exit 1
fi

truncate -s0 ${rootfs_dir}/etc/resolv.conf

if [ -r /proc/cpuinfo ]; then
	_hwnum=$( grep -c ^processor /proc/cpuinfo )
fi

cat > ${rootfs_dir}/etc/rc <<EOF
#!/bin/sh
/usr/bin/find /etc/rc3.d -type l -name S\* | while read _f; do
	\${_f} start
done
EOF

# disable ssh
for i in rc0.d rc1.d rc2.d rc3.d rc4.d rc5.d rc6.d rcS.d; do
	find ${rootfs_dir}/etc/${i} -type l -name S*ssh -delete
done

cat > ${rootfs_dir}/etc/motd <<EOF

  This environment uses SysVinit as a service initialization system.
  Please use appropriate utilities to manage services, e.g.:

  Enable service:
    update-rc.d ssh defaults

  Disable service:
    update-rc.d -f ssh remove

  List of services:
    service --status-all


EOF

cat >> ${rootfs_dir}/root/.bashrc <<EOF
[ -r /etc/motd ] && cat /etc/motd
EOF

[ -z "${_hwnum}" ] && _hwnum="4"
set -o xtrace
cd ${rootfs_dir}
env XZ_OPT="--threads=${_hwnum} --best" tar -cJf ${my_parent_dir}/${mydir}.txz . --numeric-owner
ret=$?
set +o xtrace
exit ${ret}
