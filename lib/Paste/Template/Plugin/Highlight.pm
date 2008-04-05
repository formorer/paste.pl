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

package Paste::Template::Plugin::Highlight;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
use Text::VimColor;
use Digest::SHA1 qw( sha1_hex );
use File::Temp qw / tempfile /;

use strict;

my @langs = qw (
    a65
    aap
    abaqus
    abc
    abel
    acedb
    ada
    aflex
    ahdl
    alsaconf
    amiga
    aml
    ampl
    antlr
    ant
    apachestyle
    apache
    arch
    art
    asm68k
    asmh8300
    asm
    asn
    aspperl
    aspvbs
    asterisk
    atlas
    automake
    ave
    awk
    ayacc
    baan
    basic
    bc
    bdf
    bib
    bindzone
    blank
    btm
    b
    calendar
    catalog
    cdl
    cfg
    cf
    changelog
    change
    chaskell
    cheetah
    chill
    ch
    clean
    clipper
    cl
    cobol
    colortest
    config
    conf
    cpp
    crm
    crontab
    csc
    csh
    csp
    css
    cs
    cterm
    ctrlh
    cuplsim
    cupl
    c
    cvsrc
    cvs
    cweb
    cynlib
    cynpp
    dcd
    dcl
    debchangelog
    debcontrol
    debsources
    def
    desc
    desktop
    diff
    dircolors
    diva
    dns
    docbksgml
    docbk
    docbkxml
    dosbatch
    dosini
    dot
    dracula
    dsl
    dtd
    dtml
    d
    dylanintr
    dylanlid
    dylan
    ecd
    edif
    eiffel
    elf
    elinks
    elmfilt
    erlang
    eruby
    esmtprc
    esqlc
    esterel
    eterm
    exim
    expect
    exports
    fasm
    fdcc
    fetchmail
    fgl
    focexec
    form
    forth
    fortran
    foxpro
    fstab
    fvwm2m4
    fvwm
    gdb
    gdmo
    gedcom
    gkrellmrc
    gnuplot
    gpg
    gp
    grads
    groff
    grub
    gsp
    gtkrc
    haskell
    hb
    help
    hercules
    hex
    hitest
    hog
    htmlcheetah
    htmlm4
    htmlos
    html
    ia64
    icemenu
    icon
    idlang
    idl
    indent
    inform
    inittab
    ipfilter
    ishd
    iss
    ist
    jal
    jam
    jargon
    javacc
    javascript
    java
    jess
    jgraph
    jproperties
    jsp
    kix
    kscript
    kwt
    lace
    latte
    ldif
    lex
    lftp
    lhaskell
    libao
    lifelines
    lilo
    lisp
    lite
    logtalk
    lotos
    lout
    lpc
    lprolog
    lscript
    lss
    lua
    lynx
    m4
    mailcap
    mail
    make
    manual
    man
    maple
    masm
    mason
    master
    matlab
    mel
    mf
    mgp
    mib
    mma
    mmix
    modconf
    model
    modsim3
    modula2
    modula3
    monk
    moo
    mplayerconf
    mp
    msidl
    msql
    mush
    muttrc
    mysql
    named
    nasm
    nastran
    natural
    ncf
    netrc
    nosyntax
    nqc
    nroff
    nsis
    objcpp
    objc
    ocaml
    occam
    omnimark
    openroad
    opl
    ora
    papp
    pascal
    pcap
    pccts
    perl
    pfmain
    pf
    php
    phtml
    pic
    pike
    pilrc
    pine
    pinfo
    plm
    plp
    plsql
    pod
    postscr
    po
    povini
    pov
    ppd
    ppwiz
    prescribe
    procmail
    progress
    prolog
    psf
    ptcap
    purifylog
    pyrex
    python
    qf
    quake
    radiance
    ratpoison
    rcslog
    rcs
    rc
    readline
    README.txt
    rebol
    registry
    remind
    resolv
    rexx
    rib
    rnc
    robots
    rpcgen
    rpl
    rst
    rtf
    ruby
    r
    samba
    sas
    sather
    scheme
    scilab
    screen
    sdl
    sed
    sendpr
    sgmldecl
    sgmllnx
    sgml
    sh
    sicad
    simula
    sindacmp
    sindaout
    sinda
    skill
    slang
    slice
    slrnrc
    slrnsc
    sl
    smarty
    smil
    smith
    sml
    sm
    snnsnet
    snnspat
    snnsres
    snobol4
    specman
    spec
    spice
    splint
    spup
    spyce
    sqlforms
    sqlj
    sql
    sqr
    squid
    sshconfig
    sshdconfig
    stp
    strace
    st
    sudoers
    svn
    syncolor
    synload
    syntax
    tads
    tags
    takcmp
    takout
    tak
    tasm
    tcl
    tcsh
    terminfo
    texinfo
    texmf
    tex
    tf
    tidy
    tilde
    tli
    tpp
    trasys
    tsalt
    tsscl
    tssgm
    tssop
    uc
    uil
    valgrind
    vb
    verilogams
    verilog
    vgrindefs
    vhdl
    viminfo
    vim
    virata
    vmasm
    vrml
    vsejcl
    wdiff
    webmacro
    web
    wget
    whitespace
    winbatch
    wml
    wsh
    wvdial
    xdefaults
    xf86conf
    xhtml
    xkb
    xmath
    xml
    xmodmap
    xpm2
    xpm
    xsd
    xslt
    xs
    xxd
    yacc
    yaml
    z8a
    zsh
);

push @langs, "Plain";
sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'highlight');

    return $self;
}

sub filter {
    my ($self, $text, $args, $config) = @_;

    #merge our caller and init configs
    $config = $self->merge_config($config);
    #then for arguments
    $args = $self->merge_args($args);

    if ( ! grep { lc($_) eq lc(@{$args}[0]) } @langs ) {
	die Template::Exception->new( highlight => "@$args[0] is not supported" );
    }

    my $digest = sha1_hex($text);
    my $lines = %$config->{'linenumbers'} || 0; 

    if (%$config->{'cache'}) {
	die Template::Exception->new( highlight => "cache_dir not found") unless -d %$config->{'cache_dir'};

	if (-f %$config->{'cache_dir'} . "/$digest-$lines") {
		open (my $fh, '<', %$config->{'cache_dir'} . "/$digest-$lines") or die Template::Exception->new( highlight => "Could not opencache file: $!");
		$text = join("\n", <$fh>); 
		close ($fh);
		return $text;
	}
    }

    use Encode qw(from_to);

    my $f = from_to($text, "utf-8", "iso8859-15");

    my $fh = tempfile(UNLINK => 1);
    print $fh "$text"; 
    my $syntax = Text::VimColor->new(
	string	=> "$text",
	filename => $fh,
	filetype => @$args[0],
    );
    close ($fh); 
    if (exists %$config->{'linenumbers'} && %$config->{'linenumbers'} == 1) {
	$text = "<ol style='list-style-type:decimal' class='synline'>\n";
	foreach my $line (split(/\n/, $syntax->html)) {
	    $text .= "<li class='synline'>$line</li>\n";
	}
	$text .= "</ol>";
    } else {
	    $text = "<br>";
	    foreach my $line (split(/\n/, $syntax->html)) {
		    $text .= "$line<br>\n";
	    }
	    $text .= "<br>";
    }
    $f = from_to($text, "iso8859-15", "utf-8");
    
    if (%$config->{'cache'} && -d %$config->{'cache_dir'} && -w %$config->{'cache_dir'}) {
	    open (my $fh, '>', %$config->{'cache_dir'} . "/$digest-$lines") or die Template::Exception->new( highlight => "Could not opencache file: $!");
	    print $fh $text;
	    close($fh);
    }	
    return $text;
}

1;
