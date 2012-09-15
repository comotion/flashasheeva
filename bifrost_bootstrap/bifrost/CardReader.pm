#
# Cato Feness, <ccf@linpro.no>, 2007-12-21
# 
package CardReader;


#
# CONSTANTS
# The values are mostly scrounged from include/linux/input.h, time.h etc.
#
my $DEBUG = 0;

my @EV_TYPE;
$EV_TYPE[0x00] = 'EV_SYN';
$EV_TYPE[0x01] = 'EV_KEY';
$EV_TYPE[0x02] = 'EV_REL';
$EV_TYPE[0x04] = 'EV_MSC';

my @EV_CODE = map { 'UNDEF' } ( 0 .. 255 );
$EV_CODE[56] =  'KEY_LEFTALT';
$EV_CODE[71] =  'KEY_KP7';
$EV_CODE[72] =  'KEY_KP8';
$EV_CODE[73] =  'KEY_KP9';
$EV_CODE[75] =  'KEY_KP4';
$EV_CODE[76] =  'KEY_KP5';
$EV_CODE[77] =  'KEY_KP6';
$EV_CODE[79] =  'KEY_KP1';
$EV_CODE[80] =  'KEY_KP2';
$EV_CODE[81] =  'KEY_KP3';
$EV_CODE[82] =  'KEY_KP0';
$EV_CODE[96] =  'KEY_KPENTER';

my @EV_VAL;
$EV_VAL[0] =  'RELEASE';
$EV_VAL[1] =  'PRESS';
$EV_VAL[2] =  'REPEAT';

my $TRACK_ERROR_CODE = 'E';

# l = seconds since epoch, l = +useconds, S = type, S = code, I = value
my $TMPL_INPUT_EVENT = 'llSSI';
my $INPUT_EVENT_LEN  = length(pack($TMPL_INPUT_EVENT));


#
# GLOBALS
#
my $INPUT_DEVICE;
my $PREV_TIME = 0;


#
# FUNCTIONS
#
sub init {
   my %params = @_;
   
   $DEBUG = 1 if $params{debug};
   my $device = $params{device} || '';
   open($INPUT_DEVICE, $device) || die "Unable to open device $device: $!";
   binmode($INPUT_DEVICE);
}


#
# Empties data from the event device to resynchronize
#
sub empty_input_data {
   my $len = 1024;
   $PREV_TIME = 0;
   while ($len <= sysread($INPUT_DEVICE, $_, $len)) {}
}

#
# Reads an event from the device
# returns true upon success
#
sub read_event {
   my $event_data = shift;
   my $allow_all_event_types = shift;
   %$event_data = ();

   my ($secs, $usecs, $type, $code, $value) = (undef, undef, undef, undef, undef);
   my $key_was_pressed = 0;

   while (not $key_was_pressed) {
      my $buf;
      my $len = sysread($INPUT_DEVICE, $buf, $INPUT_EVENT_LEN);

# must read entire event
      if ($len != $INPUT_EVENT_LEN) {
         empty_input_data;
         print "Got wrong data length for event: " . $len . "\n";
         return undef;
      }

      ($secs, $usecs, $type, $code, $value) = unpack($TMPL_INPUT_EVENT, $buf);

# time stamps must be chronological
      if ($secs < $PREV_TIME) {
         empty_input_data();
         print "Time stamp not chronological";
         return undef;
      }
      $key_was_pressed = 1 if $EV_TYPE[$type] eq 'EV_KEY'
         || $allow_all_event_types;
   };
   $event_data->{code}  = $EV_CODE[$code];
   $event_data->{value} = $EV_VAL[$value];
   $event_data->{type}  = $EV_TYPE[$type];
   return 1;
}


#
# Reads a character/byte from the device 
# Returns true upon success
#
# The swipe reader emulates pressing the decimal byte 
# values on the keypad while left alt is held.
#
sub read_char {
   my $char = shift;
   my %ev;

   # Wait for left alt key press
   my $got_key = 0;
   while (not $got_key) {
      my $rc = read_event(\%ev);
      return undef unless $rc;
      $got_key = 1 if $ev{code} eq 'KEY_LEFTALT' and $ev{value} eq 'PRESS';
   }

   # Read data until left alt is released
   $got_key = 0;
   my $tmp_char = '';
   while (not $got_key) {
      my $rc = read_event(\%ev);
      return undef unless $rc;
      if ($ev{code} eq 'KEY_LEFTALT' and $ev{value} eq 'RELEASE') {
	 $got_key = 1;
      }
      elsif ($ev{code} =~ /KEY_KP(\d)/ and $ev{value} eq 'PRESS') {
	 # build decimal value
	 $tmp_char .= $1;
      }
   }
   $$char = 0 + $tmp_char;
   return 1;
}

#
# Reads a swipe card
# The card format is:
# 
# [Tk1 SS] [Tk1 Data] [ES]
# [Tk2 SS] [Tk2 Data] [ES]
# [TK3 SS] [Tk3 Data] [ES]
#
# Tk1 SS = % (7-bit start sentinel)
# Tk2 SS = ; (ISO/ABA 5-bit start sentinel)
#          @ (7-bit start sentinel)
# Tk3 SS = + (ISO/ABA start sentinel)
#          # (AAMVA start sentinel)
#          & (7-bit start sentinel)
# ES     = ? (end sentinel)
# CR     = (carriage return) (0D hex)
#
sub read_card {
   # empty_input_data();
   my ($track1, $track2, $track3) = @_; # these are scalar refs

   my %tk1ss = ( 37 => '%' );
   my %tk2ss = ( 59 => ';', 64 => '@' );
   my %tk3ss = ( 43 => '+', 35 => '#', 38 => '&' );
   my %es    = ( 63 => '?' );
   my %cr    = ( 13 => 'CR' );

   my $char;
   my @buf;

   # First, read all data on card
   while (my $rc = read_char(\$char)) {
      return undef unless $rc;
      printf("Read char: %0d %s\n", $char, chr($char)) if $DEBUG;
      push(@buf, $char);
      last if $cr{$char};
   }

   # Read the good ol' tracks
   my $cur_track = undef;
   for my $c (@buf) {
      
      # are we in the process of reading data from a track?
      if (defined($cur_track)) {
	 # reached the end?
	 if ($es{$c}) {
	    $cur_track = undef;
	 }
	 else {
	    $$cur_track .= chr($c); # this is a tiny bit unsafe, should be changed to ensure a specific character set encoding
	    print "cur_track: $$cur_track\n" if $DEBUG;
	 }
      }
      # or haven't we started just yet?
      else {
	 # read track 1?
	 if ($tk1ss{$c}) {
	    print "reading track 1\n" if $DEBUG;
	    $cur_track = \($$track1 = '');
	 }
	 # read track 2?
	 elsif ($tk2ss{$c}) {
	    print "reading track 2\n" if $DEBUG;
	    $cur_track = \($$track2 = '');
	 }
	 # read track 3?
	 elsif ($tk3ss{$c}) {
	    print "reading track 3\n" if $DEBUG;
	    $cur_track = \($$track3 = '');
	 }
      }
   } # for

   # check that there were no problems reading the tracks, as
   # indicated by the swipe card reader returning an 'E'
   for my $t ($track1, $track2, $track3) {
      if ($t and $$t and $$t eq $TRACK_ERROR_CODE) {
        return undef;
      }
   }
   return 1;
}


sub flash_powerled {
   my ($flash_count, $flash_delay) = @_;

   my $proc_diag_filename = "/proc/diag/led/power";
   open my $diag_handle, ">$proc_diag_filename" || return;
   while ($flash_count > 0) {
      $flash_count--;
      syswrite $diag_handle, "0";
      select(undef, undef, undef, $flash_delay);
      syswrite $diag_handle, "1";
      select(undef, undef, undef, $flash_delay);
   }
   close ($diag_handle);
}


sub signal_user_keypad_reset {
   flash_powerled(1, 0.1);
}

sub signal_user_keypad_input_ok {
   flash_powerled(2, 0.2);
}

sub read_keypad {
   my ($pin_code_ref, $pin_code_length, $reset_timeout) = @_;
   $pin_code_length ||= 4;
   $reset_timeout ||= 10;

   my $input;

   while (1) {
      my $rin = '';
      vec($rin,fileno($INPUT_DEVICE),1)=1;
      my $nfound = select(my $rout=$rin, undef, undef, $reset_timeout);
      if ($nfound == 0 && $input) {
         signal_user_keypad_reset();
         $input = '';
      }
      my %ev;
      my $rc = read_event(\%ev, 1);
      next unless $rc;
      if (defined($ev{'code'}) && $ev{'code'} =~ /^KEY_KP/
            && $ev{'value'} eq 'PRESS'
            && $ev{'type'} eq 'EV_KEY') {

         if ($ev{code} =~ /KEY_KP(\d)/) {
            $input .= $1;
         }
         elsif($ev{'code'} eq 'KEY_KPENTER') {
            signal_user_keypad_reset();
            $input = '';
         }

         if (defined($input) && length($input) == $pin_code_length) {
            signal_user_keypad_input_ok();
            last;
         }
      }
   }
   $$pin_code_ref = $input;

   return 1;
}

1;

__END__

