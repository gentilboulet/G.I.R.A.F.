#!/usr/bin/perl -w
$|=1;

package Giraf::Modules::CallVote;

use strict;
use warnings;

use List::Util qw[min max];
use POE;


our $kernel;

our $irc;
my $votes;



sub init {
	my ($ker,$irc_session) = @_;
	$kernel=$ker;
	$irc=$irc_session;
	$Admin::public_functions->{callvote_launch}={function=>\&callvote_launch,regex=>'callvote (.*) \?\s*( +[0-9]+)?'};
	$Admin::public_functions->{callvote_status}={function=>\&callvote_status,regex=>'callvote status'};
	$Admin::public_functions->{callvote_vote}={function=>\&callvote_vote,regex=>'[fF][12]([ ]*)'};
	$Admin::on_nick_functions->{callvote_nick}={function=>\&callvote_nick};
}

sub unload {
	delete($Admin::public_functions->{callvote_launch});
	delete($Admin::public_functions->{callvote_status});
	delete($Admin::public_functions->{callvote_vote});
	delete($Admin::on_nick_functions->{callvote_nick});
}

sub callvote_launch {
	my($nick, $dest, $what)=@_;
	my @return;
	$dest=lc $dest;
	if( $votes->{$dest}->{en_cours}==0)
	{
		my ($v)=$what=~/callvote\s+(\S.*?\S?)\s+\?/ ;
		my ($d)=$what=~/callvote\s+\S.*?\S?\s+\?\s+([0-9]+)?/;
		if($d)
		{
			if($d<15)
			{
				$d=15;
			}
			$votes->{$dest}->{delay}=min(300,$d);
		}
		else
		{
			$votes->{$dest}->{delay}=60;
		}
		$votes->{$dest}->{en_cours}=1;
		$votes->{$dest}->{question}="$v ?";
		$votes->{$dest}->{oui}=0;
		$votes->{$dest}->{non}=0;
		$votes->{$dest}->{delay_id}=0;
		$votes->{$dest}->{votants}={};
		$kernel->post(callvote_core=> callvote_start => $dest => $v);
	}
	else
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"Un vote est deja en cours !"};
		push(@return,$ligne);

	}
	return @return;
}

sub callvote_vote {
	my($nick, $dest, $what)=@_;
	my @return;
	$dest=lc $dest;
	if($votes->{$dest}->{en_cours}!=0) 
	{
		if($votes->{$dest}->{votants}->{$nick}==0)
		{
			if( $what=~/[fF](1)/ )
			{
				$votes->{$dest}->{oui}=$votes->{$dest}->{oui}+1;
				$votes->{$dest}->{votants}->{$nick}=1;
				$kernel->post(callvote_core=> callvote_update => $dest);
				my $ligne={ action =>"NOTICE",dest=>$nick,msg=>"Vote pris en compte ! deja ".($votes->{$dest}->{oui})." Oui"};
				push(@return,$ligne);
			}
			elsif($what=~/[fF](2)/)
			{
				$votes->{$dest}->{non}=$votes->{$dest}->{non}+1;
				$votes->{$dest}->{votants}->{$nick}=1;
				$kernel->post(callvote_core=> callvote_update => $dest);
				my $ligne={ action =>"NOTICE",dest=>$nick,msg=>"Vote pris en compte ! deja ".($votes->{$dest}->{non})." Non"};
				push(@return,$ligne);
			}
		}
		else 
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"$nick, vous avez deja vote !"};
			push(@return,$ligne);

		}
		$votes->{$dest}->{en_cours}=1,
	}
	else 
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"Pas de vote en cours sur $dest!"};
		push(@return,$ligne);


	}
	return @return;
}

sub callvote_status {
	my($nick, $dest, $what)=@_;
	my @return;
	$dest=lc $dest;
	if( $votes->{$dest}->{en_cours}!=0)
	{
		my $q=$votes->{$dest}->{question};
		my $oui=$votes->{$dest}->{oui};
		my $non=$votes->{$dest}->{non};
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$q [/c] Oui : $oui, Non: $non."};
		push(@return,$ligne);
		$votes->{$dest}->{en_cours}=1;
	}
	else
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"Pas de vote en cours sur $dest!"};
		push(@return,$ligne);

	}
	return @return;

}

sub callvote_nick {
	my ($nick,$nick_new)=@_;
	foreach my $k (keys(%$votes))
	{
		$votes->{$k}->{votants}->{$nick_new}=$votes->{$k}->{votants}->{$nick};
	}
	return;
}

#################################################################################################################
#################################################################################################################
##############		EVENT HANDLERS
#################################################################################################################
#################################################################################################################

sub callvote_init {
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
	$_[KERNEL]->alias_set('callvote_core');
	\&Giraf::debug("CallVote start !!");
}

sub callvote_stop {
	\&Giraf::debug("CallVote stopped !!!");
}

sub vote_update {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0 ];
	my $delay_id=$votes->{$dest}->{delay_id};
	$kernel->delay_adjust($delay_id,$votes->{$dest}->{delay});
}

sub vote_start {
	my ($kernel, $heap, $dest, $vote) = @_[ KERNEL, HEAP, ARG0 , ARG1];
	my @return;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>"callvote [c=teal]$vote ?[/c]"};
	push(@return,$ligne);
	Giraf::emit(@return);
	$votes->{$dest}->{delay_id}=$kernel->delay_set( callvote_end , $votes->{$dest}->{delay}, $dest);
}

sub vote_end {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0];
	my $vote=$votes->{$dest}->{question};
	my $oui=$votes->{$dest}->{oui};
	my $non=$votes->{$dest}->{non};

	$votes->{$dest}->{en_cours}=0;

	my @return;
	if( ($oui+$non)>1)
	{
		$votants="s";
	}
	if($oui==$non)
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$vote [/c] Peut-etre (egalite, ".($oui+$non)." votant$votants)"};
		push(@return,$ligne);
	}
	elsif($oui>$non)
	{
		my $ratio=sprintf("%.2f",(100*$oui/($oui+$non)));
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$vote [/c] Oui (".$ratio."% de ".($oui+$non)." votant$votants)"};
		push(@return,$ligne);
	}
	elsif($oui<$non)
	{
		my $ratio=sprintf("%.2f",(100*$non/($oui+$non)));
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$vote [/c] Non (".$ratio."% de ".($oui+$non)." votant$votants)"};
		push(@return,$ligne);
	}
	Giraf::emit(@return);
}

POE::Session->create(
	inline_states => {
		_start => \&CallVote::callvote_init,
		_stop => \&CallVote::callvote_stop,
		callvote_update => \&CallVote::vote_update,
		callvote_start => \&CallVote::vote_start,
		callvote_end => \&CallVote::vote_end,
	},
);


1;
