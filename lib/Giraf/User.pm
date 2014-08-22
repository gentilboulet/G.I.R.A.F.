#! /usr/bin/perl
$| = 1;

package Giraf::User;

use strict;
use warnings;

use Switch;
use Giraf::Admin;
use Digest::MD5 qw(md5_hex);

use DBI;	

# Private vars
our $_dbh;
our $_mem_dbh;
our $_botadmin_registered=0;

our $_tbl_users='users';
our $_tbl_nick_history='nick_history';
our $_tbl_ignores='ignores';

sub init {
	my ($sth,$uuid);

	$_dbh = Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_users (nick TEXT, hostmask TEXT, UUID TEXT, privileges NUMERIC DEFAULT 0,password_hash TEXT,linkkey TEXT, UNIQUE(nick,hostmask))");
	$_dbh->do("DROP TABLE $_tbl_nick_history");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_nick_history (nick TEXT PRIMARY KEY, last_seen NUMERIC, hostmask TEXT, UUID TEXT)");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_ignores (UUID TEXT PRIMARY KEY, permanent NUMERIC)");
	$_dbh->do("DELETE FROM $_tbl_ignores WHERE permanent = 0");
	$_dbh->do("COMMIT;");
	
	Giraf::Core::_debug("Giraf::User::init()",1);

	Giraf::Trigger::register('on_nick_function','core','bot_on_nick_change',\&bot_on_nick_change);
	Giraf::Trigger::register('on_uuid_change_function','core','bot_on_uuid_change',\&bot_on_uuid_change);
	Giraf::Trigger::register('private_function','core','bot_user_main',\&bot_user_main,'user');
}


sub bot_user_main {
        my ($nick,$who,$what)=@_;

        Giraf::Core::_debug("Giraf::User::bot_user_main()",1);

        my @return;
        my ($sub_func,$args,@tmp);
        @tmp=split(/\s+/,$what);
        $sub_func=shift(@tmp);
        $args="@tmp";

        Giraf::Core::_debug("user main : sub_func=$sub_func",2);

        switch ($sub_func)
        {
                case 'link' 	{       push(@return,bot_link_user($nick,$args));     	}
                case 'linkkey'  {       push(@return,bot_linkkey_user($nick,$args));      }
                case 'identify' {       push(@return,bot_identify_user($nick,$args));     }
                case 'password' {       push(@return,bot_password_user($nick,$args));  	}
        }

        return @return;
}

sub bot_link_user {
	my ($nick,$what)=@_;
	Giraf::Core::_debug("Giraf::User::bot_link_user()",2);
	my @return;
	my $ligne;

	if(is_user_registered($nick))
	{
		my @tmp=split(/\s+/,$what);
		my $user=shift(@tmp);
		my $host=shift(@tmp);
		my $key=shift(@tmp);
		my $data=getDataFromNick($nick);
		my $sth=$_dbh->prepare("SELECT COUNT(*),uuid,privileges FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ? AND linkkey LIKE ?");
		my ($count,$uuid,$privileges);
		$sth->bind_columns(\$count,\$uuid,\$privileges);
		$sth->execute($user,$host,$key);
		$sth->fetch();
		if($count>0)
		{
			$sth=$_dbh->prepare("UPDATE $_tbl_users SET UUID=?,privileges=? WHERE nick LIKE ? AND hostmask LIKE ? AND UUID LIKE ?");
			if($sth->execute($uuid,$privileges,$data->{nick},$data->{hostmask},$data->{uuid}))
			{
				$ligne={action => "PRIVMSG",dest=>$nick,msg=>'Votre compte a bien été lié avec le compte '.$user.'@'.$host};
				$sth=$_dbh->prepare("UPDATE $_tbl_users SET linkkey='' WHERE UUID LIKE ?");
				$sth->execute($uuid);
				Giraf::Core::emit(Giraf::Trigger::on_uuid_change($data->{uuid},$uuid));
			}
			else
			{
				$ligne={action => "PRIVMSG",dest=>$nick,msg=>'Impossible de se lier avec le compte '.$user.'@'.$host};
			}
		}
		else
		{
			$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Impossible de se lier avec le compte '.$user.'@'.$host};
		}
	}
	else
	{
		$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Votre devez d\'abord etre enregitré !'};
	}

	push(@return,$ligne);
	return @return;
}

sub bot_linkkey_user {
	my ($nick,$what)=@_;
	Giraf::Core::_debug("Giraf::User::bot_linkkey_user()",2);
	my @return;
	my $ligne;

	if(is_user_registered($nick))
	{
		my @chars=('a'..'z','A'..'Z','0'..'9','_','$','!','@');
		my $key="";
		foreach(1..12)
		{
			$key=$key.$chars[rand @chars];
		}
		my $uuid=getUUID($nick);
		my $sth=$_dbh->prepare("UPDATE $_tbl_users SET linkkey=? WHERE nick LIKE ? AND UUID LIKE ?");
		if($sth->execute($key,$nick,$uuid) > 0)
		{
			$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Votre linkkey est [c=red]'.$key.'[/c] pour le prochain link'};
		}
		else
		{
			$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Impossible de generer une linkkey ? bug !'};
		}
	}
	else	
	{
			$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Votre devez d\'abord etre enregitré !'};
	}
	push(@return,$ligne);
	return @return;
}

sub bot_password_user {
	my ($nick,$what)=@_;
	Giraf::Core::_debug("Giraf::User::bot_password_user()",2);
	my @return;
	my $ligne;

	if(is_user_registered($nick))
	{
		my $uuid=getUUID($nick);
		my @tmp=split(/\s+/,$what);
		my $pass=shift(@tmp);
		my $hash=md5_hex($pass);
		my $sth=$_dbh->prepare("UPDATE $_tbl_users SET password_hash=? WHERE UUID LIKE ?");
		if($sth->execute($hash,$uuid)>0)
		{
			$ligne={ action => "PRIVMSG",dest=>$nick,msg=>'Le hash [c=red]'.$hash.'[/c] de votre password ('.$pass.') a bien ete enregistre !'};
		}
		else
		{
			$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Impossible de rajouter le password pour votre user ? bug !'};
		}
	}
	else
	{
		$ligne={ action =>"PRIVMSG",dest=>$nick,msg=>'Votre devez d\'abord etre enregitré !'};
	}

	push(@return,$ligne);
	return @return;
}

sub bot_identify_user {
	my ($nick,$what)=@_;
	Giraf::Core::_debug("Giraf::User::bot_identify_user()",2);
	my @return;
	my $ligne;

	my @tmp=split(/\s+/,$what);
	my $user=shift(@tmp);
	my $host=shift(@tmp);
	my $pass=shift(@tmp);
	my $hash=md5_hex($pass);
	my $data=getDataFromNick($nick);
	my $sth=$_dbh->prepare("SELECT COUNT(*),uuid FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ? AND password_hash LIKE ?");
	my ($count,$uuid);
	$sth->bind_columns(\$count,\$uuid);
	$sth->execute($user,$host,$hash);
	$sth->fetch();
	if($count>0)
	{
		$sth=$_dbh->prepare("UPDATE $_tbl_nick_history SET UUID=? WHERE UUID LIKE ?");
		$sth->execute($uuid,$data->{uuid});
		Giraf::Core::emit(Giraf::Trigger::on_uuid_change($data->{uuid},$uuid));
		$ligne={ action => "PRIVMSG",dest=>$nick,msg=>'Vous etes maintenant connu en tant que [c=red]'.$user.'@'.$host.'[/c]'};
	}
	else
	{
		$ligne={ action => "PRIVMSG",dest=>$nick,msg=>'Impossible de vous identifier en tant que [c=red]'.$user.'@'.$host.'[/c]'};
	}

	push(@return,$ligne);
	return @return;
}

sub bot_on_nick_change {
	my ($old_nick,$new_nick) = @_;

	Giraf::Core::_debug("Giraf::User::bot_on_nick_change($old_nick,$new_nick)",2);

	my @return;
	my $infos=getDataFromNick($old_nick);
	history_add($new_nick,$infos->{hostmask},$infos->{uuid});
	return @return;
}

sub add_user_info {
	my ( $nick,$hostmask) = @_;
	Giraf::Core::_debug("Giraf::User::add_user_info($nick,$hostmask)",3);
	my $UUID=$nick.'{'.$hostmask.'}';
	history_add($nick,$hostmask,$UUID);
	return $UUID;
}

sub getDataFromNick {
	my ($nick)=@_;

	Giraf::Core::_debug("Giraf::User::getDataFromNick($nick)",3);

	my ($sth,$return,$uuid,$hostmask,$uuid_with_privileges);
	$sth=$_dbh->prepare("SELECT hostmask,UUID FROM $_tbl_nick_history WHERE nick LIKE ? ORDER BY last_seen DESC");
		$sth->bind_columns(\$hostmask,\$uuid);
		$sth->execute($nick);
		$sth->fetch();

		$sth=$_dbh->prepare("SELECT UUID FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ?");
		$sth->bind_columns(\$uuid_with_privileges);
		$sth->execute($nick,$hostmask);
		$sth->fetch();
		if($uuid_with_privileges)
		{
			if($uuid ne $uuid_with_privileges)
			{
				Giraf::Core::emit(Giraf::Trigger::on_uuid_change($uuid,$uuid_with_privileges));
		}
		$uuid=$uuid_with_privileges;	
	}
	$return={nick=>$nick,uuid=>$uuid,hostmask=>$hostmask};
	
	return $return;
}

sub bot_on_uuid_change {
	my ($uuid,$uuid_new) = @_;
	my @return;
	my $sth=$_dbh->prepare("UPDATE $_tbl_nick_history SET UUID=? WHERE UUID LIKE ?");
	Giraf::Core::_debug("Giraf::User::bot_on_nick_change($uuid,$uuid_new",3);
	$sth->execute($uuid_new,$uuid);
	return @return;
}

sub getUUID {
	my ($nick)=@_;
	Giraf::Core::_debug("Giraf::User::getUUID($nick)",5);	
	my $info=getDataFromNick($nick);
	return $info->{uuid};
}

sub getNickFromUUID {
	my ($uuid)=@_;

	Giraf::Core::_debug("Giraf::User::getNickFromUUID($uuid)",5);

	my ($sth,$nick);
	$sth=$_dbh->prepare("SELECT nick FROM $_tbl_nick_history WHERE UUID LIKE ? ORDER BY last_seen DESC");
	$sth->bind_columns(\$nick);
	$sth->execute($uuid);
	$sth->fetch();
	return $nick;
}

sub history_add {
	my ($nick,$hostmask,$UUID) = @_;

	Giraf::Core::_debug("Giraf::User::history_add($nick,$hostmask,$UUID)",3);

	my ($sth,$uuid_with_privileges);
	$sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_nick_history (nick,last_seen,UUID,hostmask) VALUES (?,?,?,?)");
	$sth->execute($nick,time(),$UUID,$hostmask);
	if(!$_botadmin_registered && $nick eq Giraf::Config::get('botadmin'))
	{
		user_register_botadmin($nick,$hostmask,$UUID);
		$_botadmin_registered=1;
	}
	$sth=$_dbh->prepare("SELECT UUID FROM $_tbl_users WHERE nick LIKE ? AND hostmask LIKE ?");
	$sth->bind_columns(\$uuid_with_privileges);
	$sth->execute($nick,$hostmask);
	$sth->fetch();
	if($uuid_with_privileges)
	{
		if($UUID ne $uuid_with_privileges)
		{
			Giraf::Core::emit(Giraf::Trigger::on_uuid_change($UUID,$uuid_with_privileges));
		}
	}
}

sub user_register_botadmin {
	my ($nick,$hostmask,$UUID) = @_;
	Giraf::Core::_debug("Giraf::User::user_register_botadmin($nick,$hostmask,$UUID)",4);
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_users (nick,hostmask,UUID,privileges) VALUES (?,?,?,10000)");
	$sth->execute($nick,$hostmask,$nick.'{'.$hostmask.'}');
}

sub user_register {
	my ($nick) = @_;
	Giraf::Core::_debug("Giraf::User::user_register($nick)",4);
	if(!is_user_registered($nick))
	{
		my ($UUID,$sth);
		my $data=getDataFromNick($nick);
		$UUID=$nick.'{'.$data->{hostmask}.'}';
		$sth=$_dbh->prepare("INSERT INTO $_tbl_users (nick,hostmask,UUID) VALUES (?,?,?)");
		$sth->execute($nick,$data->{hostmask},$UUID);
		return 1;
	}
	return 0;
}

sub user_ignore {
	my ($nick,$perma) = @_;
	Giraf::Core::_debug("Giraf::User::user_ignore($nick,$perma)",4);
	my ($UUID,$sth);
	if(!Giraf::User::is_user_chan_admin($nick))
	{
		if(!is_user_registered($nick))
		{
			user_register($nick);
		}
		$UUID=getUUID($nick);
		$sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_ignores (uuid,permanent) VALUES (?,?)");
		return $sth->execute($UUID,$perma);
	}
	else
	{
		return 0;
	}
}

sub user_unignore {
	my ($nick) = @_;
	Giraf::Core::_debug("Giraf::User::user_unignore($nick)",4);
	my ($UUID,$sth);
	$UUID=getUUID($nick);
	$sth=$_dbh->prepare("DELETE FROM $_tbl_ignores WHERE uuid LIKE ?");
	return $sth->execute($UUID);
}

sub user_update_privileges {
	my ($nick,$level) = @_;
	Giraf::Core::_debug("Giraf::User::user_update_privileges($nick,$level)",4);
	my $num=0;
	switch($level) 
	{
		case 'botadmin' 	{ $num=10000;	}
		case 'admin'		{ $num=1000;	}
		case 'chan_admin'	{ $num=100;	}
		case '0'		{ $num=0;	}
		else			{ return 0;	}
	}
	my $uuid=getUUID($nick);
	if(is_user_registered($nick))
	{
		my $sth=$_dbh->prepare("UPDATE $_tbl_users SET privileges=? WHERE UUID LIKE ?");
		return $sth->execute($num,$uuid);
		return 1;
	}
	else
	{
		return 0;
	}
}


sub is_user_auth {
        my ($username,$level) = @_;

	Giraf::Core::_debug("Giraf::User::is_user_auth($username,$level)",5);

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

sub is_user_botadmin {
	my ($user) = @_;
	Giraf::Core::_debug("Giraf::User::is_user_botadmin($user)",5);
	return is_user_auth($user,10000);
}

sub is_user_admin {
	my ($user) = @_;
	Giraf::Core::_debug("Giraf::User::is_user_admin($user)",5);
	return is_user_auth($user,1000);
}

sub is_user_chan_admin {
	my ($user) = @_;
	Giraf::Core::_debug("Giraf::User::is_user_chan_admin($user)",5);
	return is_user_auth($user,100);
}

sub is_user_registered {
	my ($user) = @_;
	Giraf::Core::_debug("Giraf::User::is_user_registered($user)",5);
	return is_user_auth($user,0);
}

sub is_user_ignore {
	my ($username) = @_;
	Giraf::Core::_debug("Giraf::User::is_user_ignore($username)",5);
	my ($ignore,$uuid,$sth);
	$uuid=getUUID($username);
	$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_ignores WHERE UUID LIKE ?");
	$sth->bind_columns(\$ignore);
	$sth->execute($uuid);
	$sth->fetch();
	return $ignore;
}

1;
