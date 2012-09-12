#!/usr/bin/perl
use strict;
use warnings;

#####################
## This is a DummAssSimple POE client (das_POE_client.pl)
##
## This script will connect to a POE type server 
## using Yaml as the data exchange method. It is intended
## for a limited and structured request-response between
## the client and the server.
##
## It is not intended to be asynchronous. The POE servers
## of interest to this client provide configuration 
## information to the client so the client processes must wait
## for the new info before moving to the next (or main) task, such
## as starting a server. (Yes, POE people, many tasks in the
## event-driven world have prequistes :D)
##
## The script pulls in the POE Reference filter to use with
## Yaml. This can be easily changed to a text line filter.
## Note: The POE filter seems to work very well pulling data
## from the server, but not so well pushing data at the server.
## The method 'format_POE_Yaml_send' takes care of formatting
## the send data so the POE server can understand the data
## request.
#####################################

## modules/packages of interest
use YAML::XS qw(LoadFile DumpFile Load Dump);
use IO::Socket;
use IO::Socket::INET;
use POE::Filter::Reference;

## set some variables
my $data_container = {};
my $view_rcpt_packet = 1;

####
## Application specific hash array for data exchange
## the client talks whatever language the server talks
####
my $send = {};
$send->{state} = 'tellme...something';
$send->{type} = 'das_client';
$send->{key} = 0;

## setup the POE Reference filter
my $yaml = 'YAML';
my $ref_filter = POE::Filter::Reference->new($yaml);

## create a socket
my $nonblocking = 1;
my $retries = 0;
my $socket = &connect_sysread_socket($nonblocking,$retries);

## make the socket hot
$| = 1;

####
## Initial connection socket read. This should be the server 'welcome' messege
####
my $welcome_rcpt = [];
while (sysread($socket, my $buffer = '', 1024)) {
	my $lines = $ref_filter->get([$buffer]);
	foreach my $l (@$lines) {
		push @$welcome_rcpt, $l;
	}
}
my $size = scalar(@$welcome_rcpt);
if($view_rcpt_packet) {
	print "number of rows in welcome messege[$size]\n";
}
if($size) {
	if($view_rcpt_packet) {
		my $d = $welcome_rcpt->[0];
		while(my ($k,$v) = (each %$d)) {
			print "\tin k[$k]v[$v]\n";
		}
	}
}

####
## the welcome message could be checked for integrity
## but for now, we will assume it is from the right server :)
####

####
## package the send (info request) hash array into a Yaml stream - formatted for a POE server
####
my $req_send = &format_POE_Yaml_send($send);

####
## write the info request data package to the socket
####
syswrite($socket,$req_send,1024);

####
## go into a while loop to wait for the data to come back
## if there are multiple req-rep's than more logic will be needed
####
my $data_rcpt = [];
my $check_socket = 1;
while($check_socket) {
	while (sysread($socket, my $buffer2 = '', 1024)) {
		my $lines = $ref_filter->get([$buffer2]);
		foreach my $l (@$lines) {
			push @$data_rcpt, $l;
		}
		#print "new buffer data received.\n";
		
		## only one socket packet...so stop outside 'while' loop once data has been read.
		$check_socket = 0;
	}
	if($check_socket) {
		print "No socket data to read. Sleeping (1)\n";
		sleep(1);
	}
}

####
## a quick check of data integrity
####
my $dsize = scalar(@$data_rcpt);
print "number of elements in data rcpt[$dsize]\n";

####
## if there is data, store to a hash variable
####
if($dsize) {
	my $d = $data_rcpt->[0];
	
	####
	## loop thru hash to find actual data packet.
	## the yaml/href d variable contains additional helper key-value pairs
	## that are not data per se.
	####
	while(my ($k,$v) = (each %$d)) {
		
		####
		## the data packet will have a href value
		####
		if($v=~/HASH/) {
			####
			## the data is keyed under 'data'
			####
			if(exists $v->{data}) {
				my $rdata = $v->{data};
				my $rsize = scalar(keys %$rdata);
				print "the number of {green nosed scoobie doos} from data_server[$rsize]\n";
				while(my($pid,$href) = (each %$rdata)) {
					$data_container->{$pid} = $href;
				}
			}
		}
	}
}

## terminate connection
close($socket);

exit;

sub connect_sysread_socket {
	my $nonblocking = shift;
	my $retry = shift;
	my $locale = localtime();

	my $socket = &open_socket($retry);
	print "TCP Connection Success. on host[".$socket->peerhost."] port[".$socket->peerport."]\n";

	## provides nonblocking behavior on Win32 boxes...using a C function
	ioctl($socket, 0x8004667e, \$nonblocking);
	
	return $socket;
}

sub open_socket {
	my $retry = shift;
	my $socket = new IO::Socket::INET ( 
					PeerAddr => 'localhost', 
					PeerPort => '44409',
					Proto => 'tcp',
					Reuse => 1,
					);
	die "Could not create socket: $!\n" unless $socket; 
	return $socket;
}

sub format_POE_Yaml_send {
	my $y_data = shift;
	
	my $frozen = Dump($y_data);
	
	# # Need to check lengths in octets, not characters.
	BEGIN { eval { require bytes } and bytes->import; }

	## NO data compression
	my $send = length($frozen) . "\0" . $frozen;

	return $send;
}
