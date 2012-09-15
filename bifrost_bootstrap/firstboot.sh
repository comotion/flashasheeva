#!/bin/sh
#
# Setup the sheevaplug for bifrost.
# 
# $Id$
#
# Author: kwy@redpill-linpro.com
#
# revisions:
# v1  2009-12-16 Initial
# v2  2010-05-25 udhcpc fixes
set -x

cd /bifrost_bootstrap
dpkg -P ubuntu-minimal dhcp3-client dhcp3-common openssh-server openssh-client
rm -rf /etc/ssh


# dropbear monit snmpd ntpdate
yes | dpkg -i debs/*.deb

# setup defaults
cp default/* /etc/default/
mkdir -p /usr/local
cp -a bifrost /usr/local

ln -s /usr/bin/dbclient /usr/local/bin/ssh

cp fstab /etc/

# bifrost stuff
cp banner /etc/
cp banner /etc/motd
cp monitrc /etc/monit/
cp snmpd.conf /etc/snmp/
cp ntpserver /etc/
mkdir -p /root/.ssh
cp authorized_keys /root/.ssh
cp 88-magtek.rules /etc/udev/rules.d/

# hostname set by DHCP
cp udhcpc.default.bound /etc/udhcpc/default.bound
cp udhcpc.default.renew /etc/udhcpc/default.renew
cp udhcpc.default.leasefail /etc/udhcpc/default.leasefail

cp interfaces /etc/network/interfaces

# # this is a hack around broken ifupdown
# mv /sbin/udhcpc /sbin/udhcpc.real
# cat > /sbin/udhcpc << EOF
# #!/bin/sh
# if [ "$1" = "-n" ]; then shift; fi
# exec udhcpc.real $@
#
# EOF
# chmod +x /sbin/udhcpc


cat cron >> /etc/crontab

apt-get --yes autoremove
apt-get --yes clean

# delete self
rm -r /bifrost_bootstrap
rm -rfv /tmp/*
#rm -fv /var/log/*
#rm -fv /var/log/*/*
mkdir -p /var/log/apt
mkdir -p /var/log/fsck
mkdir -p /var/log/news
reboot
