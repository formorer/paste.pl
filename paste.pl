#!/usr/bin/perl 

use strict; 
use lib 'lib/';
use warnings;
use CGI qw(:standard);
use Template;
use POSIX;
use CGI::Carp qw(fatalsToBrowser); 
use CGI::Cookie;
use Paste;


my $template = Template->new ( { INCLUDE_PATH => 'templates', PLUGIN_BASE => 'Paste::Template::Plugin', } );


my $config_file = 'paste.conf'; 
my $paste;
eval {
	$paste = new Paste($config_file);
};
error("Fatal Error", $@) if $@;

my $dbname = $paste->get_config_key('database', 'dbname') || die "Databasename not specified";  
my $dbuser = $paste->get_config_key('database', 'dbuser') || die "Databaseuser not specified"; 
my $dbpass = $paste->get_config_key('database', 'dbpassword') || ''; 
#config 
my $base_url = $paste->get_config_key('www', 'base_url');


my $cgi = new CGI();
if ($cgi->param("plain")) {
	print_plain($cgi);
} elsif ($cgi->param("download")) {
	print_download($cgi);
} elsif ($cgi->param("show")) {
	print_show($cgi);
} elsif ($cgi->param("delete")){
	print_delete($cgi); 
} else {
	print_paste($cgi);
}

exit;

sub print_plain {
	my ($cgi,$status) = (@_);
	my $id = ''; 
	if ($cgi->param("plain")) {
		 $id = $cgi->param("plain");
	}
	my $paste = $paste->get_paste($id);
	if (! $paste) {
		 error("Entry not found", "Your requested paste entry '$id' could not be found");
	}
	print "Content-type: text/plain\r\n\r\n";
	print $paste->{code} . "\n";
}

sub print_download {
	my ($cgi,$status) = (@_);
	my $id = ''; 
	if ($cgi->param("download")) {
		 $id = $cgi->param("download");
	} else {
		print_paste($cgi);
	}

	my $paste = $paste->get_paste($id);

	if (! $paste) {
        error("Entry not found", "Your requested paste entry '$id' could not be found");
    }
	print "Content-type: text/plain\n";
	print "Content-Transfer-Encoding: text\n";
	print "Content-Disposition: attachment; filename=paste_$id\n";
	print "\r\n";
	print $paste->{code} . "\n";
}

sub print_delete {
	my ($cgi) = (@_);
	my $digest = '';
	if ($cgi->param("delete")) {
		$digest = $cgi->param("delete"); 
	} else {
		print_paste($cgi);
	}

	my $id = $paste->delete_paste($digest); 
	if (! $paste->error) {
		print_header();
		$template->process('show_message', {    "dbname" => "dbi:Pg:dbname=$dbname",
				"dbuser" => $dbuser,
				"dbpass" => $dbpass,
				"title" => "Entry $id deleted",
				"message" => "The entry with the id $id has been deleted.",
				"round" => sub { return floor(@_); },
				"base_url" => $base_url,
			}
		) or die $template->error() . "\n";
	} else {
		error("Entry could not be deleted", $paste->error);
	}
}

sub print_show {
    my ($cgi,$status) = (@_);
	my $id = '';
	my $lines = 1;
	if ($cgi->param("show")) {
		$id = $cgi->param("show");
	}
	if (defined($cgi->param("lines"))) {
		$lines = $cgi->param("lines"); 
	}
	print_header();
    $template->process('show', {	"dbname" => "dbi:Pg:dbname=$dbname", 
									"dbuser" => $dbuser, 
									"dbpass" => $dbpass,
									"show" => $id,
									"status" => $status, 
									"lines" => $lines,
									"round" => sub { return floor(@_); }, 
									"base_url" => $base_url, 
								} 
						) or die $template->error() . "\n";
}

sub print_paste {
	my ($cgi,$status) = (@_);
	do_submit($cgi);
	my $code;
	if ($cgi->param("upload")) {
		my $filename = $cgi->upload("upload");
		print_header();
		while (<$filename>) {
			$code .= $_;
		}
	} elsif ($cgi->param("code")) {
		$code = $cgi->param("code");
	}

	my $statusmessage;

	if ($code) {
		#okay we have a new entry
		#no name? ok 
		my $name; 
		if (! $cgi->param("poster")) {
			$name = "anonymous"; 
		} else {
			$name = $cgi->param("poster"); 
		}

		my ($id, $digest) = $paste->add_paste($code,$name,$cgi->param("expire"),$cgi->param("lang"));
		if ($paste->error) {
			$statusmessage .= "Could not add your entry to the paste database:<br>\n";
			$statusmessage .= "<b>" . $paste->error . "</b><br>\n";
		} else {
			if ($cgi->param("remember")) {
				my $cookie_lang = new CGI::Cookie(-name=>'paste_lang',
					-value=> $cgi->param("lang"));
				my $cookie_name = new CGI::Cookie(-name=>'paste_name', 
					-value=> $name);
				my %header = (-cookie=>[$cookie_lang, $cookie_name]);
				print_header(\%header); 
			} else {
				print_header();
			}
			$template->process('after_paste', { "dbname" => "dbi:Pg:dbname=$dbname",
					"dbuser" => $dbuser, 
					"dbpass" => $dbpass, 
					"status" => $statusmessage,
					"round" => sub { return floor(@_); },
					"id" => $id, 
					"digest" => $digest,
					"base_url" => $base_url, 
				}) or die $template->error() . "\n";								

			return;
		}
	}
	print_header();	
    $template->process('paste', {	"dbname" => "dbi:Pg:dbname=$dbname", 
									"dbuser" => $dbuser, 
									"dbpass" => $dbpass,
									"status" => $statusmessage, 
									"base_url" => $base_url,
									"round" => sub { return floor(@_); }, 
								} 
						) or die $template->error() . "\n";

}	
sub do_submit {
	my $cgi = @_; 
	warn $cgi;
}

sub error ($$) {
	my ($title,$errormessage) = @_;
	print_header();	
	$template->process('show_message', {	"dbname" => "dbi:Pg:dbname=$dbname", 
			"dbuser" => $dbuser, 
			"dbpass" => $dbpass,
			"title" => $title, 
			"message" => $errormessage,
			"round" => sub { return floor(@_); }, 
			"base_url" => $base_url, 
		} 
	) or die $template->error() . "\n";
	exit;
}

sub print_header {
	my $args = shift; 
	print header ( -charset => 'utf-8', -encoding => 'utf-8', %{$args} );
}
# vim: syntax=perl sw=4 ts=4 noet shiftround

