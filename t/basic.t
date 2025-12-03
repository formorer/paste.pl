use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use File::Spec;

BEGIN {
    $ENV{PASTE_CONFIG} = File::Spec->catfile( $FindBin::Bin, 'conf',
        'paste.conf' );
}

use Paste::App;

my $t = Test::Mojo->new('Paste::App');

$t->get_ok('/')->status_is(200);

my $code = "hello docker test\n";
$t->post_ok(
    '/' => form => {
        code   => $code,
        poster => 'tester',
        expire => 3600,
        lang   => -1,
    }
)->status_is(302);

my $loc = $t->tx->res->headers->location;
ok( $loc, 'got redirect location' );
my ($id) = $loc =~ m{/?([0-9a-f]+)/?};
ok( $id, "extracted id $id" );
$loc = "/$loc" unless $loc =~ m{^/};
$t->get_ok($loc)->status_is(200)->content_like(qr/$code/);
$t->get_ok("/plain/$id")->status_is(200)->content_is($code);

done_testing();

# vim: syntax=perl sw=4 ts=4 noet shiftround
