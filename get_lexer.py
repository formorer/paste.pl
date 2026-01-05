#!/usr/bin/python

from pygments.lexers import (get_all_lexers)

for lexname, aliases, _, mimetypes in sorted(get_all_lexers(), key=lambda x: x[1][0] if x[1] else ""):
	if aliases:
		print("%s" % (aliases[0]))

