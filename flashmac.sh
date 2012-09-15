#!/bin/sh

# flash the unit with the right mac configured
#
# note! usb partition matters - in nand custom file!!
# purpose is to avoid making errors while flashing many units!

if [ ! -d installer ]; then cd sheevaplug-installer-v1.0; fi
if [ -z "$1" ]
then
	echo Missing mac!
	exit 1
fi
if [ "$2"  != "-force" ]
    then
    if [ "`cat uboot/uboot-env/uboot-nand-custom.txt | grep ethaddr | cut -d ' ' -f 2`" == "$1" ]
    then
        echo "You already flashed this mac!"
        exit 2
    fi
fi
sed -i "s/ethaddr .*/ethaddr $1/" uboot/uboot-env/uboot-nand-custom.txt
cat uboot/uboot-env/uboot-nand-custom.txt | grep ethaddr
php runme.php nand
echo "JTAG flash complete, now eyeball the serial interface"
sleep 1
screen /dev/ttyUSB0 115200
