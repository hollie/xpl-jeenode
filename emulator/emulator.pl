#! /usr/bin/perl -w

# Jeenode with xpl_jeenode firmware emulator
#
# Used to verify the correct behaviour of the 
# xpl-jeenode code
#
# Lieven Hollevoet

use strict;

use IO::Socket;
use Net::hostent;  
use Data::Dumper;

my $server_port = 2501;

my $server = IO::Socket::INET->new( Proto     => 'tcp',
				     LocalPort => $server_port,
				     Listen    => SOMAXCONN,
				     Reuse     => 1);
my $client;
my $framecount=0;

# Try starting the server
die "can't setup server" unless $server;
print "[Server $0 accepting clients on port $server_port...]\n";

# Main program loop, only one client at a time
while ($client = $server->accept()) {
    # Autoflush to prevent buffering
    $client->autoflush(1);

    print "[< Accepted connection from client...]\n";

    while ( <$client>) {
        my $frame = $_;
        $frame =~ s/(\r\n)$//; # Strip trailing CRLF
        print "RX< $frame\n";

        if ($frame =~ /^?/){
            # Respond on init request
            print $client respond("aloha");

	    sleep(2);
	    # Generate a room event
	    print $client respond("ROOM25 190 1 60 215 0");
	    sleep(2);
	    # Generate a room event
	    print $client respond("ROOM25 190 0 60 215 0");
            next;
        }
        
       
        print "Oops: unknown message $frame\n";

    }
    
    # Once here, the client disconnected
    print "[> Remote peer disconnected ]\n";
    
    # Close and cleanup
    close $client;
    
}



sub respond
{
    my $payload=shift();
    
    my $res = $payload;
    print "TX> $res\n";

    $res = $res . "\n";
    
}

