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
our $_on_join_functions;
our $_on_part_functions;
our $_on_quit_functions;
our $_public_parsers;
our $_private_parsers;

sub init {
	my ( $classe, $ker, $irc_session, $set_triggers) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;
	$_triggers=$set_triggers;

	Giraf::Core::debug("Giraf::Trigger::init()");

}

#On event subroutines
sub on_part {
	my ($classe, $nick, $channel ) = @_;
	my @return;
	foreach my $key (keys %$_on_part_functions)
	{
		my $module=$_on_part_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};
			push(@return,$element->{function}->($nick,$channel));
		}
	}
	return @return;
}

sub on_quit {
	my ($classe, $nick) = @_;
	my @return;
	foreach my $key (keys %$_on_quit_functions)
	{
		my $module=$_on_quit_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};

			push(@return,$element->{function}->($nick));
		}
	}

	return @return;
}

sub on_nick {
	my ($classe, $nick, $nick_new ) = @_;
	my @return;
	foreach my $key (keys %$_on_nick_functions)
	{
		my $module=$_on_nick_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};
			push(@return,$element->{function}->($nick,$nick_new));

		}
	}
	return @return;
}

sub on_join {
	my ($classe, $nick, $channel ) = @_;
	my @return;
	foreach my $key (keys %$_on_join_functions)
	{
		my $module=$_on_join_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};

			push(@return,$element->{function}->($nick,$channel));
		}
	}

	return @return;
}

sub on_bot_quit {
	my ($class,$reason)=@_;
	my ($module,$module_name,$sth);

	Giraf::Core::set_quit();
	Giraf::Core::debug("on_bot_quit($reason)");

	Giraf::Module::modules_on_quit();

	$_kernel->signal( $_kernel, 'POCOIRC_SHUTDOWN', $reason );
	
	return 0;

}

sub public_msg
{
	my ($classe, $nick, $channel, $what )=@_;
	my @return;

	foreach my $module_name (keys %$_public_functions) 
	{
		my $module=$_public_functions->{$module_name};
		if( Giraf::Admin::module_authorized($module_name,$channel) )
		{
			foreach my $func (keys %$module)
			{
				my $element = $module->{$func};
				#First we check for triggers
				if(my ($arg)=($what=~/^$_triggers(.*)$/))
				{
					my $regex=$element->{regex};
					if ($arg =~/^$regex$/)
					{
						my $ref=\&{$element->{function}};
						push(@return,$ref->($nick,$channel,$arg));
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
				my $element = $module->{$func};
				#First we check for triggers
				my $regex=$element->{regex};
				if ($what =~/$regex/)
				{
					my $ref=\&{$element->{function}};
					push(@return,$ref->($nick,$channel,$what));
				}
			}
		}
	}
	return @return;

}

sub private_msg
{
	my ($classe, $nick, $who, $where, $what )=@_;
	my @return;
	foreach my $key (keys %$_private_functions) 
	{
		my $module=$_private_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};
			#First we check for triggers
			if(my ($arg)=($what=~/^$_triggers(.*)$/))
			{
				my $regex=$element->{regex};
				if ($arg =~/^$regex$/)
				{
					push(@return,$element->{function}->($nick,$where,$arg));
				}
			}
		}

	}
	foreach my $key (keys %$_private_parsers)
	{
		my $module=$_private_parsers->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};

			my $regex=$element->{regex};
			if ($what =~/$regex/)
			{
				push(@return,$element->{function}->($nick,$where,$what));
			}
		}
	}
	return @return;
}

#Registration sub
sub register {
	my ($where_to_register,$module_name,$function_name,$function,$regex)=@_;

	Giraf::Core::debug("Giraf::Trigger::register($where_to_register,$module_name,$function_name,$function)");

	if( $module_name eq 'core' || Giraf::Module::module_exists($module_name) )
	{
		switch($where_to_register) 
		{
			case 'public_function' 	{	$_public_functions->{$module_name}->{$function_name}={function=>$function,regex=>$regex};	}
			case 'public_parser' 	{	$_public_parsers->{$module_name}->{$function_name}={function=>$function,regex=>$regex};		}
			case 'on_nick_function' {	$_on_nick_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_join_function' {	$_on_join_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_part_function' {	$_on_part_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'on_quit_function' {	$_on_quit_functions->{$module_name}->{$function_name}={function=>\&$function};			}
			case 'private_function' {	$_private_functions->{$module_name}->{$function_name}={function=>\&$function,regex=>$regex};	}
			case 'private_parser'	{	$_private_parsers->{$module_name}->{$function_name}={function=>\&$function,regex=>$regex};	}
		}
	}
}

sub unregister {
	my ($where_to_register,$module_name,$function_name)=@_;

	Giraf::Core::debug("Giraf::Module::unregister($where_to_register,$module_name,$function_name)");	

	if( $module_name eq 'core' || Giraf::Module::module_exists($module_name) )
	{

		switch($where_to_register)
		{
			case 'public_function'  {       delete($_public_functions->{$module_name}->{$function_name});	}
			case 'public_parser'    {       delete($_public_parsers->{$module_name}->{$function_name});	}
			case 'on_nick_function' {       delete($_on_nick_functions->{$module_name}->{$function_name});}
			case 'on_join_function' {           delete($_on_join_functions->{$module_name}->{$function_name}); }
			case 'on_part_function' {           delete($_on_part_functions->{$module_name}->{$function_name}); }
			case 'on_quit_function' {           delete($_on_quit_functions->{$module_name}->{$function_name}); }
			case 'private_function' {           delete($_private_functions->{$module_name}->{$function_name}); }
			case 'private_parser'  {            delete($_private_parsers->{$module_name}->{$function_name});}
		}
	}
}

1;
