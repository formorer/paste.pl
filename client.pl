#!/usr/bin/perl -w

use Frontier::Client;
use strict; 

my $server_url = 'http://paste.debian.net/server.pl';
my $server = Frontier::Client->new(url => $server_url);

# Call the remote server and get our result.
my $result = $server->call('paste.addShortURL', "http://www.spiegel.de/");
my $statusmessage = $result->{'statusmessage'};
my $hash = $result->{'hash'}; 
my $new_url =  $result->{'url'}; 
my $rc = $result->{'rc'};

print "$rc - $statusmessage - $hash - $new_url\n";

$result = $server->call('paste.resolveShortURL', $hash);
$statusmessage = $result->{'statusmessage'};
$hash = $result->{'hash'};
my $url =  $result->{'url'};
$rc = $result->{'rc'};
print "$rc - $statusmessage - $hash - $url\n";

$result = $server->call('paste.ShortURLClicks', '7g2R5v');
$statusmessage = $result->{'statusmessage'};
my $count = $result->{'count'};
$rc = $result->{'rc'};
print "$rc - $count - $url\n";

