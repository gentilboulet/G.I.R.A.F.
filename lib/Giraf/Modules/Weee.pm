#! /usr/bin/perl
$|=1;

package Giraf::Modules::Weee;

use strict;
use warnings;

use Giraf::Trigger;

our $version=1;
# Private vars
our @_ovations=(['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/','\\\\o','o//'], ['<o/'],['\\o>'],['\o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/'] , ['   __        __','  / / ___   / /',' < < / _ \ / /','  \_\\\\___//_/'], [' __        __',' \ \   ___ \ \\','  \ \ / _ \ > >','   \_\\\\___//_/']);

sub init {
	my ($kernel,$irc) = @_;

	Giraf::Core::debug("Giraf::Modules::Weee::init()");

	Giraf::Trigger::register('public_parser','Weee','bot_weee',\&bot_weee,'(\B[<>/|_\\\]o[/<>|_\\\]\B)|(\B[</|_\\\>]{2}o)|(o[/<>|_\\\]{2}\B)');
}

sub unload {

	Giraf::Core::debug("Giraf::Modules::Weee::unload()");

	Giraf::Trigger::unregister('public_parser','Weee','bot_weee');
}

sub bot_weee {
	my($nick, $dest, $what)=@_;
	Giraf::Core::debug("Giraf::Modules::Weee::bot_weee()");
	my @return;
	my $rand=int(rand(scalar(@_ovations)));
	my $ref=$_ovations[$rand];
	foreach my $e (@$ref)
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>$e};
		push(@return,$ligne);
	}
	return @return;
}

1;

