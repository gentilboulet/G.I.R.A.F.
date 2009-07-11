#! /usr/bin/perl
$| = 1;

package Giraf::User;

use strict;
use warnings;

use Switch;
use Giraf::Admin;

use DBI;	

# Private vars
our $_dbh;
our $_mem_dbh;
our $_kernel;
our $_irc;
our $_botadmin_registered=0;

our $_tbl_users='users';
our $_tbl_nick_history='nick_history';

sub init {
	my ( $class, $ker, $irc_session) = @_;

	$_kernel  = $ker;
	$_irc     = $irc_session;

	$_dbh = Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_users (nick TEXT UNIQUE, hostmask TEXT, UUID TEXT PRIMARY KEY, privileges NUMERIC DEFAULT 0)");
	$_dbh->do("DROP TABLE $_tbl_nick_history");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_nick_history (nick TEXT PRIMARY KEY, last_seen NUMERIC, hostmask TEXT, UUID TEXT)");
	$_dbh->do("COMMIT;");

	Giraf::Trigger::register('on_nick_function','core','bot_on_nick_change',\&bot_on_nick_change);

}

sub bot_on_nick_change {
	my ($old_nick,$new_nick) = @_;
	my @return;
	my $infos=getDataFromNick($old_nick);
	history_add($new_nick,$infos->{hostmask},$infos->{uuid});
	return @return;
}

sub add_user_info {
	my ($class, $nick,$hostmask) = @_;
	Giraf::Core::debug("add_user_info($nick,$hostmask)");
	my $UUID=$nick.'{'.$hostmask.'}';
	history_add($nick,$hostmask,$UUID);
}

sub getDataFromNick {
	my ($nick)=@_;
	my ($sth,$return,$uuid,$hostmask,$uuid_priv);
	$sth=$_dbh->prepare("SELECT hostmask,UUID FROM $_tbl_nick_history WHERE nick LIKE ? ORDER BY last_seen DESC");
	$sth->bind_columns(\$hostmask,\$uuid);
	$sth->execute($nick);
	$sth->fetch();

	$sth=$_dbh->prepare("SELECT UUID FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ?");
	$sth->bind_columns(\$uuid_priv);
	$sth->execute($nick,$hostmask);
	$sth->fetch();
	if($uuid_priv)
	{
		$uuid=$uuid_priv;	
	}
	Giraf::Core::debug("getDataFromNick($nick)={uuid=>$uuid,hostmask=>$hostmask}");
	$return={nick=>$nick,uuid=>$uuid,hostmask=>$hostmask};
	return $return;
}

sub getUUID {
	my ($nick)=@_;
	my $info=getDataFromNick($nick);
	return $info->{uuid};
}

sub history_add {
	my ($nick,$hostmask,$UUID) = @_;
	Giraf::Core::debug("history_add($nick,$hostmask,$UUID)");
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_nick_history (nick,last_seen,UUID,hostmask) VALUES (?,?,?,?)");
	$sth->execute($nick,time(),$UUID,$hostmask);
	if(!$_botadmin_registered && $nick eq Giraf::Config::get('botadmin'))
	{
		register_botadmin($nick,$hostmask,$UUID);
		$_botadmin_registered=1;
	}
}

sub register_botadmin {
	my ($nick,$hostmask,$UUID) = @_;
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_users (nick,hostmask,UUID,privileges) VALUES (?,?,?,100000)");
	$sth->execute($nick,$hostmask,$UUID);
}

sub user_register {
	my ($class,$nick) = @_;
	my ($UUID,$sth);
	my $data=getDataFromNick($nick);
	$UUID=$nick.'{'.$data->{hostmask}.'}';
	$sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_users (nick,hostmask,UUID) VALUES (?,?,?)");
	$sth->execute($nick,$data->{hostmask},$data->{uuid});
	return 1;
}

sub user_unregister {
	my ($class,$nick) = @_;
	my ($UUID,$sth);
	$UUID=getUUID($nick);
	$sth=$_dbh->prepare("DELETE FROM $_tbl_users WHERE UUID LIKE ?");
	$sth->execute($UUID);
	return 1;
}

sub is_user_auth {
        my ($username,$level) = @_;
	my $data=getDataFromNick($username);
	my ($count_nickhost,$count_uuid);
	
	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ? AND privileges >= ?");
	$sth->bind_columns( \$count_nickhost);
	$sth->execute($username,$data->{hostmask},$level);
	$sth->fetch();

	$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE UUID LIKE ? AND privileges >= ?");
	$sth->bind_columns( \$count_uuid);
	$sth->execute($data->{uuid},$level);
	$sth->fetch();
	return (($count_nickhost > 0) || ($_botadmin_registered*$count_uuid>0));
}

sub DESTROY {
	Giraf::Core::debug("il a cassé mon user !");
}

1;
