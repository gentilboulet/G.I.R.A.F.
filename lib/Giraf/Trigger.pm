#! /usr/bin/perl
$| = 1;

package Giraf::Trigger;

use strict;
use warnings;

use Giraf::Config;
use Giraf::Module;
use Giraf::Admin;

use DBI;
use Switch;

# Public vars

# Private vars
our $_kernel;
our $_irc;
our $_triggers;
our $_dbh;

our $_public_functions;
our $_private_functions;
our $_on_nick_functions;
our $_on_uuid_change_functions;
our $_on_join_functions;
our $_on_part_functions;
our $_on_quit_functions;
our $_on_kick_functions;
our $_public_parsers;
our $_private_parsers;

sub init {
	my ( $ker, $irc_session, $set_triggers) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;
	$_triggers=$set_triggers;

	Giraf::Core::_debug("Giraf::Trigger::init()",1);

}

#On event subroutines
sub on_part {
	my ( $nick, $channel ) = @_;

	Giraf::Core::_debug("Giraf::Trigger::on_part($nick,$channel)",3);

	my @return;
	foreach my $module_name (keys %$_on_part_functions)
	{
		my $module=$_on_part_functions->{$module_name};
		foreach my $func (keys %$module)
		{
			push(@return,$module->{$func}->{function}->($nick,$channel));
		}
	}
	return @return;
}

sub on_quit {
	my ( $nick, $message) = @_;

	Giraf::Core::_debug("Giraf::Trigger::on_quit($nick,$message)",3);

	my @return;
	foreach my $module_name (keys %$_on_quit_functions)
	{
		my $module=$_on_quit_functions->{$module_name};
		foreach my $func (keys %$module)
		{
			push(@return,$module->{$func}->{function}->($nick,$message));
		}
	}
	return @return;
}

sub on_nick {
	my ( $nick, $nick_new ) = @_;

	Giraf::Core::_debug("Giraf::Trigger::on_nick($nick,$nick_new)",3);

	my @return;
	foreach my $module_name (keys %$_on_nick_functions)
	{
		my $module=$_on_nick_functions->{$module_name};
		foreach my $func (keys %$module)
		{
			push(@return,$module->{$func}->{function}->($nick,$nick_new));

		}
	}
	return @return;
}

sub on_kick {
        my ( $kicked, $channel, $kicker, $reason ) = @_;

        Giraf::Core::_debug("Giraf::Trigger::on_kick($kicked, $channel, $kicker, $reason)",3);

        my @return;
        foreach my $module_name (keys %$_on_kick_functions)
	{
		my $module=$_on_kick_functions->{$module_name};
		if( Giraf::Admin::module_authorized($module_name,$channel) )
		{
			foreach my $func (keys %$module)
			{
				push(@return,$module->{$func}->{function}->($kicked,$channel,$kicker,$reason));

			}
		}
	}


	return @return;
}


sub on_uuid_change {
	my ( $uuid, $uuid_new ) = @_;

	Giraf::Core::_debug("Giraf::Trigger::on_uuid_change($uuid,$uuid_new)",3);

	my @return;
	foreach my $module_name (keys %$_on_uuid_change_functions)
	{
		my $module=$_on_uuid_change_functions->{$module_name};
		foreach my $func (keys %$module)
		{
			push(@return,$module->{$func}->{function}->($uuid,$uuid_new));

		}
	}
	return @return;
}


sub on_join {
	my ( $nick, $channel ) = @_;

	Giraf::Core::_debug("Giraf::Trigger::on_join($nick,$channel)",3);

	my @return;
	foreach my $module_name (keys %$_on_join_functions)
	{
		my $module=$_on_join_functions->{$module_name};
		if( Giraf::Admin::module_authorized($module_name,$channel))
		{
			foreach my $func (keys %$module)
			{
				push(@return,$module->{$func}->{function}->($nick,$channel));
			}
		}
	}

	return @return;
}

sub on_bot_quit {
	my ( $reason )=@_;
	my ($module,$module_name,$sth);

	Giraf::Core::set_quit();

	Giraf::Core::_debug("Giraf::Trigger::on_bot_quit($reason)",3);

	Giraf::Module::modules_on_quit();

	$_kernel->signal( $_kernel, 'POCOIRC_SHUTDOWN', $reason );

	return 0;

}

sub public_msg
{
	my ( $nick, $channel, $what )=@_;
	Giraf::Core::_debug("Giraf::Trigger::public_msg($nick,$channel,$what)",2);
	my @return;
	if(!Giraf::User::is_user_ignore($nick))
	{
		foreach my $module_name (keys %$_public_functions) 
		{
			my $module=$_public_functions->{$module_name};
			if( Giraf::Admin::module_authorized($module_name,$channel) )
			{
				foreach my $func (keys %$module)
				{
					my $element = $module->{$func};
					#First we check for triggers
					if( $what=~/^$_triggers(.*)$/ )
					{
						my $arg=$+;#the last matched part
						my $regex=$element->{regex};
						if ( $arg =~/^$regex\s*(.*?)$/ )
						{
							my $ref=\&{$element->{function}};
							push(@return,$ref->($nick,$channel,$+,$arg));
						}
					}
				}
			}
		}

		foreach my $module_name (keys %$_public_parsers)
		{
			my $module=$_public_parsers->{$module_name};
			if( Giraf::Admin::module_authorized($module_name,$channel) )
			{
				foreach my $func (keys %$module)
				{
					my $regex=$module->{$func}->{regex};
					if ($what =~/$regex/)
					{
						push(@return,$module->{$func}->{function}->($nick,$channel,$what));
					}
				}
			}
		}
	}
	return @return;
}

sub private_msg
{
	my ( $nick, $who, $where, $what )=@_;

	Giraf::Core::_debug("Giraf::Trigger::private_msg($nick,$who,$what,$where)",2);

	my @return;
	if(!Giraf::User::is_user_ignore($nick))
	{
		foreach my $key (keys %$_private_functions) 
		{
			my $module=$_private_functions->{$key};
			foreach my $func (keys %$module)
			{
				my $element = $module->{$func};
				#First we check for triggers
				if( $what=~/^$_triggers(.*)$/ )
				{
					my $arg=$+;#the last matched part
					my $regex=$element->{regex};
					if ($arg =~/^$regex\s*(.*?)$/)
					{
						my $ref=\&{$element->{function}};
						push(@return,$ref->($nick,$where,$+,$arg));
					}
				}
			}

		}
		foreach my $key (keys %$_private_parsers)
		{
			my $module=$_private_parsers->{$key};
			foreach my $func (keys %$module)
			{
				my $regex = $module->{$func}->{regex};
				if ($what =~/$regex/)
				{
					push(@return,$module->{$func}->{function}->($nick,$where,$what));
				}
			}
		}
	}
	return @return;
}

#Registration sub
sub register {
	my ($where_to_register,$module_name,$function_name,$function,$regex)=@_;

	Giraf::Core::_debug("Giraf::Trigger::register($where_to_register,$module_name,$function_name,$function)",1);

	if( $module_name eq 'core' || Giraf::Module::module_exists($module_name) )
	{
		switch($where_to_register) 
		{
			case 'public_function' 		{	$_public_functions->{$module_name}->{$function_name}={function=>$function,regex=>$regex};	}
			case 'public_parser' 		{	$_public_parsers->{$module_name}->{$function_name}={function=>$function,regex=>$regex};		}
			case 'on_nick_function' 	{	$_on_nick_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_kick_function' 	{	$_on_kick_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_uuid_change_function' 	{	$_on_uuid_change_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_join_function' 	{	$_on_join_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_part_function' 	{	$_on_part_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_quit_function' 	{	$_on_quit_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'private_function' 	{	$_private_functions->{$module_name}->{$function_name}={function=>\&$function,regex=>$regex};	}
			case 'private_parser'		{	$_private_parsers->{$module_name}->{$function_name}={function=>\&$function,regex=>$regex};	}
		}
	}
}

sub unregister {
	my ($where_to_register,$module_name,$function_name)=@_;

	Giraf::Core::_debug("Giraf::Trigger::unregister($where_to_register,$module_name,$function_name)",1);	

	if( $module_name eq 'core' || Giraf::Module::module_exists($module_name) )
	{

		switch($where_to_register)
		{
			case 'public_function'  	{	delete($_public_functions->{$module_name}->{$function_name});	}
			case 'public_parser'    	{	delete($_public_parsers->{$module_name}->{$function_name});	}
			case 'on_nick_function' 	{	delete($_on_nick_functions->{$module_name}->{$function_name});}
			case 'on_kick_function' 	{	delete($_on_kick_functions->{$module_name}->{$function_name});}
			case 'on_uuid_change_function' 	{	delete($_on_uuid_change_functions->{$module_name}->{$function_name});}
			case 'on_join_function' 	{	delete($_on_join_functions->{$module_name}->{$function_name}); }
			case 'on_part_function' 	{	delete($_on_part_functions->{$module_name}->{$function_name}); }
			case 'on_quit_function' 	{	delete($_on_quit_functions->{$module_name}->{$function_name}); }
			case 'private_function' 	{	delete($_private_functions->{$module_name}->{$function_name}); }
			case 'private_parser'  		{	delete($_private_parsers->{$module_name}->{$function_name});}
		}
	}
}

1;
