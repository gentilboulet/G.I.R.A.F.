#! /usr/bin/perl

$|=1;

package Giraf::Modules::LicheDice;

use strict;
use warnings;

use Giraf::Admin;

use List::Util qw(sum);

sub init {
	my ($kernel,$irc) = @_;
	Giraf::Trigger::register('public_function','LicheDice','bot_liche_dice',\&bot_liche_dice,'[Ll]iche');
}

sub unload {
	Giraf::Trigger::unregister('public_function','LicheDice','bot_liche_dice');
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

sub roll_dice {
	my($facenb) = @_;
	my $res;
	my $preliminaryroll=rand(100);
	if($preliminaryroll<20) {
		$res=1;
	}
	if(($preliminaryroll>=20) && ($preliminaryroll<40)) {
		$res=int(rand($facenb)/16)+1;
	}
	if(($preliminaryroll>=40) && ($preliminaryroll<60)) {
		$res=int(rand($facenb)/8)+1;
	}
	if(($preliminaryroll>=60) && ($preliminaryroll<80)) {
		$res=int(rand($facenb)/4)+1;
	}
	if(($preliminaryroll>=80) && ($preliminaryroll<90)) {
		$res=int(rand($facenb)/2)+1;
	}
	if($preliminaryroll>=90) {
		$res=int(rand($facenb))+1;
	}
	return $res;
}


1;

