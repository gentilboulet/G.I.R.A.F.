#! /usr/bin/perl -w
$| = 1;

use lib 'lib';

use strict;
use warnings;

use Giraf::Core;
use Getopt::Long;

my %opts;

readconfig("giraf.conf");	# TODO: parameter line

GetOptions(
	\%opts,       "help",       "server=s",   "serverpass=s",	"botpass=s",
	"botnick=s",  "botuser=s",  "botrealnam=s",  			"botchan=s",		"botbindip=s",
	"botident=s", "botmodes=s", "botopcmd=s", "maxtries=i",
	"botadmin=s", "logfile=s",  "debug=i",	  "triggers=s", "ssl=i"
  )
  or die ("Error: Could not parse command line. Try $0 --help");

Giraf::Core::init(%opts);
Giraf::Core::run();

exit 0;

sub readconfig
{
	my ($config) = @_;

	if ( !-e $config )
	{
		debug(
			"Error: Cannot find $config. Copy it to this directory, "
			. "please.",
			1
		);
	} else
	{
		open( CONF, "<$config" ) or do
		{
			debug( "Failed to open config file $config $!", 1 );
		};
		my ( $line, $key, $val );
		while ( $line = <CONF> )
		{
			next() if $line =~ /^#/;    # skip comments
			$line =~ s/[\r\n]//g;
			$line =~ s/^\s+//g;
			next() if !length($line);    # skip blank lines
			( $key, $val ) = split( /\s+/, $line, 2 );
			$key = lc($key);
			if ( lc($val) eq "on" || lc($val) eq "yes" )
			{
				$val = 1;
			} elsif ( lc($val) eq "off" || lc($val) eq "no" )
			{
				$val = 0;
			}
			if ( $key eq "die" )
			{
				die(    "Please edit the file $config to setup your bot's "
					  . "options. Also, read the README file if you haven't "
					  . "yet.\n" );
			} elsif ( $key eq "server" )
			{
				my @port = split( ":", $val, 2 );
				$opts{server} = $port[0];
				$opts{port}   = $port[1];
			} elsif ( $key eq "botchan" )
			{
				push( @{ $opts{botchan} }, $val );
			} else
			{
				$opts{$key} = $val;
			}
		}
	}
}

