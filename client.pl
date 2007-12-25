#!/usr/bin/perl -w

use Frontier::Client;
use Getopt::Long;

# Make an object to represent the XML-RPC server.
$server_url = 'http://localhost/paste.pl/server.pl';
$server = Frontier::Client->new(url => $server_url);

my ($code); 
$name = "anonymous";

GetOptions(
	"name" => \$name, 
);

if (@ARGV) {
	$code = join("\n", $code); 
} else {
	while (<>) {
		$code .= $_;
	}
}
# Call the remote server and get our result.
$result = $server->call('paste.addPaste', "$code", "$name");
#$id = $result->{'id'};
$statusmessage = $result->{'statusmessage'};
#$rc = $result->{'rc'};

print "$statusmessage\n";

