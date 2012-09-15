#
# Cato Feness, <ccf@linpro.no>, 2008-01-04
#
package HttpRequest;


#
# Build and perform a post request
#
sub http_post_request {
   my $host 	 = shift;
   my $port 	 = shift;
   my $path 	 = shift;
   my $post_data = shift;

   my $ua = 'Bifrost card reader 1.0';

   my @tmp;
   while (my ($param, $value) = each %{$post_data}) {
      push(@tmp, url_encode($param) . "=" . url_encode($value));
   }
   my $post_string = join('&', @tmp);

   my $req = 
       "POST $path HTTP/1.1\r\n" .
       "Host: $host:$port\r\n" .
       "Content-Type: application/x-www-form-urlencoded\r\n".
       "Content-Length: ".length($post_string)."\r\n\r\n".
       "$post_string"; 

   print "HTTP request: \n$req\n";

   unless (socket_send($host, $port, $req, '^HTTP[\d\.\/]+ 200 OK$')) {
      return undef;
   }
   return 1;
}


#
# Simple send and then receive function
# using netcat.
#
sub socket_send {
   my $host  = shift;
   my $port  = shift;
   my $data  = shift;
   my $ok_rx = shift;

   my $tmpfile = "/tmp/http_req.$$";
   open(FH, "> $tmpfile");
   print FH $data;
   close(FH);

   if (open(NETCAT, "./netcat.sh $tmpfile $host $port |")) {
      my $response = join('', <NETCAT>);
      unlink $tmpfile;

      if (close NETCAT) {
	 print "HTTP response:\n $response\n";
	 if ($response =~ /$ok_rx/) {
	    return 1;
	 }
	 return undef;
      }
      else {
	 print "Unable to close netcat: $!\n";
	 return undef;
      }
   } else {
      print "Unable to open netcat";
   }
   return undef;
} 


sub socket_sendzz {
   my $host  = shift;
   my $port  = shift;
   my $data  = shift;
   my $ok_rx = shift;

   my $pid = open(KID_TO_WRITE, "|-");
   defined($pid) or return undef;
   
   if ($pid) { # parent
      print KID_TO_WRITE "$data";
      unless (close KID_TO_WRITE) {
	 print "Error closing KID_TO_WRITE: $!\n";
	 return undef;
      }
   } else { # child
      open(NETCAT, "nc $host $port |") || die "Unable to fork netcat: $!\n";
      my $response = join('', <NETCAT>);
      close(NETCAT) or die "Unable to close netcat: $!\n";
      print "HTTP response: $response\n";
      exit 0 if $response =~ /$ok_rx/;
      exit 1;
   }
   return 1;
}


#
# url_encode courtesy of
# CGI::Simple by Andy Armstrong,
# very slightly modified
#
sub url_encode {
   my $encode = shift;
   return undef unless defined $encode;
   $encode =~ s/([^A-Za-z0-9\-_.!~*'() ])/ uc sprintf "%%%02x",ord $1 /eg;
   $encode =~ tr/ /+/;
   return $encode;
}


1;
