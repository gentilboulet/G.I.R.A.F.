#!/usr/bin/perl -w
$|=1;

package Giraf::Modules::CallVote;

use strict;
use warnings;

use Giraf::Trigger;

use List::Util qw[min max];
use POE;
use Switch;

our $version=1;
# Private vars
our $_kernel;
our $_votes;
our $_session_started=0;

sub init {
	my ($ker,$irc_session) = @_;
	$_kernel=$ker;

	Giraf::Core::debug("Giraf::Modules::CallVote::init()");

	Giraf::Trigger::register('public_function','CallVote','callvote_main',\&callvote_main,'callvote');
	Giraf::Trigger::register('public_function','CallVote','callvote_vote',\&callvote_vote,'[fF]');

	Giraf::Trigger::register('on_uuid_change_function','CallVote','callvote_uuid_change',\&callvote_uuid_change);

	start_session();
}

sub unload {

	Giraf::Core::debug("Giraf::Modules::CallVote::unload");

	Giraf::Trigger::unregister('public_function','CallVote','callvote_main');
	Giraf::Trigger::unregister('public_function','CallVote','callvote_vote');
	Giraf::Trigger::unregister('on_uuid_change_function','CallVote','callvote_uuid_change');
	
	$_kernel->post(callvote_core=>vote_cleanup=>());
}

sub callvote_main {
	my ($nick,$dest,$what)=@_;
	my @return;
	
	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_main()");
	
	my ($sub_func,$args);
	$what=~m/((.+?)\??)(\s+[0-9]+)?\s*$/;#To remove ending '?' to catch sub funcs
	$sub_func=$2;
	if($1 ne $2) { $args=$what;  }


	switch ($sub_func)
	{
		case 'status'  	{       push(@return,callvote_status($nick,$dest)); }
		else		{       if($args) { push(@return,callvote_launch($nick,$dest,$args));} }
	}

	return @return;

}

sub callvote_launch {
	my($nick, $dest, $what)=@_;
	my @return;
	$dest=lc $dest;
	
	Giraf::Core::debug("Giraf::Modules::CallVote::callvote_launch($nick,$dest,$what)");
	
	if(! $_votes->{$dest}->{en_cours} )
	{
		my ($v)=$what=~/(\S.*?\S?)\s+\?/ ; #to detect a vote
		my ($d)=$what=~/\S.*?\S?\s+\?\s+([0-9]+)?/; #To detect a delay
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
		$_kernel->post(callvote_core=> vote_start => $dest => $v);
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

	if($_votes->{$dest}->{en_cours} && $what=~/[12]/ ) 
	{
		if( ! $_votes->{$dest}->{votants}->{$uuid} )
		{
			if( $what=~/(1)/ )
			{
				$_votes->{$dest}->{oui}=$_votes->{$dest}->{oui}+1;
				$_votes->{$dest}->{votants}->{$uuid}=1;
				$_kernel->post(callvote_core=> vote_update => $dest);
				my $ligne={ action =>"NOTICE",dest=>$nick,msg=>"Vote pris en compte ! deja ".($_votes->{$dest}->{oui})." Oui"};
				push(@return,$ligne);
			}
			elsif($what=~/(2)/)
			{
				$_votes->{$dest}->{non}=$_votes->{$dest}->{non}+1;
				$_votes->{$dest}->{votants}->{$uuid}=1;
				$_kernel->post(callvote_core=> vote_update => $dest);
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
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=teal]$q [/c] Oui : $oui, Non: $non."};
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
	Giraf::Core::debug("callvote_core::_start()");
}

sub callvote_stop {
	Giraf::Core::debug("callvote_core::_stop()");
}

sub vote_update {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0 ];

	Giraf::Core::debug("callvote_core::vote_update()");

	my $delay_id=$_votes->{$dest}->{delay_id};
	my $now=time();
	if( (($_votes->{$dest}->{start_ts}+ $_votes->{$dest}->{delay}) - $now ) < 15 )
	{
		$kernel->delay_adjust($delay_id,15);
	}
}

sub vote_start {
	my ($kernel, $heap, $dest, $vote) = @_[ KERNEL, HEAP, ARG0 , ARG1];
	
	Giraf::Core::debug("callvote_core::vote_start($vote,".$_votes->{$dest}->{delay}.")");
	
	my @return;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>"callvote [c=teal]$vote ?[/c]"};
	push(@return,$ligne);
	
	Giraf::Core::emit(@return);
	
	$_votes->{$dest}->{delay_id}=$kernel->delay_set( 'vote_end' , $_votes->{$dest}->{delay}, $dest);
}

sub vote_end {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0];
	
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

sub vote_cleanup {
	my ($k, $h) = @_[ KERNEL, HEAP];
	Giraf::Core::debug("callvote_core::vote_cleanup()");
	foreach my $chan (keys %{$_votes})
	{
		if($_votes->{$chan}->{en_cours})
		{
			$k->post(callvote_core => vote_end=>$chan);
			$k->alarm_remove($_votes->{$chan}->{delay_id});
		}
	}
	$k->post(vote_clean_events => ());
}

sub clean_events {
	my ($k, $h) = @_[ KERNEL, HEAP];
	Giraf::Core::debug("callvote_core::clean_events()");
	$k->state('vote_start');
	$k->state('vote_end');
	$k->state('vote_update');
	$k->state('vote_cleanup');
	$k->state('vote_clean_events');
}

sub new_events {
	my ($k, $h) = @_[ KERNEL, HEAP];
	Giraf::Core::debug("callvote_core::new_events()");
	$k->state('_start', \&Giraf::Modules::CallVote::callvote_init);
	$k->state('_stop', \&Giraf::Modules::CallVote::callvote_stop);

	$k->state('vote_update',\&Giraf::Modules::CallVote::vote_update);
	$k->state('vote_start',\&Giraf::Modules::CallVote::vote_start);
	$k->state('vote_end',\&Giraf::Modules::CallVote::vote_end);

	$k->state('vote_cleanup', \&Giraf::Modules::CallVote::vote_cleanup);	
	$k->state('vote_clean_events', \&Giraf::Modules::CallVote::clean_events);	
	$k->state('vote_new_events',\&Giraf::Modules::CallVote::new_events);
}

sub start_session {
	Giraf::Core::debug("Giraf::Modules::CallVote::start_session()");
	$_kernel->post(callvote_core=>vote_new_events=>());
	if(!$_session_started)
	{
		$_session_started=1;
		POE::Session->create(
			inline_states => {
				_start => \&Giraf::Modules::CallVote::callvote_init,
				_stop => \&Giraf::Modules::CallVote::callvote_stop,
				vote_update => \&Giraf::Modules::CallVote::vote_update,
				vote_start => \&Giraf::Modules::CallVote::vote_start,
				vote_end => \&Giraf::Modules::CallVote::vote_end,

				vote_cleanup => \&Giraf::Modules::CallVote::vote_cleanup,
				vote_clean_events => \&Giraf::Modules::CallVote::clean_events,
				vote_new_events => \&Giraf::Modules::CallVote::new_events,
			},

		);
	}
}

1;
