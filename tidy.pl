#!/usr/bin/perl

use strict;
use warnings;
use Modern::Perl;
use Config::Simple;

use File::Find;
use Perl::Tidy;
use Config::Simple;

my $config;
if ( -e 'tidy.ini' ) {
    say "Load configfile";
    $config = new Config::Simple('tidy.ini');
} else {
    die "tidy.ini not found";
}

my $filter = $config->param('filter') || '.pl$';

my @files = find_files($filter);

foreach my $file (@files) {
    say "Working on $file";
    my @output;
    open( my $fh, '<', $file ) or die "Could not open $file: $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    perltidy(
        source      => \$content,
        destination => $file,
        postfilter  => \&add_modeline
    );
}

sub add_modeline {
    my $content = shift;

    return unless defined $config->param('modeline');
    if ( $content !~ /^\s*#\s*vim: .*$/is ) {
        say "\tadd vim modeline";
        $content .= sprintf( "\n# vim: %s\n", $config->param('modeline') );
    }
    return $content;
}

sub find_files {
    my $filter = shift || '.pl$';
    say "Search for file matching '$filter'";
    my @files;
    find(
        sub {
            return unless -f;
            push @files, $File::Find::name if $_ =~ /$filter/;
        },
        '.'
    );
    return @files;
}
