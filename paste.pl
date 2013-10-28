#!/usr/bin/perl 

#CGI Interface to paste.debian.net
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

use strict;
use lib 'lib/';
use warnings;
use CGI qw(:standard);
use Template;
use POSIX;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use Digest::SHA qw (sha1_hex);
use Paste;
use ShortURL;

use subs qw(error);

my $template = Template->new(
    {   INCLUDE_PATH => 'templates',
        PLUGIN_BASE  => 'Paste::Template::Plugin',
    }
);

my $config_file = 'paste.conf';
my $paste;
eval { $paste = new Paste($config_file); };
error( "Fatal Error", $@ ) if $@;

my $shorturl;

eval { $shorturl = new ShortURL($config_file); };
error( "Fatal Error", $@ ) if $@;

my $dbname = $paste->get_config_key( 'database', 'dbname' )
    || die "Databasename not specified";
my $dbuser = $paste->get_config_key( 'database', 'dbuser' )
    || die "Databaseuser not specified";
my $dbpass = $paste->get_config_key( 'database', 'dbpassword' ) || '';

#config
my $base_url   = $paste->get_config_key( 'www',      'base_url' );
my $short_base = $paste->get_config_key( 'shorturl', 'base_url' );

my $cgi = new CGI();

if ( $cgi->param("plain") ) {
    print_plain($cgi);
} elsif ( $cgi->param("plainh") ) {
    print_plain( $cgi, 1 );
} elsif ( $cgi->param("download") ) {
    print_download($cgi);
} elsif ( $cgi->param("downloadh") ) {
    print_download( $cgi, 1 );
} elsif ( $cgi->param("comment") ) {
    print_add_comment($cgi);
} elsif ( $cgi->param("show") ) {
    print_show($cgi);
} elsif ( $cgi->param("hidden") ) {
    print_show( $cgi, 1 );
} elsif ( $cgi->param("delete") ) {
    print_delete($cgi);
} elsif ( $cgi->param("show_template") ) {
    print_template($cgi);
} elsif ( $cgi->param("shorturl") ) {
    print_shorturl($cgi);
} elsif ( $cgi->param("addurl") ) {
    add_shorturl($cgi);
} else {
    print_paste($cgi);
}

exit;

sub add_shorturl {
    my ($cgi) = @_;
    my $url = $cgi->param("addurl");

    my $hash = $shorturl->add_url($url);
    if ( $shorturl->error ) {
        error( "Could not add url",
            "Could not add url $url: " . $shorturl->error() );
    }
    print_header();
    $template->process(
        'shorturl_info',
        {   "dbname"     => "dbi:Pg:dbname=$dbname",
            "dbuser"     => $dbuser,
            "dbpass"     => $dbpass,
            "base_url"   => $base_url,
            "short_base" => $short_base,
            "hash"       => $hash,
            "cgi"        => $cgi
        }
    ) or die $template->error() . "\n";
}

sub print_shorturl {
    my ($cgi) = @_;
    my $hash  = $cgi->param("shorturl");
    my $url   = $shorturl->get_url($hash);
    if ( $shorturl->error ) {
        print header( 'text/plain', '500 Internal Server Error' );
        print "Something went wrong: \n";
        print $shorturl->error;
    } elsif ($url) {
        $shorturl->update_counter($hash);
        print $cgi->redirect($url);
    } else {
        print header( 'text/plain', '404 Not Found' );
        print "Move along, nothing to see here...\n";
    }
}

sub print_plain {
    my ( $cgi, $hidden ) = (@_);
    my $id = '';
    if ( $cgi->param("plain") ) {
        $id = $cgi->param("plain");

        #sanitizing
        $id =~ s/[^0-9]+//g;
    } elsif ( $cgi->param("plainh") ) {
        $id = lc( $cgi->param("plainh") );
        $id =~ s/[^0-9a-f]+//g;
    }
    if ( !$hidden ) {
        $paste = $paste->get_paste($id);
    } else {
        $paste = $paste->get_hidden_paste($id);
    }
    if ( !$paste ) {
        error( "Entry not found",
            "Your requested paste entry '$id' could not be found" );
    }
    print "Content-type: text/plain\r\n\r\n";
    print $paste->{code};
}

sub print_download {
    my ( $cgi, $hidden ) = (@_);
    my $id = '';
    if ( $cgi->param("download") ) {
        $id = $cgi->param("download");

        #sanitizing
        $id =~ s/[^0-9]+//g;
    } elsif ( $cgi->param("downloadh") ) {
        $id = lc( $cgi->param("downloadh") );
        $id =~ s/[^0-9a-f]//g;
    } else {
        print_paste($cgi);
    }

    if ( !$hidden ) {
        $paste = $paste->get_paste($id);

    } else {
        $paste = $paste->get_hidden_paste($id);
    }

    if ( !$paste ) {
        error( "Entry not found",
            "Your requested paste entry '$id' could not be found" );
    }
    print "Content-type: text/plain\n";
    print "Content-Transfer-Encoding: text\n";
    print "Content-Disposition: attachment; filename=paste_$id\n";
    print "\r\n";
    print $paste->{code};
}

sub print_delete {
    my ($cgi) = (@_);
    my $digest = '';
    if ( $cgi->param("delete") ) {
        $digest = $cgi->param("delete");
    } else {
        print_paste($cgi);
    }

    my $id = $paste->delete_paste($digest);
    if ( !$paste->error ) {
        print_header();
        $template->process(
            'show_message',
            {   "dbname"   => "dbi:Pg:dbname=$dbname",
                "dbuser"   => $dbuser,
                "dbpass"   => $dbpass,
                "title"    => "Entry $id deleted",
                "message"  => "The entry with the id $id has been deleted.",
                "round"    => sub { return floor(@_); },
                "base_url" => $base_url,
            }
        ) or die $template->error() . "\n";
    } else {
        error( "Entry could not be deleted", $paste->error );
    }
}

sub print_add_comment {
    my ($cgi) = (@_);
    my $error;
    my $comment  = $cgi->param("comment")  or $error = "Please add a comment";
    my $paste_id = $cgi->param("paste_id") or $error = "No Paste id found";
    my $name = $cgi->param("poster") || "anonymous";

    if ($error) {
        error( "Could not add comment: <br>\n" . $error );
    }

    my $digest;


    $paste->add_comment( $comment, $name, $paste_id );

    my $tmpl_name = $cgi->param("hide") ? "hidden" : "show";

    if ( !$paste->error ) {
        print_header();

warn $tmpl_name;
        $template->process(
            $tmpl_name,
            {   "dbname" => "dbi:Pg:dbname=$dbname",
                "dbuser" => $dbuser,
                "dbpass" => $dbpass,
                "show"   => $paste_id,
                "status" =>
                    "Your comment has been added to paste entry $paste_id.",
                "round"    => sub { return floor(@_); },
                "base_url" => $base_url,
            }
        ) or die $template->error() . "\n";
    } else {
        error( "Comment could not be added", $paste->error );
    }
}

sub print_template {
    my ( $cgi, $status ) = (@_);
    my $tmpl;
    my @templates = qw(about clients shorturl_info shorturl_add);

    if ( $cgi->param("show_template") ) {
        $tmpl = $cgi->param("show_template");
        if ( !grep /^$tmpl$/, @templates ) {
            error( "Page not found", "Page not found" );
        }
    }
    print_header();
    $template->process(
        $tmpl,
        {   "dbname"     => "dbi:Pg:dbname=$dbname",
            "dbuser"     => $dbuser,
            "dbpass"     => $dbpass,
            "base_url"   => $base_url,
            "short_base" => $short_base,
            "round"      => sub { return floor(@_); },
            "cgi"        => $cgi
        }
    ) or die $template->error() . "\n";
}

sub print_show {
    my ( $cgi, $hidden ) = (@_);
    my $id = '';
    my $status;
    my $lines = 1;
    if ( $cgi->param("show") ) {
        $id = $cgi->param("show");

        #sanitizing
        $id =~ s/[^0-9]+//g;
    } elsif ( $cgi->param("hidden") ) {
        $id = lc( $cgi->param("hidden") );
        $id =~ s/[^0-9a-f]//g;
    }
    if ( defined( $cgi->param("lines") ) ) {
        $lines = $cgi->param("lines");
    }
    print_header();
    my $tmpl_name = $hidden ? "hidden" : "show";

    $template->process(
        $tmpl_name,
        {   "dbname"   => "dbi:Pg:dbname=$dbname",
            "dbuser"   => $dbuser,
            "dbpass"   => $dbpass,
            "show"     => $id,
            "status"   => $status,
            "lines"    => $lines,
            "round"    => sub { return floor(@_); },
            "base_url" => $base_url,
        }
    ) or die $template->error() . "\n";
}

sub print_paste {
    my ( $cgi, $status ) = (@_);
    my $code;
    if ( $cgi->param("upload") ) {
        my $filename = $cgi->upload("upload");
        while (<$filename>) {
            $code .= $_;
        }
    } elsif ( $cgi->param("code") ) {
        $code = $cgi->param("code");
    }

    my $statusmessage;

    my $hidden;

    if ( $cgi->param("private") ) {
        $hidden = 't';
    } else {
        $hidden = 'f';
    }

    my $pnew;
    if ( $cgi->param("pnew") ) {
        $pnew = $cgi->param("pnew");

        #sanitizing
        $pnew =~ s/[^0-9]//g;
    }

    if ($code) {

        #okay we have a new entry
        #no name? ok
        my $name;
        if ( !$cgi->param("poster") ) {
            $name = "anonymous";
        } else {
            $name = $cgi->param("poster");
        }

        my $session_id = $cgi->param('session_id')
            || sha1_hex( rand() . time() );

	    my $wrap = $cgi->param("wrap");
	    my $expire = $cgi->param("expire");
	    my $lang = $cgi->param("lang");
        my ( $id, $digest ) =
            $paste->add_paste( { 
			    'code' => $code, 
			    'name' => $name, 
			    'expire' => $expire,
            		    'lang' => $lang, 
			    'session_id' => $session_id, 
			    'hidden' => $hidden, 
			    'wrap' => $wrap, 
			    'cgi' => $cgi
		    });
        if ( $paste->error ) {
            $statusmessage
                .= "Could not add your entry to the paste database:<br><br>\n";
            $statusmessage .= "<b>" . $paste->error . "</b><br>\n";
        } else {
            if ( my $remember = $cgi->param("remember") ) {
                my $cookie_lang = $remember eq "both" && new CGI::Cookie(
                    -name    => 'paste_lang',
                    -value   => $cgi->param("lang"),
                    -expires => '+2M',
                );
                my $cookie_expire = new CGI::Cookie(
                    -name    => 'paste_expire',
                    -value   => $cgi->param("expire"),
                    -expires => '+2M',
                );
                my $cookie_name = new CGI::Cookie(
                    -name    => 'paste_name',
                    -value   => $name,
                    -expires => '+2M',
                );
                my $session = new CGI::Cookie(
                    -name    => 'session_id',
                    -expires => '+1M',
                    -value   => $session_id,
                );
                my @cookies = grep { $_ } ($cookie_lang, $cookie_expire,
                                           $cookie_name, $session);
                my %header;
                if ( $hidden eq 'f' ) {
                    %header = (
                        -cookie => \@cookies,
                        -location => "$id/"
                    );
                } else {
                    %header = (
                        -cookie => \@cookies,
                        -location => "hidden/$id/"
                    );
                }
                print_header( \%header );
            } else {
                my $session = new CGI::Cookie(
                    -name    => 'session_id',
                    -expires => '+1M',
                    -value   => $session_id,
                );
                my %header;

                if ( $hidden eq 'f' ) {
                    %header = ( -cookie => [$session], -location => "$id/" );
                } else {

                    %header =
                        ( -cookie => [$session], -location => "hidden/$id/" );
                }
                print_header( \%header );
            }
            return;
        }
    }
    print_header();
    my $as_hidden = $cgi->param("as_hidden") ? 1 : 0;
    $template->process(
        'paste',
        {   "dbname"    => "dbi:Pg:dbname=$dbname",
            "dbuser"    => $dbuser,
            "dbpass"    => $dbpass,
            "status"    => $statusmessage,
            "pnew"      => $pnew,
            "base_url"  => $base_url,
            "as_hidden" => $as_hidden,
            "round"     => sub { return floor(@_); },
        }
    ) or die $template->error() . "\n";

}

sub error ($$) {
    my ( $title, $errormessage ) = @_;
    print_header();
    $template->process(
        'show_message',
        {   "dbname"   => "dbi:Pg:dbname=$dbname",
            "dbuser"   => $dbuser,
            "dbpass"   => $dbpass,
            "title"    => $title,
            "message"  => $errormessage,
            "round"    => sub { return floor(@_); },
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

# vim: syntax=perl sw=4 ts=4 noet shiftround
