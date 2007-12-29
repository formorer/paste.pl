#!/usr/bin/perl -w

use strict;
use Frontier::RPC2;
use Config::IniFiles;
use lib 'lib/'; 
use Paste;

my $config_file = 'paste.conf';
my $config = Config::IniFiles->new( -file => $config_file );
unless ($config) {
    my $error = "$!\n";
    $error .= join "\n", @Config::IniFiles::errors;
    die "Could not load configfile '$config_file': $error";
}

my $base_url = $config->val('www', 'base_url');

my $paste = new Paste($config_file); 

sub addPaste {
    my ($code, $name, $expire, $lang) = @_;
    $name = $name || 'anonymous';
	$expire = $expire || 72000;
	$lang = $lang || -1;

	my $error = 0; 
	my $statusmessage;
	my ($id, $digest) = $paste->add_paste($code, $name, $expire, $lang); 
	if ($paste->error) {
		$error = 1; 
		$statusmessage = $paste->error;
	} else {
		$statusmessage = "Your entry has been added to the database\n";
		$statusmessage .= "To download your entry use: $base_url/$id\n";
		$statusmessage .= "To delete your entry use: $base_url/$digest\n";
	}
    return {'id' => $id, 'statusmessage' => $statusmessage, 'rc' => $error, 'digest' => $digest} ;
}

sub deletePaste {
	my ($digest) = @_;
	my $error = 0; 
	my ($statusmessage, $id);
	if ($digest !~ /[0-9a-f]{40}/i) {
		$error = 1;
		$statusmessage = "Invalid digest ('$digest')"; 
	} else {
		$id = $paste->delete_paste($digest); 
		if ($paste->error) {
			$error = 1; 
			$statusmessage = $paste->error; 
		} else {
			$statusmessage = "Entry $id deleted"; 
		}
	}
	return {'rc' => $error, 'statusmessage' => $statusmessage, 'id' => $id }; 
}

sub getLanguages {
	my $error = 0; 
	my $statusmessage;
	my $lang_ref = $paste->get_langs();
	my @langs;
	if ($paste->error) {
		$error = 1; 
		$statusmessage = $paste->error; 
	} else { 
		foreach my $lang (@{$lang_ref}) {
			push @langs, $lang->{desc};
		}
	}
	return {'rc' => $error, 'statusmessage' => $statusmessage, 'langs' => \@langs,};
}
process_cgi_call({'paste.addPaste' => \&addPaste, 
			      'paste.deletePaste' => \&deletePaste,
				  'paste.getLanguages' => \&getLanguages, 
				});


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

