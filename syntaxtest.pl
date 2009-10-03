#/usr/bin/perl 

use strict; 
use Template; 

use lib 'lib/';

my $template = Template->new ( { INCLUDE_PATH => 'templates', PLUGIN_BASE => 'Paste::Template::Plugin', } );

$template->process('test', { 
			'desc' => "perl", 
			'code' => 'print "foo"; foobar();', 
		}
	) ||  die $template->error(), "\n";

