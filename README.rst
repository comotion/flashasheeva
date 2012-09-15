flashasheeva
============

flash your bits to one or many sheeva plugs


Flashing the SheevaPlug for use with Bifrost
Prerequisites

* a Sheeva unit
* A 32-bit x86 computer
* the SheevaPlug Installer http://www.plugcomputer.org/405/us/plug-basic/tools/sheevaplug-installer-v1.0.tar.gz
* a JTAG connector (or USB for older units)
* a USB thumb drive with about 100MB free space.

If you don't have a 32-bit computer you will need a 32-bit chroot with libftdi installed, this because the openocd program is only built for 32-bit computers.
  
Just flashing
=============

Get the sheeva flasher.

If all you want is to flash a pre-built image, everything you need is in that directory.

Your USB thumb must contain: 

* uImage
* initrd
* modules.tar.gz
* ubuntu-sheevaplug.sh
* rootfs.tar.gz 

from sheevaplug-installer-v1.0/installer/initrd

Got all that? Connect to the sheeva plug by USB and then flash with

::

  ./flashmac F0:AD:4E:00:XX:XX

Where F0:AD:4E:00:XX:XX should be replaced with the actual MAC printed on the label found on the underside of the device.

This will unbrick, upgrade Das U-Boot and flash the kernel, initrd, modules and rootfs contained on the USB stick onto the device itself. If you're doing it multiple times, add a -force parameter to the end of that command.


The mods
========

at present this flashes a slightly modified ubuntu image for use with the Bifrost print system,
however this is the fastest and leanest image for the Sheeva that I could find at this moment.

/bifrost_bootstrap is put into the rootfs.tar.gz file in the installer, and 
/bifrost_bootstrap/firstboot.sh is run through /etc/rc.local on first boot after
a successful flash.

prepare_image.sh <-- run 1st. downloads dependencies and prepares the above
  root image. This script is standalone and can be executed from /tmp to get a temporary flashy root.

flashmac.sh <-- flash the device through JTAG. Also works fonders for unbricking.

  Insert into the Sheeva your USB drive preloaded with uImage, initrd, modules.tar.gz and rootfs.tar.gz as well as the ubuntu-sheevaplug.sh script (generated through prepare_image). The USB drive should have one FAT partition, the boot loader is quite picky with the type of drive.


NB NB NB! Once the device is flashed, if your console becomes corrupted, it means you have a newer revision of the CPU that is incompatible with the current kernel. NewIT have a patched kernel for this problem at:

http://www.newit.co.uk/files-sheevaplug/installer/installer-A1/


After flashing, the device will run through a self-update process that lasts about 5 minutes, after which it will reboot on its own.

NOTE THAT Once the self-update is complete, you will want to log into the device via JTAG serial console (root/nosoup4u) and update /root/.ssh/authorized_keys to contain your own SSH key. Or you could read the script and flash your authorized_keys file right on there.

Once you have done the above steps, you can check the proper operation of the device by running check_flash.sh. It will even verify proper bifrost operation if you connect a card reader.

For flashing many times it helps to comment out the following line in sheevaplug-installer:

::

    exec("modprobe ftdi_sio vendor=0x9e88 product=0x9e8f", $out, $rc);

change that to

::

    #exec("modprobe ftdi_sio vendor=0x9e88 product=0x9e8f", $out, $rc);


Building the root image
=======================

You will also need udhcpc, dropbear and other DEB packages for mipsel.

