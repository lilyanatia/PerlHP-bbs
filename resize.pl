#!/usr/bin/perl

use strict;
use CGI;

my $query=new CGI;
my $img=$query->param('img');
die 'invalid filename' if $img=~/(?:\.\.|\/|\\)/;
print "Content-type: image/png;\n\n",
	`convert src/$img -resize 240x320 png:-`
