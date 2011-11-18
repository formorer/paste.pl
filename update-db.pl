#!/usr/bin/perl 

use DBI;
use Config::IniFiles;

my $config_file = 'paste.conf';

my $config = Config::IniFiles->new( -file => $config_file );
unless ($config) {
    my $error = "$!\n";
    $error .= join( "\n", @Config::IniFiles::errors );
    die "Could not load configfile '$config_file': $error";
}

my $dbname = $config->val( 'database', 'dbname' )
    || die "Databasename not specified in config";
my $dbuser = $config->val( 'database', 'dbuser' )
    || die "Databaseuser not specified in config";
my $dbpass = $config->val( 'database', 'dbpassword' ) || '';

my $dbh =
    DBI->connect( "dbi:Pg:dbname=$dbname", $dbuser, $dbpass,
    { RaiseError => 0, PrintError => 0 } )
    or die "Could not connect to DB: " . $DBI::errstr;

$rows_affected = $dbh->do("DELETE FROM LANG");

$sth = $dbh->prepare( '
	INSERT INTO lang ("desc") VALUES (?) 
	' ) or die $dbh->errstr;

while ( my $l = <> ) {
    chomp($l);
    $sth->execute($l);
}

# vim: syntax=perl sw=4 ts=4 noet shiftround
