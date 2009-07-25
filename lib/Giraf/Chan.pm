#! /usr/bin/perl
$| = 1;

package Giraf::Chan;

use Giraf::Core;

use strict;
use warnings;

use DBI;	

# Private vars
our $_dbh;
our $_kernel;
our $_irc;

our $_tbl_chans='chans';

sub init {
	my ( $ker, $irc_session) = @_;

	$_kernel  = $ker;
	$_irc     = $irc_session;

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
}

sub join {
	my ( $chan ) = @_;
	if(!is_chan_joined($chan))
	{
		Giraf::Core::debug("Chan::join($chan)");
		my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,1)");	
		$sth->execute($chan);
		$_kernel->post( $_irc => join => $chan );
		$_kernel->post( $_irc => who => $chan );
	}
}

sub autorejoin {
	my ( $chan, $autorejoin ) = @_;
	my $sth=$_dbh->prepare("UPDATE $_tbl_chans SET autorejoin=? WHERE name LIKE ?");
	$sth->execute($autorejoin,$chan);

}

sub part {
	my ( $chan, $reason) = @_;
	Giraf::Core::debug("Chan->part($chan,$reason)");
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,0)");
	$sth->execute($chan);
	Giraf::Core::debug("Part _irc =$_irc ; _kernel =$_kernel");
	$_kernel->post( $_irc => part => $chan => $reason );
}

sub known_chan {
	my ($chan) = @_;
	my ($count,$sth);
	$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_chans WHERE name LIKE ?");
	$sth->bind_columns(\$count);
	$sth->execute($chan);
	$sth->fetch();
	return $count;
}

sub is_chan_joined {
	my ($chan) = @_;
	my ($joined,$sth);
	$sth=$_dbh->prepare("SELECT joined FROM $_tbl_chans WHERE name LIKE ?");
	$sth->bind_columns(\$joined);
	$sth->execute($chan);
	$sth->fetch();
	return $joined;
}

1;
