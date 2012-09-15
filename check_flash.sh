#!/bin/sh
# check the cardreader for all crits
# -kwy@linpro.no 2009-10-13
# -kwy@linpro.no 2009-12-16 for SheevaPlug
set -e
IP=${1:-192.168.1.1}

MYIP=${2:-192.168.1.2}
#ID=bifrost_rsa
#ID=stavanger_dsa
#ID=bifrost@hio_rsa
#ID=bifrost@mf_rsa
ID=~/.ssh/keys/bifrost_rsa

exithook() {
   E=$?
   [ "$E" -ne "0" ] && echo "Failed with code $?"
}

trap exithook SIGTERM SIGINT EXIT

SSH="ssh -i $ID -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/k_h $IP -l root"
card_file=/usr/local/bifrost/read_card.pl
PROCESSES='udhcpc snmpd monit read_card.pl logger watchdog dropbear'
echo
echo "[!!!!] Checking router $IP : NOT PASSED unless I SAY SO"
echo
#if [ -n "$MYIP" ]
#then
#   echo "[*] setting eth0 to $MYIP"
#   sudo ifconfig eth0 $MYIP
#fi
echo "[*] checking SSH to $IP"
$SSH cat /etc/banner

echo "[*] checking $card_file"
SERVER_TYPE=`$SSH cat $card_file | grep -v '\s*#' | 
awk '
/BIFROST_SERVER = .*;/ { server = $4 }
/INPUT_TYPE = .*/ { type = $4 $5 }
END {
   if(server){
      print server;
   } else {
      print "[!?!] no BIFROST_SERVER!\n";
      exit 1
   }
   if(type) {
      print type;
   } else {
      print " [!?!] NO INPUT_TYPE\n";
      exit  2;
   }
}
'`
echo "$SERVER_TYPE"
SERVER=`echo "$SERVER_TYPE" | head -n 1`

ADDR="192.168.1.1"
DHCP=''
while [ -z "$DHCP" ]
do
   echo "[*] Checking DHCP:"
   DHCP=`$SSH /sbin/ifconfig | grep 'inet addr:' | egrep -v ':192\.168\.1\.1|:127\.0\.'`
   if [ -n "$DHCP" ]
      then
      echo "[+] Got address: "
      echo "$DHCP"
      ADDR=`echo $DHCP | cut -f 2 -d ':' | cut -f 1 -d ' '`
      $SSH ping -c 1 $ADDR
   else
      echo "[!] NO DHCP ADDRESS"
      echo " - plug it in please! or go debug. Hit ENTER to TRY AGAIN, 's' ENTER to skip this check."
      read SKIP
      if [ "$SKIP" = "s" ]
         then
         echo "[^_^] SKIPPED"
         break
      fi
   fi
done

echo "[!!] NTPDATE"
$SSH /usr/sbin/ntpdate pool.ntp.org
echo "[*] Mac address"
$SSH /sbin/ifconfig eth0 | grep HW 

echo "[*] Checking processes: $PROCESSES"
procs=`$SSH ps aux`
for proc in $PROCESSES
do
   if echo $procs | grep -q $proc
      then
      echo "[+] OK $proc"
   else
      echo "[!] FAIL $proc"
      exit 1
   fi
done

$SSH 'cat > /usr/local/bifrost/cat_card.pl' << EOF
#!/usr/bin/perl
use CardReader;

my \$server = $SERVER
&CardReader::init( device => "/dev/input/event0", debug => 0 );
while(1) {
   print "waiting for input\n";
   my \$t1,\$t2,\$t3;
   my \$rc = &CardReader::read_card(\\\$t1,\\\$t2,\\\$t3);
   print "Return code: \$rc\n";
   if(not \$t1 and not \$t2 and not \$t3){
      print "Failed to read card!\n";
      exit(1);
   }
   print "\$t1\n\$t2\n\$t3\n";
   exit(0);
}

EOF

echo "[*] Final step: checking card reader. Please swipe something."
$SSH 'cd /usr/local/bifrost && perl cat_card.pl'
rm /tmp/k_h
echo
echo "[**] PASSED! Router is bifrost ready towards server $SERVER"
