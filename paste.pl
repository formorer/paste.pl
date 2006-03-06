#!/usr/bin/perl 

use strict; 
use lib '/var/www/paste/lib/';
use warnings;
use CGI qw(:standard);
use Template;
use POSIX;
use DBI;

my $template = Template->new ( { INCLUDE_PATH => 'templates', PLUGIN_BASE => 'Paste::Template::Plugin', } );


my $cgi = new CGI();
warn $cgi->param;
if ($cgi->param("paste")) {
    do_submit($cgi);
	my $name = "anonymous" unless $cgi->param("paste");
	
} else {
    print_paste($cgi)
}

exit;

sub print_paste {
    my ($cgi) = (@_);
	my $show = '';
	if ($cgi->param("show")) {
		$show = $cgi->param("show");
	}
	print header;
    $template->process('paste', {	"db" => 'dbi:mysql:pastebin', 
									"user" => 'root', 
									"pass" => 'test',
									"show" => $show,
									"round" => sub { return floor(@_); }, 
								} 
									
						) or die $template->error() . "\n";
}

sub do_submit {
	my $cgi = @_; 
	warn $cgi;
}
# vim: syntax=perl sw=4 ts=4 noet shiftround

