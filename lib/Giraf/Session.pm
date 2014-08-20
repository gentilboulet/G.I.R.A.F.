#! /usr/bin/perl
$| = 1;

package Giraf::Session;

use strict;
use warnings;

use Giraf::Config;
use Giraf::Admin;
use Giraf::Trigger;

use POE::Session;
use DBI;
use Switch;
use Data::Dumper;

# Private vars
our $_kernel;
our $_irc;
our $_dbh;
our $_tbl_modules = 'modules';
our $_tbl_users = 'users';
our $_tbl_config = 'config';
our $_sessions_hash;

sub init {
	my ( $ker, $irc_session ) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;

	Giraf::Core::debug("Giraf::Session::init()");

	Giraf::Trigger::register('public_function','core','bot_session_main',\&bot_session_main,'session');
}

#sessions s methods
sub bot_session_main {
	my ($nick,$dest,$what)=@_;
	
	Giraf::Core::debug("Giraf::Session::bot_session_main()");
	
	my @return;
	my ($sub_func,$args,@tmp);
	@tmp=split(/\s+/,$what);	
	$sub_func=shift(@tmp);
	$args="@tmp";
	
	Giraf::Core::debug("bot_session_main : sub_func=$sub_func ; args = $args");

	switch ($sub_func)
	{
		case 'list' 	{	push(@return,bot_list_session($nick,$dest,$args)); }
		case 'start' 	{	push(@return,bot_start_session($nick,$dest,$args)); }
		case 'shutdown'	{	push(@return,bot_shutdown_session($nick,$dest,$args)); }
	}

	return @return;
}

sub bot_list_session
{
	my ($nick,$dest)=@_;

	Giraf::Core::debug("Giraf::Session::bot_list_session");

	my @return;
	my $ligne;

	if(Giraf::Admin::is_user_admin($nick) )
	{
		my $size = keys (%$_sessions_hash);
		if( $size > 0 )
		{

			foreach my $session_alias (keys(%$_sessions_hash))
			{
				Giraf::Core::debug("Session $session_alias");
				if( $_sessions_hash->{$session_alias}->{started})
				{
					my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est [c=green]en cours[/c] !"};
					push(@return,$ligne);
				}
				else
				{
					my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est [c=red]stoppee[/c]!"};
					push(@return,$ligne);
				}
			}
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=yellow]Pas de session active pour l'instant[/c]!"};
			push(@return,$ligne);
		}

	}
	return @return;
}

sub bot_start_session
{
	my ($nick,$dest,$what)=@_;

	Giraf::Core::debug("Giraf::Session::bot_start_session");

	my @return;
	my $session_alias = $what ;
	
	if(Giraf::Admin::is_user_admin($nick) )
	{
		if($session_alias eq '')
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=red]Nom de session manquant !!! [/c] !"};
			push(@return,$ligne);
		}
		else
		{
			if( $_sessions_hash->{$session_alias}->{started})
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est deja [c=green]en cours[/c] !"};
				push(@return,$ligne);
			}
			else
			{
				init_session("$session_alias");
				my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est [c=green]lancee[/c] !"};
				push(@return,$ligne);
			}
		}
	}
	return @return;
}

sub bot_shutdown_session
{
	my ($nick,$dest,$what)=@_;

	Giraf::Core::debug("Giraf::Session::bot_start_session");

	my @return;
	my $ligne;
	my $session_alias = $what ;
	
	if(Giraf::Admin::is_user_admin($nick) )
	{
		if($session_alias eq '')
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=red]Nom de session manquant !!! [/c] !"};
			push(@return,$ligne);
		}
		else
		{
			if( $_sessions_hash->{$session_alias}->{started})
			{
				shutdown_session("$session_alias");
				my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est [c=red]arretee[/c] !"};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>"La session $session_alias est deja [c=yellow]arretee[/c] !"};
				push(@return,$ligne);
			}
		}
	}
	return @return;
}

sub init_session
{
	my ($session_alias)=@_;

	if(! $_sessions_hash->{$session_alias}->{started})
	{
		Giraf::Core::debug("Giraf::Session::init_session($session_alias)");
		my $session_id=POE::Session->create(
			inline_states => {
				_start => sub {
					$_[HEAP]->{alias}=$session_alias;
					$_[KERNEL]->alias_set($session_alias);
					Giraf::Core::debug("session $session_alias is started !!!"); 
				},
				_new_event => \&Giraf::Session::event_new_event,
				_del_event => \&Giraf::Session::event_del_event,
				_delay_event => \&Giraf::Session::event_delay_event,
				_alarm_event => \&Giraf::Session::event_alarm_event,
				_adjust_delay_event => \&Giraf::Session::event_adjust_delay_event,
				_adjust_alarm_event => \&Giraf::Session::event_adjust_alarm_event,
				_remove_timer_event => \&Giraf::Session::event_remove_tumer_event,
				_shutdown => \&Giraf::Session::event_session_shutdown,
				_stop => \&Giraf::Session::event_session_stop,
			},
			options => { trace => 1, debug => 1 }
		);
		$_sessions_hash->{$session_alias}->{started}=1;
		# temporary ; may be deleted in the future ; DO NOT USE !
		$_sessions_hash->{$session_alias}->{session_id}=$session_id;
	}
	return $_sessions_hash->{$session_alias}->{started} ;
}

sub shutdown_session
{
	my ($session_alias)=@_;
	if($_sessions_hash->{$session_alias}->{started})
	{
		Giraf::Core::debug("Giraf::Session::shutdown_session($session_alias)");
		post_event($session_alias, '_shutdown');		
		delete( $_sessions_hash->{$session_alias} )
	}
}

sub post_event
{
	my ($session_alias, $event_name, @args) = @_;
	Giraf::Core::debug("Giraf::Session::post_event($session_alias, $event_name, (@args) );");
	$_kernel->post($session_alias => $event_name => @args);
	return ;
}

sub call_event
{
	my ($session_alias, $event_name, @args) = @_;
	Giraf::Core::debug("Giraf::Session::call_event($session_alias, $event_name, (@args) );");
	return $_kernel->call($session_alias => $event_name => @args);
}

sub add_event
{
	#eval du code passé en parametres
	my ($session_alias, $event_name, $event_handler) = @_;
	Giraf::Core::debug("Giraf::Session::add_event($session_alias, $event_name, $event_handler)");
	call_event($session_alias, '_new_event', $event_name,$event_handler);		
}

sub rm_event
{
	my ($session_alias, $event_name) = @_;
	Giraf::Core::debug("Giraf::Session::rm_event($session_alias, $event_name)");
	call_event($session_alias, '_del_event', $event_name);
}

sub set_delay_event
{
	my ($session_alias, $event, $delay, @args) = @_;		
	Giraf::Core::debug("Giraf::Session:set_delay_event($event,$delay,(@args))");
	my $session = $_kernel->alias_resolve($session_alias);
	my $delay_id = call_event($session_alias, "_delay_event", ($event, $delay, @args));
	Giraf::Core::debug("Giraf::Session:set_delay_even(id=$delay_id)");
	return $delay_id;
}

sub set_alarm_event
{
	my ($session_alias, $event, $alarm, @args) = @_;		
	Giraf::Core::debug("Giraf::Session:set_alarm_event($event,$alarm,(@args))");
	my $session = $_kernel->alias_resolve($session_alias);
	my $alarm_id = call_event($session_alias, "_alarm_event", ($event, $alarm, @args));
	Giraf::Core::debug("Giraf::Session:set_alarm_even(id=$alarm_id)");
	return $alarm_id;
}

sub adjust_delay_event
{
	my ($session_alias, $delay_id, $new_delay) = @_;		
	Giraf::Core::debug("Giraf::Session:adjust_delay_event($delay_id,$new_delay)");
	my $session = $_kernel->alias_resolve($session_alias);
	call_event($session_alias, "_adjust_delay_event", ($delay_id, $new_delay));
}

sub adjust_alarm_event
{
	my ($session_alias, $alarm_id, $new_alarm) = @_;		
	Giraf::Core::debug("Giraf::Session:adjust_alarm_event($alarm_id,$new_alarm)");
	my $session = $_kernel->alias_resolve($session_alias);
	call_event($session_alias, "_adjust_alarm_event", ($alarm_id, $new_alarm));
}

sub remove_event_timer
{
	my ($session_alias, $timer_id) = @_;		
	Giraf::Core::debug("Giraf::Session::remove_event_timer($timer_id)");
	my $session = $_kernel->alias_resolve($session_alias);
	call_event($session_alias, "_remove_timer_event", ($timer_id));
}

###################################
##### Session Event
##################################
sub event_session_stop
{
	#mostly placehandler
	#this event does nothing except some debug
	my $alias=$_[HEAP]->{alias};
	Giraf::Core::debug("Event : session $alias is stopped !!!"); 
}

sub event_session_shutdown
{
	my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

	# delete all wheels.
	delete $heap->{wheel};

	# clear your alias
	$kernel->alias_remove($heap->{alias});

	# clear all alarms you might have set
	$kernel->alarm_remove_all();

	# get rid of external ref count
	$kernel->refcount_decrement($session, 'my ref name');

	# propagate the message to children
	$kernel->post($heap->{child_session}, '_shutdown');
	return;
}

sub event_new_event
{
	my $event_name = $_[ARG0];
	my $event_handler = $_[ARG1];
	my $alias=$_[HEAP]->{alias};
	$_[KERNEL]->state( $event_name => $event_handler );
	Giraf::Core::debug("Event from $alias :  new handler for $event_name : $event_handler !!!"); 
}

sub event_del_event
{
	my $event_name = $_[ARG0];
	my $alias=$_[HEAP]->{alias};
	$_[KERNEL]->state( $event_name  );
	Giraf::Core::debug("Event from $alias :  deleting event $event_name !!!"); 
}

sub event_delay_event
{
	my $alias=$_[HEAP]->{alias};
	my ($event_name, $delay, @args) = @_[ARG0..$#_];
	my $delay_id = $_[KERNEL]->delay_set($event_name, $delay, @args);
	Giraf::Core::debug("Event from $alias :  delay $event_name for $delay seconds (@args) !!!"); 
	return $delay_id;
}

sub event_alarm_event
{
	my $alias=$_[HEAP]->{alias};
	my ($event_name, $alarm, @args) = @_[ARG0..$#_];
	my $alarm_id = $_[KERNEL]->alarm_set($event_name, $alarm, @args);
	Giraf::Core::debug("Event from $alias :  alarm $event_name at $alarm EPOCH (@args) !!!"); 
	return $alarm_id;
}

sub event_adjust_delay_event
{
	my $alias=$_[HEAP]->{alias};
	my ($delay_id, $new_delay) = @_[ARG0..$#_];
	$_[KERNEL]->delay_adjust($delay_id,$new_delay);
	Giraf::Core::debug("Event from $alias :  delay update for ($delay_id) is $new_delay seconds !!!");
}

sub event_adjust_alarm_event
{
	my $alias=$_[HEAP]->{alias};
	my ($alarm_id, $new_alarm) = @_[ARG0..$#_];
	$_[KERNEL]->alarm_adjust($alarm_id,$new_alarm);
	Giraf::Core::debug("Event from $alias :  alarm at $new_alarm for ($alarm_id) !!!");
}

sub event_remove_timer_event
{
	my $alias=$_[HEAP]->{alias};
	my ($timer_id) = @_[ARG0..$#_];
	$_[KERNEL]->alarm_remove($timer_id);
	Giraf::Core::debug("Event from $alias :  timer ($timer_id) removed !!!");
}

1;
