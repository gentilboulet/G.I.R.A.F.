#! /usr/bin/perl
$| = 1;

package Giraf::Chan;

use Giraf::Core;
use Giraf::Session;

use strict;
use warnings;

use DBI;
use POE;

# Private vars
our $_dbh;
our $_kernel;
our $_irc;

our $_tbl_chans='chans';

sub init {
	my ( $ker, $irc_session) = @_;

	$_kernel  = $ker;
	$_irc     = $irc_session;

	Giraf::Core::debug("Giraf::Chan::init()");

	$_dbh=Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_chans (name TEXT PRIMARY KEY, autorejoin NUMERIC DEFAULT 0, joined NUMERIC)");
	$_dbh->do("UPDATE $_tbl_chans SET joined=0");
	$_dbh->do("COMMIT;");
	
	my ($sth,$chan);
	$sth=$_dbh->prepare("SELECT name FROM $_tbl_chans WHERE autorejoin > 0");
	$sth->bind_columns(\$chan);
	$sth->execute();
	while($sth->fetch())
	{
		Giraf::Chan::join($chan);
	}

	Giraf::Trigger::register('on_kick_function','core','bot_on_kick',\&bot_on_kick);
	Giraf::Session::init_session('chan_core');
	start_session();
}

sub join {
	my ( $chan ) = @_;

	Giraf::Core::debug("Giraf::Chan::join($chan)");

	if(!is_chan_joined($chan))
	{
		my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,1)");	
		$sth->execute($chan);
		#Giraf::Session::post_event('irc_core','join',$chan);
		#Giraf::Session::post_event('irc_core','who',$chan);
		$_kernel->post( $_irc => join => $chan);
		$_kernel->post( $_irc => who  => $chan);
	}
}

sub autorejoin {
	my ( $chan, $autorejoin ) = @_;
	Giraf::Core::debug("Giraf::Chan::autorejoin($chan,$autorejoin)");
	my $sth=$_dbh->prepare("UPDATE $_tbl_chans SET autorejoin=? WHERE name LIKE ?");
	$sth->execute($autorejoin,$chan);

}

sub part {
	my ( $chan, $reason) = @_;
	Giraf::Core::debug("Giraf::Chan::part($chan,$reason)");
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,0)");
	$sth->execute($chan);
	Giraf::Core::debug("Part _irc =$_irc ; _kernel =$_kernel");
	$_kernel->post( $_irc => part => $chan => $reason );
	#Giraf::Session::post_event('irc_core','part',($chan,$reason));
}

sub is_chan_known {
	my ($chan) = @_;
	Giraf::Core::debug("Giraf::Chan::is_chan_known($chan)");
	my ($count,$sth);
	$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_chans WHERE name LIKE ?");
	$sth->bind_columns(\$count);
	$sth->execute($chan);
	$sth->fetch();
	return $count;
}

sub is_chan_joined {
	my ($chan) = @_;
	Giraf::Core::debug("Giraf::Chan::is_chan_joined($chan)");
	my ($joined,$sth);
	$sth=$_dbh->prepare("SELECT joined FROM $_tbl_chans WHERE name LIKE ?");
	$sth->bind_columns(\$joined);
	$sth->execute($chan);
	$sth->fetch();
	return $joined;
}

################################"
sub bot_on_kick {
	my ($kicked, $chan, $kicker, $reason) = @_;
	my @return;
	Giraf::Core::debug("Giraf::Chan::bot_on_kick($kicked, $chan, $kicker, $reason)");
	if($kicked eq $Giraf::Core::botname)
	{
		Giraf::Core::debug("Giraf::Chan::bot_on_kick()");
		my ($sth,$autorejoin);
		
		$sth=$_dbh->prepare("UPDATE $_tbl_chans SET joined = 0 WHERE name LIKE ?");
		$sth->execute($chan);
		
		$sth=$_dbh->prepare("SELECT autorejoin FROM $_tbl_chans WHERE name LIKE ?");
		$sth->bind_columns(\$autorejoin);
		$sth->execute($chan);
		$sth->fetch();

		if($autorejoin) 
		{
			Giraf::Session::post_event('chan_core','launch_delayed_join',$chan);
		}
	}
	return @return;
}

#################################
# Session management subs !	#
#################################
sub launch_delayed_join {
	my ($chan) = @_[ KERNEL, HEAP, ARG0 ];
	Giraf::Core::debug("chan_core::launch_delayed_join($chan)");
	Giraf::Session::set_delay_event('chan_core','delayed_join',61, $chan);
}

sub delayed_join {
	my ($chan) = @_[ KERNEL, HEAP, ARG0 ];
	Giraf::Core::debug("chan_core::delayed_join($chan)");
	Giraf::Chan::join($chan);
	if(!is_chan_joined($chan))
	{
		Giraf::Session::set_delay_event('chan_core','delayed_join',61, $chan);
	}
}

sub start_session {
	Giraf::Core::debug("Giraf::Chan::start_session()");
	Giraf::Session::add_event('chan_core','launch_delayed_join',\&Giraf::Chan::launch_delayed_join);
	Giraf::Session::add_event('chan_core','delayed_join',\&Giraf::Chan::delayed_join);
}
1;
