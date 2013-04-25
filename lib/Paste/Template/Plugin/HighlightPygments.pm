#Perl Template toolkit pluginText::VimColor
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

package Paste::Template::Plugin::HighlightPygments;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
use Digest::SHA qw( sha1_hex );
use File::Temp qw (tempfile );

use strict;

my @langs;

open( my $fh, '<', 'langs' )
    or die Template::Exception->new(
    highlight => "Could not open languagefile: $!" );
while ( my $l = <$fh> ) {
    chomp($l);
    push @langs, $l;
}

sub init {
    my $self = shift;

    $self->{_DYNAMIC} = 1;

    # first arg can specify filter name
    $self->install_filter( $self->{_ARGS}->[0] || 'highlight' );

    return $self;
}

sub filter {
    my ( $self, $text, $args, $config ) = @_;

    #merge our caller and init configs
    $config = $self->merge_config($config);

    #then for arguments
    $args = $self->merge_args($args);

    if ( !grep { lc($_) eq lc( @{$args}[0] ) } @langs ) {
        die Template::Exception->new(
            highlight => "@$args[0] is not supported" );
    }

    my $digest = sha1_hex($text);
    my $lines = $config->{'linenumbers'} || 0;

    if ( $config->{'cache'} ) {
        die Template::Exception->new( highlight => "cache_dir not found" )
            unless -d $config->{'cache_dir'};

        if ( -f $config->{'cache_dir'} . "/$digest-$lines" ) {
            open( my $fh, '<', $config->{'cache_dir'} . "/$digest-$lines" )
                or die Template::Exception->new(
                highlight => "Could not open cache file: $!" );
            $text = join( "", <$fh> );
            close($fh);
            return $text;
        }
    }

    #print $fh "$text";

    my $lang = @$args[0];
    $lang = ( $lang eq 'Plain' ) ? 'text' : $lang;
    use IPC::Run3;
    my $out;
    my $stderr;

    my $pygment =
          '/usr/bin/pygmentize -f html -l "' 
        . $lang
        . '" -O style=default,classprefix=pygment';
    if ( exists $config->{'linenumbers'} && $config->{'linenumbers'} == 1 )
    {
        $pygment .= ',linenos=1';
    }

    if ( exists $config->{'style'} ) {
        $pygment .= ',style=' . $config->{'style'};
    }

    run3( $pygment, \$text, \$out, \$stderr );

    if ($stderr) {
        die Template::Exception->new( highlight => "pymentize error: $out" );
    }

    my $text = $out;

    if (   $config->{'cache'}
        && -d $config->{'cache_dir'}
        && -w $config->{'cache_dir'} )
    {
        open( my $fh, '>', $config->{'cache_dir'} . "/$digest-$lines" )
            or die Template::Exception->new(
            highlight => "Could not opencache file: $!" );
        print $fh $text;
        close($fh);
    }
    return $text;
}

1;

# vim: syntax=perl sw=4 ts=4 noet shiftround
