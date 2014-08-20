#!/usr/bin/perl -w
$|=1;

package Giraf::Modules::CallVote;

use strict;
use warnings;

use Giraf::Trigger;
use Giraf::Session;

use List::Util qw[min max];
use POE;
use Switch;

our $version=1;
# Private vars
our $_votes;

sub init {
	my ($ker,$irc_session) = @_;

	Giraf::Core::debug("Giraf::Modules::CallVote::init()");

	Giraf::Trigger::register('public_function','CallVote','callvote_main',\&callvote_main,'callvote');
	Giraf::Trigger::register('public_function','CallVote','callvote_vote',\&callvote_vote,'[fF]');

	Giraf::Trigger::register('on_uuid_change_function','CallVote','callvote_uuid_change',\&callvote_uuid_change);

	Giraf::Session::init_session("callvote_core");
	start_session();
}

sub unload {

	Giraf::Core::debug("Giraf::Modules::CallVote::unload");

	Giraf::Trigger::unregister('public_function','CallVote','callvote_main');
	Giraf::Trigger::unregister('public_function','CallVote','callvote_vote');
	Giraf::Trigger::unregister('on_uuid_change_function','CallVote','callvote_uuid_change');


	Giraf::Session::post_event('callvote_core','callvote_end');
	foreach my $dest (keys(%$_votes))
	{
		Giraf::Session::call_event('callvote_core','vote_end',$dest);
		delete($_votes->{$dest});
	}
	Giraf::Session::shutdown_session("callvote_core");	
	$_votes={};
}

sub callvote_main {
	my ($nick,$dest,$args)=@_;
	my @return;
	
	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_main()");
	
	if( $args =~/status/ )
	{       push(@return,callvote_status($nick,$dest)); }
	else
	{       if($args) { push(@return,callvote_launch($nick,$dest,$args));} }

	return @return;
}

sub callvote_launch {
	my($nick, $dest, $what)=@_;
	my @return;
	$dest=lc $dest;
	
	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_launch($nick,$dest,$what)");
	
	if(! $_votes->{$dest}->{en_cours} )
	{
		my ($v)=$what=~/((\S+\s*)+)\s*\?/ ; #to detect a vote
		if( $v ne "")
		{
			$what=~/((\S+\s*)+)\s*\?\s+([0-9]+)?/; #To detect a delay
			my $d = $3;
	
			if($d)
			{
				if($d<15)
				{
					$d=15;
				}
				$_votes->{$dest}->{delay}=min(300,$d);
			}
			else
			{
				$_votes->{$dest}->{delay}=60;
			}
			$_votes->{$dest}->{en_cours}=1;
			$_votes->{$dest}->{question}="$v ?";
			$_votes->{$dest}->{oui}=0;
			$_votes->{$dest}->{non}=0;
			$_votes->{$dest}->{delay_id}=0;
			$_votes->{$dest}->{votants}={};
			$_votes->{$dest}->{start_ts}=time();
			Giraf::Session::post_event('callvote_core','vote_start', $dest, $v);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"Callvote : demande \"$what\" rejetee !"};
			delete( $_votes->{$dest} );
			push(@return,$ligne);
		}
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

	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_vote($nick,$dest,$what)");
	my $uuid=Giraf::User::getUUID($nick);

	if($_votes->{$dest}->{en_cours} && $what=~/[0-9]+/ ) 
	{
		if( ! $_votes->{$dest}->{votants}->{$uuid} )
		{
			if( $what=~/(1)/ )
			{
				$_votes->{$dest}->{oui}=$_votes->{$dest}->{oui}+1;
				$_votes->{$dest}->{votants}->{$uuid}=1;
				Giraf::Session::post_event('callvote_core','vote_update',$dest);
				my $ligne={ action =>"NOTICE",dest=>$nick,msg=>"Vote pris en compte ! deja ".($_votes->{$dest}->{oui})." Oui"};
				push(@return,$ligne);
			}
			elsif($what=~/(2)/)
			{
				$_votes->{$dest}->{non}=$_votes->{$dest}->{non}+1;
				$_votes->{$dest}->{votants}->{$uuid}=1;
				Giraf::Session::post_event('callvote_core','vote_update',$dest);
				my $ligne={ action =>"NOTICE",dest=>$nick,msg=>"Vote pris en compte ! deja ".($_votes->{$dest}->{non})." Non"};
				push(@return,$ligne);
			}
		}
		else 
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"$nick, vous avez deja vote !"};
			push(@return,$ligne);

		}
		$_votes->{$dest}->{en_cours}=1,
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

	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_status()");

	my @return;
	$dest=lc $dest;
	if( $_votes->{$dest}->{en_cours})
	{
		my $q=$_votes->{$dest}->{question};
		my $oui=$_votes->{$dest}->{oui};
		my $non=$_votes->{$dest}->{non};

		my $now = time();
		my $restant = ($_votes->{$dest}->{start_ts}+ $_votes->{$dest}->{delay}) - $now ;
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$q [/c] Oui : $oui, Non: $non. Temps restant $restant s."};
		push(@return,$ligne);
		$_votes->{$dest}->{en_cours}=1;
	}
	else
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"Pas de vote en cours sur $dest!"};
		push(@return,$ligne);

	}
	return @return;
}

sub callvote_uuid_change {
	my ($uuid,$uuid_new)=@_;

	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_uuid_change($uuid,$uuid_new)");

	foreach my $k (keys(%$_votes))
	{
		$_votes->{$k}->{votants}->{$uuid_new}=$_votes->{$k}->{votants}->{$uuid};
		delete($_votes->{$k}->{votants}->{$uuid});
	}
	return;
}

#################################################################################################################
#################################################################################################################
##############		EVENT HANDLERS
#################################################################################################################
#################################################################################################################

sub vote_update {
	my $dest = $_[ ARG0 ];

	Giraf::Core::debug("callvote_core::vote_update()");

	my $delay_id=$_votes->{$dest}->{delay_id};
	my $now=time();
	if( (($_votes->{$dest}->{start_ts}+ $_votes->{$dest}->{delay}) - $now ) < 15 )
	{
		Giraf::Session::adjust_delay_event('callvote_core',$delay_id,15);
	}
}

sub vote_start {
	my $dest = $_[ARG0];
	my $vote = $_[ARG1];
	
	Giraf::Core::debug("callvote_core::vote_start($vote,".$_votes->{$dest}->{delay}.")");
	
	my @return;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>"callvote [c=teal]$vote ?[/c]"};
	push(@return,$ligne);
	
	$_votes->{$dest}->{delay_id}=Giraf::Session::set_delay_event('callvote_core','vote_end', $_votes->{$dest}->{delay}, $dest);
	Giraf::Core::emit(@return);
}

sub vote_end {
	my $dest = $_[ ARG0];
	
	Giraf::Core::debug("callvote_core::vote_end()");
	
	my $vote=$_votes->{$dest}->{question};
	my $oui=$_votes->{$dest}->{oui};
	my $non=$_votes->{$dest}->{non};

	$_votes->{$dest}->{en_cours}=0;

	my @return;
	my $votants="";

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
	delete($_votes->{$dest});
	Giraf::Core::emit(@return);
}

sub start_session {
	Giraf::Core::debug("Giraf::Modules::CallVote::start_session()");
	Giraf::Session::add_event('callvote_core','vote_update',\&Giraf::Modules::CallVote::vote_update);
	Giraf::Session::add_event('callvote_core','vote_start',\&Giraf::Modules::CallVote::vote_start);
	Giraf::Session::add_event('callvote_core','vote_end',\&Giraf::Modules::CallVote::vote_end);
}

1;
