#! /usr/bin/perl -w

package Giraf::Config;

use strict;
use warnings;

use Getopt::Long;

our %config;

sub load {
	my ($cfg_file) = @_;

	my %opts = readconfig($cfg_file);
	
	GetOptions(
		\%opts,       "help",       "server=s",   "serverpass=s",	"botpass=s",
		"botnick=s",  "botuser=s",  "botrealnam=s",  			"botchan=s",		"botbindip=s",
		"botident=s", "botmodes=s", "botopcmd=s", "maxtries=i",
		"botadmin=s", "logfile=s",  "debug=i",	 "debug_level=i", "triggers=s", "ssl=i",
		"dbsrc=s", "dbuser=s", "dbpass=s"
	  )
	or return 0;

	%config = %opts;
	return scalar keys %config;
}

sub get {
	my ($name) = @_;
	if($config{$name})
	{
		return $config{$name};
	}
	else
	{
		return "";
	}
}

sub set {
	my ($name, $value) = @_;

	$config{$name} = $value;
}

# Ulgy config file reader
sub readconfig
{
	my ($cfg_file) = @_;
	my %opts = ();

	if ( !-e $cfg_file )
	{
		die "Error: Cannot find $cfg_file. Copy it to this directory, please.";
	}
	else
	{
		open( CONF, "<$cfg_file" ) or do
		{
			debug( "Failed to open config file $cfg_file $!", 1 );
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
				die(    "Please edit the file $cfg_file to setup your bot's "
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
	return %opts;
}

1;
