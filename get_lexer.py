#!/usr/bin/python

from pygments.lexers import (get_all_lexers)

for lexname, aliases, _, mimetypes in get_all_lexers():
	print "%s" % (lexname)

