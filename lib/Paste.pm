#Paste library for paste.debian.net
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

package Paste;

use strict;
use warnings;
use Exporter;
use Config::IniFiles;
use DBI;
use Encode;
use Digest::SHA qw(sha1_hex);
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use RPC::XML;
use RPC::XML::Client;
use Text::ExtractWords qw (words_list);
use Text::Wrap;
use GnuPG;
use File::Temp qw ( tempfile );
use Format::Human::Bytes;
use WWW::Honeypot::httpBL;

use Carp;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

@EXPORT = qw ();

sub new {
    my $invocant    = shift;
    my $class       = ref($invocant) || $invocant;
    my $config_file = shift || '';
    my %opts        = @_;
    croak("Need a configfile ($config_file)") unless -f $config_file;
    my $config = Config::IniFiles->new( -file => $config_file );

    unless ($config) {
        my $error = "$!\n";
        $error .= join( "\n", @Config::IniFiles::errors );
        croak "Could not load configfile '$config_file': $error";
    }

    my $dbname =
           ( defined $ENV{DB_NAME} && length( $ENV{DB_NAME} ) && $ENV{DB_NAME} !~ /\$\{/ )
        ? $ENV{DB_NAME}
        : $config->val( 'database', 'dbname' )
        || carp "Databasename not specified in config";
    my $dbuser =
           ( defined $ENV{DB_USER} && length( $ENV{DB_USER} ) && $ENV{DB_USER} !~ /\$\{/ )
        ? $ENV{DB_USER}
        : $config->val( 'database', 'dbuser' )
        || carp "Databaseuser not specified in config";
    my $dbpass =
          ( defined $ENV{DB_PASSWORD} && length( $ENV{DB_PASSWORD} ) && $ENV{DB_PASSWORD} !~ /\$\{/ )
        ? $ENV{DB_PASSWORD}
        : ( $config->val( 'database', 'dbpassword' ) || '' );
    my $dbhost =
          ( defined $ENV{DB_HOST} && length( $ENV{DB_HOST} ) && $ENV{DB_HOST} !~ /\$\{/ )
        ? $ENV{DB_HOST}
        : $config->val( 'database', 'dbhost' );
    my $dbport =
          ( defined $ENV{DB_PORT} && length( $ENV{DB_PORT} ) && $ENV{DB_PORT} !~ /\$\{/ )
        ? $ENV{DB_PORT}
        : $config->val( 'database', 'dbport' );

    my $dsn;
    if ( $opts{dsn} ) {
        $dsn = $opts{dsn};
    } else {
        $dsn = "dbi:Pg:dbname=$dbname";
        $dsn .= ";host=$dbhost" if $dbhost;
        $dsn .= ";port=$dbport" if $dbport;
    }

    my $base_url = $ENV{BASE_URL}
        || $config->val( 'www', 'base_url' )
        || carp "base_url not specified in config";

    my $dbh =
        DBI->connect( $dsn, $dbuser, $dbpass,
        { RaiseError => 0, PrintError => 0 } )
        or croak "Could not connect to DB: " . $DBI::errstr;

    my $self = {
        config => $config,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        dbh    => $dbh,
        log    => $opts{log},
        @_,
    };

    bless( $self, $class );

    if ( $ENV{PASTE_DEBUG} || ( $self->{log} && $self->{log}->is_level('debug') ) ) {
        my $masked = $dbpass ? '***' : '';
        my $msg = "DB debug: dsn=$dsn user=$dbuser pass=$masked host=$dbhost port=$dbport ENV{DB_HOST}='" . ($ENV{DB_HOST}//'undef') . "'";
        if ( $self->{log} ) {
            $self->{log}->debug($msg);
        } else {
            warn "$msg\n";
        }
    }

    return $self;
}

sub get_config_key () {
    my ( $self, $section, $key ) = @_;
    if ( $self->{config}->val( $section, $key ) ) {
        return $self->{config}->val( $section, $key );
    } else {
        return undef;
    }
}

sub error {
    my $self = shift;
    return $self->{error};
}

=pod

=head2 add_paste( B<code>, B<name>, B<expire>, B<lang> [B<session_id>])

=over 4

Adds a new entry to the paste database. 

=over 4 

=item B<code> 

A string with \n or \r\n which represents the paste entry

=item B<name>

The name of the submitter, anonymous if empty

=item B<expire> 

Expire time in seconds from now() 

=item B<lang>

ID of the language for highlight. If 0 highlighting is disabled. 

=item B<sessionid> 

SHA1 of the sessionid which will be used to identify a special user. (optional) 

=back 

=back

=cut

sub add_paste {
    my $self      = shift;
    my $args      = shift;
    my $code      = $args->{code};
    my $name      = $args->{name};
    my $expire    = $args->{expire};
    my $lang      = $args->{lang};
    my $sessionid = $args->{session_id};
    my $hidden    = $args->{hidden};
    my $wrap      = $args->{wrap};

    my $dbh = $self->{dbh};
    $name      = $name      || 'anonymous';
    $sessionid = $sessionid || '';
    $hidden    = $hidden    || 'f';

    if ( !$args->{authenticated} ) {
        if ( $name !~ /^[^;,'"<>]{1,10}$/i ) {
            $self->{error} =
                "Invalid format for name (no special chars, max 10 chars)";
            return 0;
        }
    }

    if ( $lang !~ /^[0-9-]+$/ ) {
        $lang = $self->get_lang($lang);
        return 0 if $self->error;
    }
    if ( $expire !~ /^(-1|[0-9]+)/ ) {
        $self->{error} = "Expire must be an integer or -1";
        return 0;
    }

    if ( $sessionid && $sessionid !~ /^[0-9a-f]{40}$/i ) {
        $self->{error} = "Sessionid does not look like a sha1 hex";
        return 0;
    }

    my $max_code_size = $args->{authenticated} ? 5242880 : 153600;

    my $file;
    if ( $code =~ /^-----BEGIN PGP SIGNED MESSAGE/ ) {
        my $gpg = new GnuPG();
        my $sig;

        my $code_new;
        foreach my $line ( split( "\n", $code ) ) {
            $code_new .= "$line\n";
            last if $line =~ /^-----END PGP SIGNATURE-----/;
        }
        $code = $code_new;
        my ( $fh, $filename ) = tempfile( UNLINK => 1 );
        print $fh $code;
        close($fh);
        eval { $sig = $gpg->verify( signature => $filename ); };
        if ($sig) {
            die $sig->{'user'};
            if ( $self->{log} ) {
                $self->{log}->warn( "Code signed by " . $sig->{'user'} );
            } else {
                warn "Code signed by " . $sig->{'user'};
            }
            $max_code_size = 52428800;
        } elsif ( $@ =~ /no public key (\S+)/m ) {
            if ( $self->{log} ) {
                $self->{log}->warn( "Code signed by $1" );
            } else {
                warn "Code signed by $1";
            }
            $max_code_size = 52428800;
        }
        unlink($filename);
    }
    my $code_size = length($code);

    if ( defined($max_code_size) && $code_size > $max_code_size ) {
        my $readable = Format::Human::Bytes::base2($max_code_size);
        $self->{error} = "Length of code is not allowed to exceed $readable";
        return 0;
    }

    my $newlines = 0;
    my $pos      = 0;
    while (1) {
        $pos = index( $code, "\n", $pos );
        last if ( $pos < 0 );
        $newlines++;
        $pos++;
    }

    if ( !$args->{authenticated} ) {
        if ( defined $self->get_config_key( 'spam', 'linebreaks' )
            && $newlines < $self->get_config_key( 'spam', 'linebreaks' ) )
        {
            my $needed = $self->get_config_key( 'spam', 'linebreaks' );
            $self->{error} =
                "Thanks to some spammers you need to provide at least $needed linebreaks";
            return 0;
        }
    }

    unless ( $args->{authenticated} ) {
        my $spamscore = $self->get_config_key( 'spam', 'score' );
        if ($spamscore) {
            my ( $hits, $score ) = $self->check_wordfilter($code);
            if ( $hits && $score >= $spamscore ) {
                $self->{error} =
                    "The spam wordfilter said you had $hits that led to a score of $score which is more or equal than the limit of $spamscore. If this was a false positive please contact the admin.";
                return 0;
            }
        }

        if ( $self->get_config_key( 'spam', 'honeypotblkey' ) && $args->{cgi} ) {
            my $key = $self->get_config_key( 'spam', 'honeypotblkey' );
            my $h         = WWW::Honeypot::httpBL->new( { access_key => $key } );
            my $cgi       = $args->{cgi};
            my $remote_ip = $cgi->remote_host();
            $h->fetch($remote_ip);

            if (   $h->is_comment_spammer()
                || $h->is_suspicious() )
            {
                $self->{error} =
                    "Your ip ($remote_ip) is listed on http://www.projecthoneypot.org/. If this was a false positive please contact the admin";
                return 0;
            }

        }
    }

    my $sth = $dbh->prepare(
        "INSERT INTO paste(poster,posted,code,lang_id,expires,sha1, sessionid, hidden) VALUES(?,now(),?,?,?,?,?,?)"
    );
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    #replace \r\n with \n
    $code =~ s/\r\n/\n/g;

    #wrap text if wanted

    if ($wrap) {
        $code = wrap( "", "", $code );
    }

#we create some kind of digest here. This will be used for "administrative work". Everyone who has this digest can delete the entry.
#in the future the first 8 or so chars will be used as an accesskeys for "hidden" entrys.
    my $digest = hmac_sha1_hex( $code, sha1_hex( time() . rand() ) );

    $sth->execute( $name, $code, $lang, $expire, $digest, $sessionid,
        $hidden );

    if ( $dbh->errstr ) {
        $self->{error} = "Could not insert paste into db: " . $dbh->errstr;
        return 0;
    }

    #We need to get the id from our database so that the caller is able to
    #generate the proper URLs
    my $id;

    if ( $hidden eq 'f' ) {
        $sth = $dbh->prepare("SELECT id from paste where sha1 = ?");
        if ( $dbh->errstr ) {
            $self->{error} =
                "Could not prepare db statement: " . $dbh->errstr;
            return 0;
        }
        $sth->execute($digest);
        if ( $dbh->errstr ) {
            $self->{error} =
                "Could not retrieve your entry from the paste database: "
                . $dbh->errstr;
            return 0;
        }
        while ( my @row = $sth->fetchrow_array ) {
            $id = $row[0];
        }
    } else {
        $sth = $dbh->prepare(
            "SELECT  substring(sha1 FROM 1 FOR 8) AS id from paste where sha1 = ?"
        );
        if ( $dbh->errstr ) {
            $self->{error} =
                "Could not prepare db statement: " . $dbh->errstr;
            return 0;
        }
        $sth->execute($digest);
        if ( $dbh->errstr ) {
            $self->{error} =
                "Could not retrieve your entry from the paste database: "
                . $dbh->errstr;
            return 0;
        }
        while ( my @row = $sth->fetchrow_array ) {
            $id = $row[0];
        }
    }

    return $id, $digest;

}

=pod

=head2 add_comment( B<comment>, B<name>, B<paste_id> )

=over 4

Adds a new comment to the paste database. 

=over 4 

=item B<comment> 

A string with \n or \r\n which represents the comment

=item B<name>

The name of the submitter, anonymous if empty

=item B<paste_id>

The ID of the paste entry where the comment belongs to. 

=back 

=back

=cut

sub add_comment ($$$) {
    my ( $self, $comment, $name, $paste_id ) = @_;
    my $dbh = $self->{dbh};
    $name = $name || 'anonymous';

    if ( $name !~ /^[^;,'"]{1,30}/i ) {
        $self->{error} =
            "Invalid format for name (no special chars, max 30 chars)";
        return 0;
    }

    #id must be an integer
    if ( $paste_id !~ /^[0-9]+$/ ) {
        $self->{error} = "Invalid id format (must be an integer)";
    }

    my $paste_id_ref = $dbh->selectall_arrayref(
        "SELECT id FROM paste  WHERE id = '$paste_id'");
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    if ( !@{$paste_id_ref} ) {
        $self->{error} = "No entry with id '$paste_id' found";
        return 0;
    }

    my $sth = $dbh->prepare(
        "INSERT INTO comments(name,text,paste_id,date) VALUES(?,?,?,now())");
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    #replace \r\n with \n
    $comment =~ s/\r\n/\n/g;

    #even if it already should be valid UTF-8 encoding again won't harm.
    #Postgresql is a little bit picky about clean UTF-8
    #$comment = encode_utf8($comment);

    $sth->execute( $name, $comment, $paste_id );

    if ( $dbh->errstr ) {
        $self->{error} = "Could not insert comment into db: " . $dbh->errstr;
        return 0;
    }

    return 1;
}

=pod

=head2 delete_paste( B<digest> )

=over 4

Deletes a entry from the database. 

=over 4 

=item B<digest> 

The digest of the entry you want to delete

=back 

=back

=cut

sub delete_paste ($) {
    my ( $self, $sha1 ) = @_;
    my $dbh = $self->{dbh};

    if ( $sha1 !~ /^[0-9a-f]{40}$/i ) {
        $self->{error} = "Digest does not look like a sha1 hex";
        return 0;
    }
    my $deleted_id_ref =
        $dbh->selectall_arrayref("SELECT id from paste where sha1 = '$sha1'");

    if ( !@{$deleted_id_ref} ) {
        $self->{error} = "No entry with digest '$sha1' found";
        return 0;
    }
    my $id  = @{ @{$deleted_id_ref}[0] }[0];
    my $sth = $dbh->prepare("DELETE from paste where sha1 = ?");
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    $sth->execute($sha1);

    if ( $dbh->errstr ) {
        $self->{error} = "Could not delete paste from db: " . $dbh->errstr;
        return 0;
    }
    return $id;
}

=pod

=head2 delete_comment( B<id> )

=over 4

Deletes a comment from the database. 

=over 4 

=item B<id> 

The id of the comment you want to delete

=back 

=back

=cut

sub delete_comment ($) {
    my ( $self, $id ) = @_;
    my $dbh = $self->{dbh};

    if ( $id !~ /^[0-9]+$/i ) {
        $self->{error} = "ID does not look like an integer";
        return 0;
    }
    my $deleted_comment_ref =
        $dbh->selectall_arrayref("SELECT id from comments where id = '$id'");

    if ( !@{$deleted_comment_ref} ) {
        $self->{error} = "No entry with id '$id' found";
        return 0;
    }
    $id = @{ @{$deleted_comment_ref}[0] }[0];
    my $sth = $dbh->prepare("DELETE from comments where id = ?");
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    $sth->execute($id);

    if ( $dbh->errstr ) {
        $self->{error} = "Could not delete comment from db: " . $dbh->errstr;
        return 0;
    }
    return $id;
}

=pod

=head2 get_paste( B<id> )

=over 4

Returns an entry from the database. Returns undef if the entry couldn't be found. Otherwise a hashref with the entry will be returned. Beware that the digest is included. You should not reveal this to externals, otherwise your entrys can be deleted.  
This will not get entries marked as hidden. See get_hidden_paste if you want to retreive them. 

=over 4 

=item B<id> 

The id of the entry you want to retreive

=back 

=back

=cut

sub get_paste ($) {
    my ( $self, $id ) = @_;
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare(
        "SELECT id, poster, to_char(posted, 'YYYY-MM-DD HH24:MI:SS') as posted,
                code, paste.lang_id, lang.desc as lang_desc, expires, sha1, sessionid
         FROM paste LEFT JOIN lang ON paste.lang_id=lang.lang_id
         WHERE id = ? AND hidden IS FALSE"
    );
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    $sth->execute($id);
    if ( $dbh->errstr ) {
        $self->{error} = "Could not get paste from db: " . $dbh->errstr;
        return 0;
    }
    my $hash_ref = $sth->fetchrow_hashref;
    if ( defined( $hash_ref->{code} ) ) {
        return $hash_ref;
    } else {
        return undef;
    }
}

=pod

=head2 get_hidden_paste( B<id> )

=over 4

Returns a hidden entry from the database. Returns undef if the entry couldn't be found. Otherwise a hashref with the entry will be returned. Beware that the digest is included. You should not reveal this to externals, otherwise your entrys can be deleted.  

=over 4 

=item B<id> 

The id of the entry you want to retreive

=back 

=back

=cut

sub get_hidden_paste ($) {
    my ( $self, $id ) = @_;
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare(
        "SELECT id, poster, to_char(posted, 'YYYY-MM-DD HH24:MI:SS') as posted,
                code, paste.lang_id, lang.desc as lang_desc, expires, sha1, sessionid
         FROM paste LEFT JOIN lang ON paste.lang_id=lang.lang_id
         WHERE substring(sha1 FROM 1 FOR 8) = ?"
    );
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return 0;
    }

    $sth->execute($id);
    if ( $dbh->errstr ) {
        $self->{error} = "Could not get paste from db: " . $dbh->errstr;
        return 0;
    }
    my $hash_ref = $sth->fetchrow_hashref;
    if ( defined( $hash_ref->{code} ) ) {
        return $hash_ref;
    } else {
        return undef;
    }
}

sub get_paste_display {
    my ( $self, $id, $hidden ) = @_;
    my $dbh  = $self->{dbh};
    my $sql  = '';
    my $args = [$id];

    if ($hidden) {
        $sql =
            "SELECT id, substring(sha1 FROM 1 FOR 8) AS hidden_id, poster, code,
                    paste.lang_id, lang.desc AS lang_desc, expires, sha1, sessionid,
                    to_char(posted, 'YYYY-MM-DD HH24:MI:SS') AS postedate,
                    CASE WHEN expires = -1 THEN NULL ELSE
                        to_char(posted + (expires || ' seconds')::interval,
                                'YYYY-MM-DD HH24:MI:SS') END AS expiredate
             FROM paste
             LEFT JOIN lang ON paste.lang_id = lang.lang_id
             WHERE substring(sha1 FROM 1 FOR 8) = ?";
    } else {
        $sql =
            "SELECT id, poster, code, paste.lang_id, lang.desc AS lang_desc,
                    expires, sha1, sessionid,
                    to_char(posted, 'YYYY-MM-DD HH24:MI:SS') AS postedate,
                    CASE WHEN expires = -1 THEN NULL ELSE
                        to_char(posted + (expires || ' seconds')::interval,
                                'YYYY-MM-DD HH24:MI:SS') END AS expiredate
             FROM paste
             LEFT JOIN lang ON paste.lang_id = lang.lang_id
             WHERE id = ? AND hidden IS FALSE";
    }

    my $sth = $dbh->prepare($sql);
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare db statement: " . $dbh->errstr;
        return;
    }

    $sth->execute(@$args);
    if ( $dbh->errstr ) {
        $self->{error} = "Could not get paste from db: " . $dbh->errstr;
        return;
    }
    my $entry = $sth->fetchrow_hashref;
    return $entry if $entry && defined $entry->{code};
    return;
}

sub get_comments {
    my ( $self, $paste_id ) = @_;
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare(
        "SELECT text, name, to_char(date, 'YYYY-MM-DD HH24:MI:SS') AS postedate
         FROM comments
         WHERE paste_id = ?
         ORDER BY date ASC"
    );
    if ( $dbh->errstr ) {
        $self->{error} = "Could not prepare comments statement: " . $dbh->errstr;
        return;
    }

    $sth->execute($paste_id);
    if ( $dbh->errstr ) {
        $self->{error} = "Could not fetch comments: " . $dbh->errstr;
        return;
    }

    return $sth->fetchall_arrayref( {}, 1000 ) || [];
}

sub get_recent_pastes {
    my ( $self, $limit ) = @_;
    $limit ||= 10;

    return [];
}

sub get_user_pastes {
    my ( $self, $session_id, $limit ) = @_;
    $limit ||= 5;
    my $dbh = $self->{dbh};
    return [] unless $session_id;

    my $sth = $dbh->prepare(
        "SELECT id, poster,
                EXTRACT (epoch from (now() - posted)) as age,
                posted AS postedate,
                hidden, sha1, code
         FROM paste
         WHERE sessionid = ?
         ORDER BY posted DESC, id DESC
         LIMIT ?"
    );

    if ( $dbh->errstr ) {
        $self->{error} =
            "Could not prepare user pastes statement: " . $dbh->errstr;
        return;
    }

    $sth->execute( $session_id, $limit );
    if ( $dbh->errstr ) {
        $self->{error} = "Could not fetch user pastes: " . $dbh->errstr;
        return;
    }

    return $sth->fetchall_arrayref( {}, $limit ) || [];
}

sub get_langs () {
    my ( $self, $id ) = @_;
    my $dbh = $self->{dbh};
    my $ary_ref =
        $dbh->selectall_arrayref( "SELECT * from lang ORDER BY \"desc\"",
        { Slice => {} } );
    if ( $dbh->errstr ) {
        $self->{error} =
            "Could not get languages from database: " . $dbh->errstr;
        return 0;
    }
    return $ary_ref;
}

sub cleanup_expired {
    my ($self) = @_;
    my $dbh    = $self->{dbh};
    $dbh->do(
        "DELETE from paste where posted + interval '1 second' * expires < now() and expires <> '-1'"
    );
    return 1;
}

sub get_lang ($) {
    my ( $self, $lang ) = @_;
    my $dbh = $self->{dbh};

    my $lang_id_ref = $dbh->selectall_arrayref(
        "SELECT lang_id from lang where \"desc\" = ?", undef, $lang);

    if ( $dbh->errstr ) {
        $self->{error} = "Could not execute db statement: " . $dbh->errstr;
        return 0;
    }

    if ( !@{$lang_id_ref} ) {
        $self->{error} = "Language $lang not found";
        return 0;
    }
    my $id = @{ @{$lang_id_ref}[0] }[0];
    return $id;
}

sub check_ip ($) {
    my $ip  = shift;
    my $rbl = Net::RBLClient->new(
        max_time => 0.5,
        lists    => [
            'dnsbl.njabl.org',    'no-more-funn.moensted.dk',
            'spammers.v6net.org', 'proxies.monkeys.com'
        ],

    );
    $rbl->lookup($ip);
    my @listed_by = $rbl->listed_by;

    return 1 if @listed_by;
    return 0;
}

sub check_wordfilter ($) {
    my $self  = shift;
    my $paste = shift;

    my $db = $self->get_config_key( 'spam', 'db' );
    return unless $db && -f $db;

    open( my $fh, '<', $db ) or die "Could not open spamdb: $db";

    my $lkup;
    while ( my $line = <$fh> ) {
        my ( $word, $score ) = split( /\s+/, $line, 2 );
        $lkup->{$word} = $score;
    }
    close($fh);

    my $aref = [];
    words_list( $aref, $paste );
    my ( $score, $hits ) = 0;
    foreach my $word ( @{$aref} ) {
        if ( exists $lkup->{$word} ) {
            $score += $lkup->{ lc($word) };
            $hits++;
        }
    }
    return $hits, $score;
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround
