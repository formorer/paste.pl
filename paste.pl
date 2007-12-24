#!/usr/bin/perl 

use strict; 
use lib '/var/www/paste.pl/lib/';
use warnings;
use CGI qw(:standard);
use Template;
use POSIX;
use DBI;
use CGI::Carp qw(fatalsToBrowser); 
use CGI::Cookie;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);

my $template = Template->new ( { INCLUDE_PATH => 'templates', PLUGIN_BASE => 'Paste::Template::Plugin', } );

#config 
my $base_url = 'http://localhost/paste.pl';

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
	my $show = ''; 
	if ($cgi->param("plain")) {
		 $show = $cgi->param("plain");
	}
	my $dbh = DBI->connect('dbi:Pg:dbname=paste', 'postgres') or error ("Could not connect to DB", "Could not connect to DB: " . $DBI::errstr);
	my $sth = $dbh->prepare("SELECT code from paste where id = '$show'");
	$sth->execute() or error ("Could not execute query", "Error in executing query: " . $DBI::errstr);
	print "Content-type: text/plain\r\n\r\n";
	my $code;
	while ( my @row = $sth->fetchrow_array ) {
		$code = $row[0];
	}
	if ($code) {
		print $code;
	} else {
		error("Entry not found", "Your requested paste entry '$show' could not be found");
	}
}

sub print_download {
	my ($cgi,$status) = (@_);
	my $show = ''; 
	if ($cgi->param("download")) {
		 $show = $cgi->param("download");
	} else {
		print_paste($cgi);
	}
	my $dbh = DBI->connect('dbi:Pg:dbname=paste', 'postgres') or error("Could not connect to DB", "Could not connect to DB: " . $DBI::errstr);
	my $sth = $dbh->prepare("SELECT code from paste where id = '$show'");
	$sth->execute() or error ("Error in executing query", "Error in executing query: " . $DBI::errstr);
	print "Content-type: text/plain\n";
	print "Content-Transfer-Encoding: text\n";
	print "Content-Disposition: attachment; filename=paste_$show\n";
	print "\r\n";
	my $code; 
	while ( my @row = $sth->fetchrow_array ) {
		$code = $row[0];
	}
   if ($code) {
        print $code;
    } else {
        error("Entry not found", "Your requested paste entry '$show' could not be found");
    }
}

sub print_delete {
	my ($cgi) = (@_);
	my $sha1 = '';
	if ($cgi->param("delete")) {
		$sha1 = $cgi->param("delete"); 
	} else {
		print_paste($cgi);
	}
	my $dbh = DBI->connect('dbi:Pg:dbname=paste', 'postgres') or error("Could not connect to DB", "Could not connect to DB: " . $DBI::errstr);
	my $sth = $dbh->prepare("SELECT id from paste where sha1 = '$sha1'"); 
	$sth->execute() or error ("Error", "Error in executing query: " . $DBI::errstr);
	my $id;
	while ( my @row = $sth->fetchrow_array ) {
		$id = $row[0];
	}
	if ($id) {
		my $sth = $dbh->prepare("DELETE from paste where id = ?"); 
		$sth->execute($id) or error ("Error", "Error in executing query: " . $DBI::errstr); 
		print header;
		$template->process('show_message', {    "db" => 'dbi:Pg:dbname=paste',
				"user" => 'postgres',
				#"pass" => 'test',
				"title" => "Entry $id deleted",
				"message" => "The entry with the id $id has been deleted.",
				"round" => sub { return floor(@_); },
				"base_url" => $base_url,
			}
		) or die $template->error() . "\n";
	} else {
		error("Entry not found", "The entry with the digest '$sha1' could not be found");
	}
}

sub print_show {
    my ($cgi,$status) = (@_);
	my $show = '';
	my $lines = 1;
	if ($cgi->param("show")) {
		$show = $cgi->param("show");
	}
	if (defined($cgi->param("lines"))) {
		$lines = $cgi->param("lines"); 
	}
	print header;
    $template->process('show', {	"db" => 'dbi:Pg:dbname=paste', 
									"user" => 'postgres', 
									#"pass" => 'test',
									"show" => $show,
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
		print header;
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

		my $dbh = DBI->connect('dbi:Pg:dbname=paste', 'postgres') or error("Could not connect to db", "Could not connect to DB: " . $DBI::errstr);
		my $sth = $dbh->prepare("INSERT INTO paste(poster,posted,code,lang_id,expires,sha1) VALUES(?,now(),?,?,?,?)");
		my $code = $cgi->param("code");
		$code =~ s/\r\n/\n/g;
		my $digest = sha1_hex($code . time()); 
		$sth->execute($name,$code,$cgi->param("lang"),$cgi->param("expire"),$digest); 
			
		my $id;
		if ($dbh->errstr) {
			$statusmessage .= "Could not add your entry to the paste database:<br>\n";
			$statusmessage .= "<b>" . $dbh->errstr . "<b><br>\n";
		} else {
			$sth = $dbh->prepare("SELECT id from paste where sha1 = '$digest'");
			$sth->execute();
			if ($dbh->errstr) {
				$statusmessage .= "Could not retrieve your entry from the paste database:<br>\n";
				$statusmessage .= "<b>" . $dbh->errstr . "<b><br>\n";
			} else {
				while ( my @row = $sth->fetchrow_array ) {
					$id = $row[0];
				}
			}
		}
		if ($cgi->param("remember")) {
			my $cookie_lang = new CGI::Cookie(-name=>'paste_lang',
				-value=> $cgi->param("lang"));
		    my $cookie_name = new CGI::Cookie(-name=>'paste_name', 
				-value=> $name);
			print header(-cookie=>[$cookie_lang, $cookie_name]); 
		} else {
			print header;
		}
		$template->process('after_paste', { "db" => 'dbi:Pg:dbname=paste',
											"user" => 'postgres', 
											"status" => $statusmessage,
											"round" => sub { return floor(@_); },
											"id" => $id, 
											"digest" => $digest,
											"base_url" => $base_url, 
										}) or die $template->error() . "\n";								
			
										return;
	}
	print header;	
    $template->process('paste', {	"db" => 'dbi:Pg:dbname=paste', 
									"user" => 'postgres', 
									#"pass" => 'test',
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
	print header;	
	$template->process('show_message', {	"db" => 'dbi:Pg:dbname=paste', 
			"user" => 'postgres', 
			#"pass" => 'test',
			"title" => $title, 
			"message" => $errormessage,
			"round" => sub { return floor(@_); }, 
			"base_url" => $base_url, 
		} 
	) or die $template->error() . "\n";
	exit;
}
# vim: syntax=perl sw=4 ts=4 noet shiftround

