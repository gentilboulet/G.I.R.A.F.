#! /usr/bin/perl -w
$| = 1;

use lib 'lib';

use strict;
use warnings;

use Giraf::Core;

my $cfg_file = "giraf.conf";	# TODO: parameter line

Giraf::Core::init($cfg_file) or die "Cannot load config from $cfg_file !";
Giraf::Core::run();

exit 0;


