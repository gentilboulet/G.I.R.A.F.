#! /usr/bin/perl

$|=1;

package Giraf::Modules::Gygax;

use strict;
use warnings;

use Giraf::Admin;

use POSIX qw(ceil floor);
use List::Util qw(min sum);

our $version=1;

sub init {
	my ($kernel,$irc) = @_;
	Giraf::Trigger::register('public_function','Gygax','bot_gygax',\&bot_gygax,'gygax');
	Giraf::Trigger::register('public_function','Gygax','bot_4d6',\&bot_4d6,'dnd_4d6');
}

sub unload {
	Giraf::Trigger::unregister('public_parser','Gygax','bot_gygax');
	Giraf::Trigger::unregister('public_parser','Gygax','bot_4d6');
}

sub bot_gygax {
	my($nick, $dest, $what)=@_;
	Giraf::Core::debug("bot_gygax()");
	my @return;
	my $stats={STR=>roll(),DEX=>roll(),CON=>roll(),INT=>roll(),WIS=>roll(),CHA=>roll()};
	my ($modifs,$total,$total_modif,$ligne,$msg);

	$modifs->{STR} = floor(($stats->{STR}-10)/2);
	$modifs->{DEX} = floor(($stats->{DEX}-10)/2);
	$modifs->{CON} = floor(($stats->{CON}-10)/2);
	$modifs->{INT} = floor(($stats->{INT}-10)/2);
	$modifs->{WIS} = floor(($stats->{WIS}-10)/2);
	$modifs->{CHA} = floor(($stats->{CHA}-10)/2);

	$total = $stats->{STR}+$stats->{DEX}+$stats->{CON}+$stats->{INT}+$stats->{WIS}+$stats->{CHA};
	$total_modif = $modifs->{STR}+$modifs->{DEX}+$modifs->{CON}+$modifs->{INT}+$modifs->{WIS}+$modifs->{CHA};

	$msg = " STR: ".$stats->{STR}." (".format_modif($modifs->{STR}).")";
	$msg .= " DEX: ".$stats->{DEX}." (".format_modif($modifs->{DEX}).")";
	$msg .= " CON: ".$stats->{CON}." (".format_modif($modifs->{CON}).")";
	$msg .= " INT: ".$stats->{INT}." (".format_modif($modifs->{INT}).")";
	$msg .= " WIS: ".$stats->{WIS}." (".format_modif($modifs->{WIS}).")";
	$msg .= " CHA: ".$stats->{CHA}." (".format_modif($modifs->{CHA}).")";


	$ligne={ action=>"MSG",dest=>$dest,msg=>$nick.": ".$msg." - Total: ".$total." (".format_modif($total_modif).")"};
	push(@return,$ligne);
	return @return;
}

sub bot_4d6 {
	my($nick, $dest, $what)=@_;
	Giraf::Core::debug("bot_4d6()");
	my @return;
	my $stats={STR=>roll_4d6(),DEX=>roll_4d6(),CON=>roll_4d6(),INT=>roll_4d6(),WIS=>roll_4d6(),CHA=>roll_4d6()};
	my ($modifs,$total,$total_modif,$ligne,$msg);

	$modifs->{STR} = floor(($stats->{STR}-10)/2);
	$modifs->{DEX} = floor(($stats->{DEX}-10)/2);
	$modifs->{CON} = floor(($stats->{CON}-10)/2);
	$modifs->{INT} = floor(($stats->{INT}-10)/2);
	$modifs->{WIS} = floor(($stats->{WIS}-10)/2);
	$modifs->{CHA} = floor(($stats->{CHA}-10)/2);

	$total = $stats->{STR}+$stats->{DEX}+$stats->{CON}+$stats->{INT}+$stats->{WIS}+$stats->{CHA};
	$total_modif = $modifs->{STR}+$modifs->{DEX}+$modifs->{CON}+$modifs->{INT}+$modifs->{WIS}+$modifs->{CHA};

	$msg = " STR: ".$stats->{STR}." (".format_modif($modifs->{STR}).")";
	$msg .= " DEX: ".$stats->{DEX}." (".format_modif($modifs->{DEX}).")";
	$msg .= " CON: ".$stats->{CON}." (".format_modif($modifs->{CON}).")";
	$msg .= " INT: ".$stats->{INT}." (".format_modif($modifs->{INT}).")";
	$msg .= " WIS: ".$stats->{WIS}." (".format_modif($modifs->{WIS}).")";
	$msg .= " CHA: ".$stats->{CHA}." (".format_modif($modifs->{CHA}).")";


	push(@return,$ligne);
	return @return;
}



sub roll {
	my $ret=int(rand(6))+int(rand(6))+int(rand(6))+3;
	return $ret;
}

sub roll_4d6 {
	my @roll;
	@roll=(int(rand(6))+1,int(rand(6))+1,int(rand(6))+1,int(rand(6))+1);
	Giraf::Core::debug($roll[0].','.$roll[1].','.$roll[2].','.$roll[3]);
	my $ret=sum(@roll)-min(@roll);
	return $ret;
}

sub format_modif {
	my($nb)=@_;
	my $ret;
	if($nb >= 0) {
		$ret="+".$nb;
	}
	else {
		$ret=$nb;
	}
	return $ret;
}

1;
