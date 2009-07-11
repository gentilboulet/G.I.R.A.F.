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
	my ( $class, $ker, $irc_session) = @_;

	$_kernel  = $ker;
	$_irc     = $irc_session;

	$_dbh=Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_chans (name TEXT PRIMARY KEY, autorejoin NUMERIC, joined NUMERIC)");
	$_dbh->do("COMMIT;");


}

sub join {
	my ( $class, $chan ) = @_;
	Giraf::Core::debug("Chan->join($chan)");
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,1)");	
	$sth->execute($chan);
#	Giraf::Core::debug("Join _irc =$_irc ; _kernel =$_kernel");
	$_kernel->post( $_irc => join => $chan );
	$_kernel->post( $_irc => who => $chan );
}

sub autorejoin {
	my ( $class, $chan, $autorejoin ) = @_;
	my $sth=$_dbh->prepare("UPDATE $_tbl_chans SET autorejoin=? WHERE name LIKE ?");
	$sth->execute($autorejoin,$chan);

}

sub part {
	my ( $class, $chan, $reason) = @_;
#	Giraf::Core::debug("Chan->part($chan,$reason)");
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_chans (name,joined) VALUES (?,0)");
	$sth->execute($chan);
	Giraf::Core::debug("Part _irc =$_irc ; _kernel =$_kernel");
	$_kernel->post( $_irc => part => $chan => $reason );
}

sub known_chan {
        my ($chan) = @_;

	my $count;
        my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_chans WHERE name LIKE ?");
        $sth->bind_columns(\$count);
        $sth->execute($chan);
        $sth->fetch();
        return $count;
}

sub DESTROY {
	Giraf::Core::debug("il a cassé mon chan !");
}

1;
