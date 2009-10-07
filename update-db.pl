#!/usr/bin/perl 

use DBI; 

$dbh = DBI->connect("dbi:Pg:dbname=paste", "", "");

$rows_affected = $dbh->do(
	                 "DELETE FROM LANG");


$sth = $dbh->prepare( '
	INSERT INTO lang ("desc") VALUES (?) 
	') or die $dbh->errstr;

open (my $fh, '<', 'langs') or die "could not open langs: $!"; 

while (my $l = <$fh>) {
	chomp($l); 
	$sth->execute($l); 
}
 
