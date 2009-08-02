#! /usr/bin/perl

$|=1;

package Giraf::Modules::LicheDice;

use strict;
use warnings;

use Giraf::Admin;

use POSIX qw(ceil floor);
use List::Util qw(sum);

our $version=1;

sub init {
	my ($kernel,$irc) = @_;
	Giraf::Trigger::register('public_function','LicheDice','bot_liche_dice',\&bot_liche_dice,'[Ll]iche');
	Giraf::Trigger::register('public_function','LicheDice','bot_liche_gygax',\&bot_liche_gygax,'[Ll]ich[Gg]ax');
}

sub unload {
	Giraf::Trigger::unregister('public_function','LicheDice','bot_liche_dice');
	Giraf::Trigger::unregister('public_function','LicheDice','bot_liche_gygax');
}

sub bot_liche_dice {
	my($nick, $dest, $what)=@_;
	Giraf::Core::debug("bot_liche_dice($what)");
	my @return;
	if($what=~/^(\d{1,4})[Dd](\d{1,8})$/)
	{
		my $nbroll=$1;
		my $nbface=$2;
		my @rolls;
		my ($roll,$message,$rollvalue,$ligne);
		$message = $nick." : ";
		for($roll=1;$roll<=$nbroll;$roll = $roll + 1) {
			$rollvalue=roll_dice($nbface);
			push(@rolls,$rollvalue);
			if($nbroll<20) {
				$message = $message.$rollvalue;
				if($roll<$nbroll) {
					$message = $message." ,";
				}
			}
		}
		if($nbroll>=20) {
			$message = $message." ".$nbroll."d".$nbface;
		}
		$message = $message. " - Total : ".sum(@rolls);
		$ligne={action=>"MSG",dest=>$dest,msg=>$message};
		push(@return,$ligne);
	}
	return @return;
}

sub bot_liche_gygax {
        my($nick, $dest, $what)=@_;
        Giraf::Core::debug("bot_liche_gygax()");
        my @return;
        my $stats={STR=>gygax_roll(),DEX=>gygax_roll(),CON=>gygax_roll(),INT=>gygax_roll(),WIS=>gygax_roll(),CHA=>gygax_roll()};
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

sub gygax_roll() {
	return roll_dice(6)+roll_dice(6)+roll_dice(6);
}

sub roll_dice {
	my($facenb) = @_;
	my $res;
	my $preliminaryroll=rand(100);
	if($preliminaryroll<20) {
		$res=1;
	}
	else {
		my $divisor = int(rand($facenb/2))+1;
		$res = int(rand($facenb)/$divisor)+1;
	}
	return $res;
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

