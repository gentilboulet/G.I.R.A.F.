#! /usr/bin/perl
$| = 1;

package Giraf::User;

use strict;
use warnings;

use Giraf::Admin;

use DBI;	

# Private vars
our $_dbh;
our $_kernel;
our $_irc;

our $_tbl_users='users';

sub init {
	my ( $class, $ker, $irc_session) = @_;

	$_kernel  = $ker;
	$_irc     = $irc_session;

	$_dbh = Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_users (name TEXT PRIMARY KEY, )");
	$_dbh->do("COMMIT;");


}

sub DESTROY {
	Giraf::Core::debug("il a cassé mon chan !");
}

1;
