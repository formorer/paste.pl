use strict;
use warnings;
use lib 'lib';

# PSGI bootstrap for paste.debian.net (Mojolicious + TT + existing logic)

use Paste::App;

my $app = Paste::App->new;
my $handler = $app->start('psgi');

return $handler;

# vim: syntax=perl sw=4 ts=4 noet shiftround
