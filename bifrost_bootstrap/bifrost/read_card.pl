#!/usr/bin/perl -w
#
# Cato Feness, <ccf@linpro.no>, 2008-01-04
#
use CardReader;
use HttpRequest;

#
# CONFIGURATION
#
my $BIFROST_SERVER = 'print.linpro.no';
my $WAN_INTERFACE = 'eth0';
my $PID_FILE = '/tmp/read_card.pid';

# The INPUT_TYPE determins what mode to operate in and what
# input to expect. The values are
# - 'card reader': a USB card swiper
# - 'keypad': a USB keypad epecting a $KEYPAD_PIN_CODE_LENGTH long ping code
#             before sending it. If no input has been received withing
#             $KEYPAD_RESET_TIMEOUT seconds, the pin code is reset, i.e.
#             set to blank, and it waits for new input
my $INPUT_TYPE = 'card reader';

#my $INPUT_TYPE = 'keypad';
my $KEYPAD_PIN_CODE_LENGTH = 6;
my $KEYPAD_RESET_TIMEOUT = 3;

#
# MAIN
#
{
   open(FH, "> $PID_FILE") || die "Unable to open PID file $PID_FILE\n";
   print FH $$;
   close(FH);

   my $mac_address = get_mac_address($WAN_INTERFACE) || die "Unable to get mac address\n";
   print "MAC address: $mac_address\n";

   &CardReader::init(
                     device => "/dev/input/event0",
                     debug => 0,
                    );

   while (1) {
      print "\n".localtime()." Waiting for input from $INPUT_TYPE...\n";

      my $rc;
      my $url;
      my %param = ( macaddress => $mac_address );
      if ($INPUT_TYPE eq 'card reader') {
         my ($track1, $track2, $track3);
         $rc = &CardReader::read_card(\$track1, \$track2, \$track3);
         $param{'track1'} = $track1 || '';
         $param{'track2'} = $track2 || '';
         $param{'track3'} = $track3 || '';

         print "Input data:\n";
         print "1: '" . $param{'track1'} . "'\n"
               . "2: '" . $param{'track2'} . "'\n"
               . "3: '" . $param{'track3'} . "'\n";

         $url = '/backend/cardreader/swipe';
      }
      elsif ($INPUT_TYPE eq 'keypad') {
         my $pin_code;
         $rc = &CardReader::read_keypad(\$pin_code, $KEYPAD_PIN_CODE_LENGTH, $KEYPAD_RESET_TIMEOUT);
         $param{'pincode'} = $pin_code || '';

         print "Input data:\n";
         print "Pin code: " . $param{'pincode'} . "\n";

         $url = '/backend/numpad/pincode';
      }
      else {
         die "Unknown input device $INPUT_TYPE\n";
      }

      unless ($rc) {
         print "Error reading input from $INPUT_TYPE\n";
         next;
      }

      $rc = HttpRequest::http_post_request($BIFROST_SERVER, 80, $url, \%param);
      if ($rc) {
         print "Ok\n";
      }
   } # while
}


#
# FUNCTIONS
#
sub get_mac_address {
   my $interface = shift;

   my $output = qx"/sbin/ifconfig $interface";
   my $mac_address;
   my $oct = '[0-9a-fA-F]{2}';
   if ($output =~ /\sHWaddr\s+(($oct:){5}$oct)/i) {
      $mac_address = $1;
   }
   else {
      print "ifconfig output: $output\n";
      return undef;
   }

   return $mac_address;
}


__END__
