use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use File::Spec;

BEGIN {
    if ( !$ENV{PASTE_CONFIG} && -f File::Spec->catfile( $FindBin::Bin, 'conf',
            'paste.conf' ) )
    {
        $ENV{PASTE_CONFIG} = File::Spec->catfile( $FindBin::Bin, 'conf',
            'paste.conf' );
    }
}

use Paste::App;

my $t = Test::Mojo->new('Paste::App');

subtest 'home page' => sub {
    $t->get_ok('/')->status_is(200);
};

my $code = "hello docker test\n";
subtest 'create hidden paste' => sub {
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
    my ($hidden_id) = $loc =~ m{([0-9a-f]+)/*$};
    ok( $hidden_id, "extracted hidden id $hidden_id" );
    $loc = "/$loc" unless $loc =~ m{^/};
    $t->get_ok($loc)->status_is(200)->content_like(qr/$code/);
    $t->get_ok("/plainh/$hidden_id")->status_is(200)->content_is($code);
};

subtest 'submit via form (urlencoded)' => sub {
    my $code2 = "hello via form\n";
    $t->post_ok(
        '/' => form => {
            code   => $code2,
            poster => 'formuser',
            expire => 3600,
            lang   => -1,
        }
    )->status_is(302);
    my $loc2 = $t->tx->res->headers->location;
    ok( $loc2, 'got redirect location for form post' );
    my ($hid2) = $loc2 =~ m{([0-9a-f]+)/*$};
    ok( $hid2, "extracted hidden id $hid2" );
    $loc2 = "/$loc2" unless $loc2 =~ m{^/};
    $t->get_ok($loc2)->status_is(200)->content_like(qr/$code2/);
    $t->get_ok("/plainh/$hid2")->status_is(200)->content_is($code2);
};

subtest 'reject empty paste' => sub {
    $t->post_ok( '/' => form => { code => '' } )->status_is(200)
        ->content_like(qr/Please add some text/);
};

subtest 'reject binary paste' => sub {
    my $binary = pack( "C*", 0, 1, 2, 3, 255 ) . "abc";
    $t->post_ok( '/' => form => { code => $binary } )->status_is(200)
        ->content_like(qr/Binary uploads are not allowed/);
};

subtest 'highlight renders for non-ascii bash paste' => sub {
    my $code3 = "echo café\n";
    $t->post_ok(
        '/' => form => {
            code   => $code3,
            poster => 'bashuser',
            expire => 3600,
            lang   => 'bash',
        }
    )->status_is(302);
    my $loc3 = $t->tx->res->headers->location;
    my ($hid3) = $loc3 =~ m{([0-9a-f]+)/*$};
    ok( $hid3, "extracted hidden id $hid3" );
    $loc3 = "/$loc3" unless $loc3 =~ m{^/};
    my $res = $t->get_ok($loc3)->status_is(200)->tx->res->body;
    like( $res, qr/pygment/, 'highlighted output contains pygment classes' );
    $t->get_ok("/plainh/$hid3")->status_is(200)->content_is($code3);
};

subtest 'delete removes paste' => sub {
    my $code4 = "deleteme\n";
    $t->post_ok(
        '/' => form => {
            code   => $code4,
            poster => 'deleter',
            expire => 3600,
            lang   => -1,
        }
    )->status_is(302);
    my $loc4 = $t->tx->res->headers->location;
    my ($hid4) = $loc4 =~ m{([0-9a-f]+)/*$};
    ok( $hid4, "extracted hidden id $hid4" );

    my $cfg = $ENV{PASTE_CONFIG}
        || File::Spec->catfile( $FindBin::Bin, 'conf', 'paste.conf' );
    my $model = Paste->new($cfg);
    my $row   = $model->get_hidden_paste($hid4);
    ok( $row->{sha1}, 'found digest for paste' );
    $t->get_ok("/delete/$row->{sha1}")->status_is(200)
        ->content_like(qr/deleted/i);
    $t->get_ok("/plainh/$hid4")->status_is(200)
        ->content_like(qr/could not be found|not be found/i);
};

done_testing();

# vim: syntax=perl sw=4 ts=4 noet shiftround
