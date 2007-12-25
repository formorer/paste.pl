#!/usr/bin/perl -w

use strict;
use Frontier::RPC2;
use Config::IniFiles;
use DBI;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);


my $config_file = 'paste.conf';
my $config = Config::IniFiles->new( -file => $config_file );
unless ($config) {
    my $error = "$!\n";
    $error .= join "\n", @Config::IniFiles::errors;
    die "Could not load configfile '$config_file': $error";
}

my $dbname = $config->val('database', 'dbname') || die "Databasename not specified";
my $dbuser = $config->val('database', 'dbuser') || die "Databaseuser not specified";
my $dbpass = $config->val('database', 'dbpassword') || '';

my $base_url = $config->val('www', 'base_url');

sub addPaste {
    my ($code, $name, $expire) = @_;
    $name = $name || 'anonymous';
	$expire = $expire || 72000;

    my $lang = 418;
	my $dbh = DBI->connect("dbi:Pg:dbname=$dbname", $dbuser, $dbpass) or die "Could not connect to db", "Could not connect to DB: " . $DBI::errstr;
	my $sth = $dbh->prepare("INSERT INTO paste(poster,posted,code,lang_id,expires,sha1) VALUES(?,now(),?,?,?,?)");
	$code =~ s/\r\n/\n/g;
	my $digest = sha1_hex($code . time());
	$sth->execute($name,$code,$lang,$expire,$digest);
	my $id;
	my $error = 0; 
	my $statusmessage ="";
	
	if ($dbh->errstr) {
		$error = 1; 
		$statusmessage .= "Could not add your entry to the paste database : " . $dbh->errstr;
	} else {
		$sth = $dbh->prepare("SELECT id from paste where sha1 = '$digest'");
		$sth->execute();
		if ($dbh->errstr) {
			$error = 1; 
			$statusmessage .= "Could not retrieve your entry from the paste database: " . $dbh->errstr;
		} else {
			while ( my @row = $sth->fetchrow_array ) {
				$id = $row[0];
			}
			$statusmessage = "Your entry has been added to the database\n";
			$statusmessage .= "To download your entry use: $base_url/$id\n";
			$statusmessage .= "To delete your entry use: $base_url/$digest\n";
		}
	}
    return {'id' => $id, 'statusmessage' => $statusmessage, 'rc' => $error} ;
}

sub deletePaste {
	my ($digest) = @_; 


}
process_cgi_call({'paste.addPaste' => \&addPaste});


#==========================================================================
#  CGI Support
#==========================================================================
#  Simple CGI support for Frontier::RPC2. You can copy this into your CGI
#  scripts verbatim, or you can package it into a library.
#  (Based on xmlrpc_cgi.c by Eric Kidd <http://xmlrpc-c.sourceforge.net/>.)

# Process a CGI call.
sub process_cgi_call ($) {
    my ($methods) = @_;

    # Get our CGI request information.
    my $method = $ENV{'REQUEST_METHOD'};
    my $type = $ENV{'CONTENT_TYPE'};
    my $length = $ENV{'CONTENT_LENGTH'};

    # Perform some sanity checks.
    http_error(405, "Method Not Allowed") unless $method eq "POST";
    http_error(400, "Bad Request") unless $type eq "text/xml";
    http_error(411, "Length Required") unless $length > 0;

    # Fetch our body.
    my $body;
    my $count = read STDIN, $body, $length;
    http_error(400, "Bad Request") unless $count == $length; 

    # Serve our request.
    my $coder = Frontier::RPC2->new;
    send_xml($coder->serve($body, $methods));
}

# Send an HTTP error and exit.
sub http_error ($$) {
    my ($code, $message) = @_;
    print <<"EOD";
Status: $code $message
Content-type: text/html

<title>$code $message</title>
<h1>$code $message</h1>
<p>Unexpected error processing XML-RPC request.</p>
EOD
    exit 0;
}

# Send an XML document (but don't exit).
sub send_xml ($) {
    my ($xml_string) = @_;
    my $length = length($xml_string);
    print <<"EOD";
Status: 200 OK
Content-type: text/xml
Content-length: $length

EOD
    # We want precise control over whitespace here.
    print $xml_string;
}
# vim: syntax=perl sw=4 ts=4 noet shiftround

