#ShortURL library for paste.debian.net
#Copyright (C) 2010  Alexander Wirt <formorer@debian.org>
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

package ShortURL;

use strict; 
use warnings; 
use Exporter; 
use Config::IniFiles;
use DBI; 
use Digest::JHash qw(jhash);
use Encode::Base58;


use Carp; 

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

@EXPORT = qw ();
sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;	
	my $config_file = shift || ''; 
	croak ("Need a configfile") unless -f $config_file; 
	my $config = Config::IniFiles->new( -file => $config_file );	

	unless ($config) {
		my $error = "$!\n"; 
		$error .= join("\n", @Config::IniFiles::errors);
		croak "Could not load configfile '$config_file': $error"; 
	}

	my $dbname = $config->val('database', 'dbname') || carp "Databasename not specified in config";
	my $dbuser = $config->val('database', 'dbuser') || carp "Databaseuser not specified in config";
	my $dbpass = $config->val('database', 'dbpassword') || '';
	my $base_url = $config->val('www', 'base_url') || carp "base_url not specified in config";	

	my $dbh = 
		DBI->connect("dbi:Pg:dbname=$dbname", $dbuser, $dbpass,
			{ RaiseError => 0, PrintError => 0}) or 
			croak "Could not connect to DB: " . $DBI::errstr;

	my $self = {
			config => $config, 
			dbname => $dbname, 
			dbuser => $dbuser, 
			dbpass => $dbpass, 
			dbh => $dbh,
			@_, 
		};

	bless ($self, $class);
	return $self;
}

sub get_config_key () {
	my ($self, $section, $key) = @_; 
	if ($self->{config}->val($section, $key)) {
		return $self->{config}->val($section, $key);
	} else {
		return undef;
	}
}

sub error {
	my $self = shift;
	return $self->{error};
}

=pod

=head2 add_url( B<url>)

=over 4

Adds a new shorturl to the database. 

=over 4 

=item B<url> 

A http or https url 

=back 

=back

=cut

sub add_url ($$) {
	my ($self, $url) = @_;
	my $dbh = $self->{dbh}; 

	#simple sanity check TODO improve
	if ($url !~ /^https?/) {
		$self->{'error'} = "Does not look like an URL",
		return 0; 
	} elsif ($url =~ /https?:\/\/frm\.li/) {
		$self->{'error'} = "Please don't do recursive URLs"; 
		return 0; 
	} elsif ($url =~ /https?:\/\/paste\.debian\.net/) {
		$self->{'error'} = "Please don't do recursive URLs"; 
		return 0; 
	}

	my $hash = encode_base58(Digest::JHash::jhash("$url" . time())); 

	my $sth = $dbh->prepare("INSERT INTO shorturl (url, hash) VALUES (?,?)"); 

	if ($dbh->err) {
		$self->{error} = "Could not prepare db statement: " . $dbh->errstr;
		return 0; 
	}

	my $collision = 1; 
	while ($collision == 1) {
		$sth->execute($url, $hash);
		if ($dbh->err) {
			if ($dbh->errstr =~ /constraint "shorturl_hash_key"/) {
				$hash = time(); 
				next; 
			} else {
				$self->error = $dbh->errstr;
				return 0; 
			}
		}
		$collision = 0; 
	}
	#if we are here everything worked 
	return $hash;
}

sub update_counter ($$) {
	my ($self, $hash) = @_;
	my $dbh = $self->{dbh}; 

	my $rc = $dbh->do('UPDATE shorturl SET clicks = clicks +1 where hash = ?;', undef, $hash); 
}

sub get_counter ($$) {
	my ($self, $hash) = @_;
	my $dbh = $self->{dbh}; 

	if ($hash =~ /^https?:\/\/frm\.li\/(.*)/) {
		$hash = $1; 
	}

	my  $count = $dbh->selectall_arrayref("SELECT clicks from shorturl where hash = ?", undef, $hash);

	if ($dbh->err) {
		$self->{error} = "Could not create db statement: " . $dbh->errstr;
		return 0;
	}

	if (! @{$count}) {
		$self->{error} = "Hash '$hash' not found in database.";
		return 1; 
	}

	return @{@{$count}[0]}[0];
}

sub get_url ($$) {
	my ($self, $hash) = @_;
	my $dbh = $self->{dbh};

	if ($hash =~ /^https?:\/\/frm\.li\/(.*)/) {
		$hash = $1; 
	}

	my  $url_ref = $dbh->selectall_arrayref("SELECT url from shorturl where hash = ?", undef, $hash); 

	if ($dbh->err) {
		$self->{error} = "Could not create db statement: " . $dbh->errstr;
		return 0;
	}

	if (! @{$url_ref}) {
		$self->{error} = "Hash '$hash' not found in database."; 
		return 0; 
	}

	return @{@{$url_ref}[0]}[0];
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround

