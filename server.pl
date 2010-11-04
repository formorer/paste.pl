#!/usr/bin/perl -w
#XML-RPC Interface to paste.debian.net
#Copyright (C) 2007  Alexander Wirt <formorer@debian.org>
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU Affero General Public License as
#published by the Free Software Foundation, either version 3 of the
#License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU Affero General Public License for more details.
#
#You should have received a copy of the GNU Affero General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

#The CGI Support has been copied from: http://tldp.org/HOWTO/XML-RPC-HOWTO/xmlrpc-howto-perl.htl


use strict;
use Frontier::RPC2;
use lib 'lib/'; 
use Paste;
use ShortURL;

my $config_file = 'paste.conf';
my $paste = new Paste($config_file); 

my $shorturl;

eval {
    $shorturl = new ShortURL($config_file);
};
error("Fatal Error", $@) if $@;

my $base_url = $paste->get_config_key('www', 'base_url');
my $short_url = $paste->get_config_key('shorturl', 'base_url'); 

sub addPaste {
    my ($code, $name, $expire, $lang, $hidden) = @_;
    $name = $name || 'anonymous';
	$expire = $expire || 72000;
	$hidden = $hidden ? 't' : 'f'; 

	$lang = $lang || "text";
	$lang = ($lang eq 'Plain') ? 'text' : $lang; 
	my $error = 0; 
	my $statusmessage;
	my $lang_id = -1;

	$lang_id = $paste->get_lang($lang); 
	if ($paste->error) {
		$error = 1;
		$statusmessage = $paste->error;
		return {'id' => '', 'statusmessage' => $statusmessage, 'rc' => $error, 'digest' => ''} ;
	}

	my ($id, $digest) = $paste->add_paste($code, $name, $expire, $lang_id, '', $hidden); 
	if ($paste->error) {
		$error = 1; 
		$statusmessage = $paste->error;
	} else {
		if ($hidden eq 'f') {
			$statusmessage = "Your entry has been added to the database\n";
			$statusmessage .= "To download your entry use: $base_url/download/$id\n";
			$statusmessage .= "To delete your entry use: $base_url/delete/$digest\n";
		} else {
			$statusmessage = "Your entry has been added to the database\n";
			$statusmessage .= "This entry is hidden. So don't lose your hidden id ($id)\n";
			$statusmessage .= "To download your entry use: $base_url/downloadh/$id\n";
			$statusmessage .= "To delete your entry use: $base_url/delete/delete/$digest\n";
		}
	}
    if ($hidden eq 't') {
	    $hidden = 1; 
    } else {
	    $hidden = 0; 
    }
    return {'id' => $id, 'statusmessage' => $statusmessage, 'rc' => $error, 'digest' => $digest, 'hidden' => $hidden} ;
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

sub getPaste {
	my ($id) = @_; 
	my $error = 0; 
	my $entry = $paste->get_paste($id);
	my $statusmessage;
	if (! $entry) {
		$error = 1; 
		$statusmessage = "Entry $id could not be found"; 
		return {'rc' => $error, 'statusmessage' => $statusmessage, 'code' => '', submitter => '', submitdate => '', expiredate => ''}; 
	} else {
		return {'rc' => $error, 'statusmessage' => $statusmessage,
				'code' => $entry->{code}, 'submitter' => $entry->{poster},
				'submitdate' => $entry->{posted}, expiredate => $entry->{expires}, };
	}
}

sub add_shorturl {
	my ($url) = @_; 

	my $hash = $shorturl->add_url($url);

	if ($shorturl->error) {
		return {'rc' => 1, 'statusmessage' => $shorturl->error, 'url' => ''};
	} else {
		return { 'rc' => 0, 'statusmessage' => '', 'hash' => $hash, 'url' => "$short_url/$hash" }; 
	}
}

sub resolve_shorturl {
	my ($hash) = @_; 
	if ($hash =~ /^https?:\/\/frm\.li\/(.*)/) {
		$hash = $1;
	}


	my $url = $shorturl->get_url($hash);

	if ($shorturl->error) {
		return {'rc' => 1, 'statusmessage' => $shorturl->error, 'url' => '', hash => $hash };
	} elsif ($url) {
		return { 'rc' => 0, 'statusmessage' => '', 'hash' => $hash, 'url' => "$url" }; 
	} else {
		return { 'rc' => 1, 'statusmessage' => "Hash $hash not found", 'hash' => $hash, 'url' => '' }; 
	}

}

sub shorturl_clicks {
	my ($hash) = @_; 

	my $count = $shorturl->get_counter($hash);
	if ($hash =~ /^https?:\/\/frm\.li\/(.*)/) {
		$hash = $1;
	}


	if ($shorturl->error) {
		return {'rc' => 1, 'statusmessage' => $shorturl->error, 'url' => '', hash => $hash };
	} else {
		return { 'rc' => 0, 'statusmessage' => '', 'hash' => $hash, 'count' => $count }; 
	}

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
				  'paste.getPaste' => \&getPaste,
				  'paste.addShortURL' => \&add_shorturl, 
				  'paste.resolveShortURL' => \&resolve_shorturl,
				  'paste.ShortURLClicks' => \&shorturl_clicks, 
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
    http_error(405, "Method Not Allowed") unless $method;
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

