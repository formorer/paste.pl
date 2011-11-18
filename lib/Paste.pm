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
use Digest::SHA1 qw(sha1_hex);
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use RPC::XML;
use RPC::XML::Client;

use Carp;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

@EXPORT = qw ();

sub new {
    my $invocant    = shift;
    my $class       = ref($invocant) || $invocant;
    my $config_file = shift || '';
    croak("Need a configfile ($config_file)") unless -f $config_file;
    my $config = Config::IniFiles->new( -file => $config_file );

    unless ($config) {
        my $error = "$!\n";
        $error .= join( "\n", @Config::IniFiles::errors );
        croak "Could not load configfile '$config_file': $error";
    }

    my $dbname = $config->val( 'database', 'dbname' )
        || carp "Databasename not specified in config";
    my $dbuser = $config->val( 'database', 'dbuser' )
        || carp "Databaseuser not specified in config";
    my $dbpass = $config->val( 'database', 'dbpassword' ) || '';
    my $base_url = $config->val( 'www', 'base_url' )
        || carp "base_url not specified in config";

    my $dbh =
        DBI->connect( "dbi:Pg:dbname=$dbname", $dbuser, $dbpass,
        { RaiseError => 0, PrintError => 0 } )
        or croak "Could not connect to DB: " . $DBI::errstr;

    my $self = {
        config => $config,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        dbh    => $dbh,
        @_,
    };

    bless( $self, $class );
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

sub add_paste ($$$$;$$) {
    my ( $self, $code, $name, $expire, $lang, $sessionid, $hidden ) = @_;
    my $dbh = $self->{dbh};
    $name      = $name      || 'anonymous';
    $sessionid = $sessionid || '';
    $hidden    = $hidden    || 'f';

    if ( $name !~ /^[^;,'"<>]{1,10}$/i ) {
        $self->{error} =
            "Invalid format for name (no special chars, max 10 chars)";
        return 0;
    }

    if ( $expire !~ /^(-1|[0-9]+)/ ) {
        $self->{error} = "Expire must be an integer or -1";
        return 0;
    }

    if ( $sessionid && $sessionid !~ /^[0-9a-f]{40}$/i ) {
        $self->{error} = "Sessionid does not look like a sha1 hex";
        return 0;
    }
    if ( $expire > 604800 ) {
        $self->{error} =
            'Expiration time can not be longer than 604800 seconds (7 days)';
        return 0;
    }

    my $code_size = length($code);

    if ( $code_size > 91080 ) {
        $self->{error} = 'Length of code is not allowed to exceed 90kb';
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

    if ( $newlines <= 1 ) {
        $self->{error} =
            'Thanks to some spammers you need to provide at least 3 or two linebreaks';
        return 0;
    }

	my $spamscore = $self->get_config_key('spam', 'score');
	if ($spamscore) {
		my ($hits, $score) = check_wordfilter($code);
		if ($hits && $score >= $spamscore) {
			$self->{error} = 'The spam wordfilter said you had $hits that led to a score of $score which is more or equal than the limit of $spamscore. If this was a false positive please contact the admin.';
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
        "SELECT id, poster, to_char(posted, 'YYYY-MM-DD HH24:MI:SS') as posted, code, lang_id, expires, sha1, sessionid from paste where id = ? and hidden is FALSE"
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
        "SELECT id, poster, to_char(posted, 'YYYY-MM-DD HH24:MI:SS') as posted, code, lang_id, expires, sha1, sessionid from paste where substring(sha1 FROM 1 FOR 8) = ?"
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

sub get_langs () {
    my ( $self, $id ) = @_;
    my $dbh = $self->{dbh};
    my $ary_ref =
        $dbh->selectall_arrayref( "SELECT * from lang", { Slice => {} } );
    if ( $dbh->errstr ) {
        $self->{error} =
            "Could not get languages vom database: " . $dbh->errstr;
        return 0;
    }
    return $ary_ref;
}

sub get_lang ($) {
    my ( $self, $lang ) = @_;
    my $dbh = $self->{dbh};

    my $lang_id_ref = $dbh->selectall_arrayref(
        "SELECT lang_id from lang where \"desc\" = '$lang'");

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
	my $paste = shift;

	my $db = $self->get_config_key('spam', 'db');
	next unless $db && -f $db;

	open (my $fh, '<', $db) or die "Could not open spamdb: $db";

	my $lkup;
	while (my $line = <$fh>) {
		my ($word, $score) = split (/\s+/, $line, 2); 
		$lkup->{$word} = $score;
	}
	close ($fh);

	my $aref = []; 
	words_list($aref, $paste);
	my ( $score, $hits ) = 0;
	foreach my $word (@{$aref}) {
		if (exists $lkup->{$word}) {
			$score += $lkup->{lc($word)};
			$hits++;
		}  
	}
	return $hits, $score;
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround
