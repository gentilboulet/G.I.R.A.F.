#! /usr/bin/perl
$|=1;

package Giraf::Modules::Dice;

use strict;
use warnings;

use Giraf::Admin;
use Giraf::Config;

our $version=1;

sub init {
	my ($kernel,$irc) = @_;
	Giraf::Trigger::register('public_function','Dice','dice_main',\&bot_roll_dice,'dice');
}

sub unload {
	Giraf::Trigger::unregister('public_function','Dice','dice_main');

}


sub bot_roll_dice {
	my($nick, $dest, $what)=@_;
	Giraf::Core::debug("bot_roll_dice($what)");
	my @return;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>roll($what,$nick)};
	push(@return,$ligne);
	return @return;
}

sub roll {
	my ($msg, $nick) = @_;
	$_ = $msg;
	my $ret;

	if(/^[1-9][0-9]*[d|D]\d+sr\d+[-|_]?$/i )
	{

		my $value;
		my $rnd;
		my $forloop;
		my $sides;
		my $lang;
		my @dice  = split(/ /,$_,2);
		my @dices = split(/[d|D]/,$_,2);
		my @sr = split(/sr/,$dices[1],2);
		my $relance=1;
		if($sr[1]=~/-/)
		{
			$relance=0;
		}
		
		if($sr[1]=~/_/)
		{	
			$relance=-1;
		}
		my $ligne;
		my $succes;
		my $echecs_critiques=0;
		my $retry=0;
		$dices[1]=$sr[0];
		if($nick)
		{
			$ret="$nick lance ".$msg.".....";
			$ligne="$nick obtient (";
		}
		else
		{
			$ligne="(";
		}
		if($dices[1] > 1)
		{
			if($dices[1] <= 100)
			{
				if($dices[0] < 26)
				{
					if($dices[0] < 1)
					{
						$dices[0] = 1;
					}
					for($forloop = 1; $forloop-$retry <= $dices[0]; $forloop++)
						{
						$rnd = int(rand($dices[1]));
						if($rnd == 0)
						{
							$rnd = $dices[1];
						}
						if($rnd == 1)
						{
							$rnd="[color=red]".$rnd."[/color]";
							if($relance>-1)
							{
								$echecs_critiques++;
							}	
						}
						else
						{
							if($rnd == $dices[1] && $relance==1)
							{
								$retry++;
							}
							if($rnd >= $sr[1])
							{
								if($rnd == $dice[1])
								{
									$rnd="[color=green][b]".$rnd."[/b][/color]";
								}
								else
								{	$rnd="[color=green]".$rnd."[/color]";
								}
								$succes++;
							}
						}
						if($forloop == 1)
						{
							$ligne="$ligne$rnd";
						}
						else
						{
							$ligne="$ligne $rnd";
						}
					}
					$ligne="$ligne)";
					if($succes==0 && $echecs_critiques>0)
					{
						$ligne="$ligne : Echec critique.";
					}elsif($succes==$echecs_critiques || $echecs_critiques>$succes)
					{
						$ligne="$ligne : 0 Succes.";
					}else
					{
						$ligne="$ligne : ".($succes-$echecs_critiques)." Succes.";
					}
					$ret=($ligne);
				}
				else
				{       if($nick)
					{
						$ret=("$nick veut prendre un bain de d".$dices[1]);
					}
				}
			}
			else
			{
				if($nick)
				{
					$ret=("$nick pense qu'un d".$dices[1]." n'a pas assez de faces");
				}
			}
		}
		else
		{
			if($dices[1] == "0")
			{
				if($nick)
				{
					$ret=("$nick invente le de sans face");
				}
			}
			if($dices[1] == "1")
			{
				if($nick)
				{
					$ret=("$nick joue aux billes");
				}
			}
		}
		return $ret;


	}
	elsif(/^[1-9]\d*[d|D]\d+([\+\-]\d+){0,1}$/i)
	{
		my $value;
		my $rnd;
		my $forloop;
		my $sides;
		my $lang;
		my @dice  = split(/ /,$_,2);
		my @dices = split(/[d|D]/,$_,2);
		my @plus = split(/[\+|\-]/,$dices[1],2);
		my $ligne;
		$dices[1]=$plus[0];
		if($nick)
		{
			$ligne="$nick lance ".$msg." et obtient (";
		}
		else
		{
			$ligne="(";
		}
		if($dices[1] > 1)
		{
			if($dices[1] <= 100)
			{
				if($dices[0] < 26)
				{
					if($dices[0] < 1)
					{
						$dices[0] = 1;
					}
					for($forloop = 1; $forloop <= $dices[0]; $forloop++)
					{
						$rnd = int(rand($dices[1]));
						if($rnd == 0)
						{
							$rnd = $dices[1];
						}
						$value = $value + $rnd;
						if($rnd == 1 )
						{
							$rnd="[color=red]".$rnd."[/color]";
						}
						else
						{
							if($rnd == $dices[1])
							{
								$rnd="[color=green]".$rnd."[/color]";
							}
						}
						if($forloop == 1)
						{
							$ligne="$ligne$rnd";
						}
						else
						{
							$ligne="$ligne+$rnd";
						}
					}
					if($plus[1]>0)
					{
						if($msg=~/\-/)
						{
							$value=$value-$plus[1];
							$ligne="$ligne)-".$plus[1]." = $value";
						}
						else
						{
							$value=$value+$plus[1];
							$ligne="$ligne)+".$plus[1]." = $value";
						}
					}
					else
					{
						$ligne="$ligne) = $value";
					}
					$ret=($ligne);
				}
				else
				{       if($nick)
					{
						$ret=("$nick veut prendre un bain de d".$dices[1]);
					}
				}
			}
			else
			{
				if($nick)
				{
					$ret=("$nick pense qu'un d".$dices[1]." n'a pas assez de faces");
				}
			}
		}
		else
		{
			if($dices[1] == "0")
			{
				if($nick)
				{
					$ret=("$nick invente le de sans face");
				}
			}
			if($dices[1] == "1")
			{
				if($nick)
				{
					$ret=("$nick joue aux billes");
				}
			}
		}
		return $ret;
	}
}


1;
