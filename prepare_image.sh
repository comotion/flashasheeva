#!/bin/sh
set -e #-x
#

# create SheevaPlug firmware for bifrost usage
#
# this script will prepare a sheevaplug filesystem image for flashing
# despite the requirements, this script itself does *not* need to be run on 32bits
# .. the flashing process needs 32 bits however.

# requirements: 
# - a SheevaPlug connected through the USB-to-serial JTAG interface
# - updated debian packages in DEB_PATH
# - a connection to the internet
# - the libftdi library on a *32*bit system
#
# checklist:
# * point bifrost_bootstrap/bifrost/read_card.pl at right ip address
# * put right key in authorized_keys
# * check if your debs are correct and all

workdir=/tmp/sheeva
repo=http://bifrost.projects.linpro.no/svn/trunk/src/Sheeva/
# annoying url
sheeva_url="http://plugcomputer.org/index.php/us/resources/downloads?func=showdown&id=53"
# sheevaplug-installer
TARBALL=sheevaplug-installer-v1.0.tar.gz
# a 100MB USB stick
MEDIA=/mnt/one
# place necessary debs in bootstrap/debs
# do not proceed until you have at least udhcp, dropbear, monit and snmp debs in DEB_PATH
DEB_PATH=bootstrap/debs
# where the bifrost server is (for bifrost images)
PRINT_SERVER=print.me.not


# what keys to include in the image
AUTH_KEYS=bifrost_bootstrap/authorized_keys

# grab the required files
sheeva_bifrost_get () {
    svn co $repo $1
}

get_file () {
    wget $1
}

# unpack the installer
xtract_installer () {
    echo "@@@@ unpacking installer @@@@"
    tar xf $1
    echo "@@@@ done unpacking installer @@@@"
}

rootfs_xtract () {
    # unpack the UBIFS rootfs
    echo "@@@@ unpacking rootfs @@@@"
    rm -rf roots; mkdir -p rootfs
    (cd rootfs && fakeroot tar xf ../rootfs.tar.gz)
    echo "@@@@ done unpacking rootfs @@@@"
}

rootfs_prepare_files () {
    echo "@@@@ prepare rootfs for bifrost (set up bootstrap procedure which does the rest) @@@@"
    cp -a ../../bifrost_bootstrap rootfs/
    find rootfs/bifrost_bootstrap -name '.svn' | xargs rm -r
    mv rootfs/bifrost_bootstrap/rc.local rootfs/etc/
    # to be safe, make them exec
    chmod +x rootfs/etc/rc.local
    chmod +x rootfs/bifrost_bootstrap/firstboot.sh
    chmod +x rootfs/bifrost_bootstrap/bifrost/*.sh
    chmod +x rootfs/bifrost_bootstrap/bifrost/read_card.pl
    sed -i "s/BIFROST_SERVER = .*$/BIFROST_SERVER = '$PRINT_SERVER';/" \
        rootfs/bifrost_bootstrap/bifrost/read_card.pl

    # save some space on the SheevaPlug
    rm -r rootfs/usr/share/locale/*
    rm -r rootfs/usr/share/locale-langpack/*
    rm rootfs/var/cache/apt/archives/*.deb
    rm -fr rootfs/var/lib/apt/lists/*
    mkdir -p rootfs/var/lib/apt/lists/partial
    if [ -n "$AUTH_KEYS" -a -f "$AUTH_KEYS" ]
        then
        echo "overwriting authorized keys with $AUTH_KEYS"
        cp $AUTH_KEYS rootfs/bifrost_bootstrap/authorized_keys
    else
        echo "using authorized keys from repo..."
    fi

    # there is more to save if you forgo perl unicode support 
    # /usr/lib/python2.6 19MB 
    # /usr/lib/gconv     7MB
    # /usr/share/perl/5.10/unicore 16MB or if you forgo documentation
    # /usr/share/doc 12MB
    # /usr/share/i18n 8MB
    # /usr/share/man  6 MB
    # /usr/share/X11 ???
    # du -sx * | sort -n # is your friend
    echo "@@@@ rootfs prepared for bifrost server $PRINT_SERVER @@@@"
}

rootfs_put_debs () {
    # place necessary debs in bifrost_bootstrap/debs
    packages="`find $DEB_PATH -type f -name '*.deb'`"
    if [ -z "$packages" ]
    then
        echo "@@@@ do not proceed until you have at least udhcp, dropbear, monit and snmp debs in DEB_PATH (currently $DEB_PATH) @@@@"
        echo "hint: get these from ports.ubuntu.com jaunty armel or copy them from UBIFS."
        exit 1
    fi
    mkdir -p rootfs/bifrost_bootstrap/debs
    cp $DEB_PATH/*.deb rootfs/bifrost_bootstrap/debs/
    echo "@@@@ The following packages will be installed on your plug:" 
    find rootfs/bifrost_bootstrap/debs -type f
}

rootfs_pack () {
    # repack the rootfs
    echo "@@@@ repacking the rootfs @@@@"
    [ ! -f rootfs-original.tar.gz ] && mv rootfs.tar.gz rootfs-original.tar.gz
    rm -f rootfs/var/run/crond.reboot
    (cd rootfs && fakeroot tar czf ../rootfs.tar.gz .)
    echo "@@@@ done repacking rootfs @@@@"
}

rootfs_prepare () {
    echo "@@@@ preparing rootfs @@@@"
    rootfs_xtract
    rootfs_prepare_files
    rootfs_put_debs
    rootfs_pack
    echo "@@@@ rootfs prepared @@@@"
}


if [ ! -d $workdir ]
    then
    cd `dirname $workdir`
    sheeva_bifrost_get $workdir
fi
cd $workdir
if [ ! -f $TARBALL ]
    then
    echo $sheeva_url
    get_file $sheeva_url
fi

xtract_installer $TARBALL
cp flashmac.sh sheevaplug-installer-v1.0
cp runme.php sheevaplug-installer-v1.0
cd sheevaplug-installer-v1.0/installer

rootfs_prepare

# fix kernel problem with newer CPUs rev A1
if [ ! -f uImage.A0 ]
    then
    mv uImage uImage.A0
    get_file http://www.newit.co.uk/files-sheevaplug/installer/installer-A1/uImage
fi

# place the kernel, modules and rootfs on your USB media
if [ ! -d $MEDIA ]
    then
    echo @@@@ need removable media for UBIFS files
    echo 'cp rootfs.tar.gz uImage modules.tar.gz ubuntu-sheevaplug.sh PATH/TO/MEDIA'
    exit 2
fi
pwd
cp initrd rootfs.tar.gz uImage modules.tar.gz ubuntu-sheevaplug.sh $MEDIA
sync

cd $workdir

echo "@@@@ Rootfs ready and waiting in $MEDIA. @@@@"
echo "Now proceed:"
echo "0. eject $MEDIA"
echo "1. insert the USB stick into the SheevaPlug"
echo "2. connect your computer to the SheevaPlug with the USB cable."
echo "3. run the flashmac script with the desired MAC address"
echo
echo "The mac address is printed on the bottom of the unit"
echo "EXAMPLE:  ./flashmac 00:50:43:de:ad:ed"
if [ "`uname -m`" != "i686" ]
    then
    echo "@@@@ You *WILL* need a 32-bit intel OS to flash from. Try a chroot?"
    exit 3
fi
