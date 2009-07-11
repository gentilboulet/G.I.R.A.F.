#! /usr/bin/perl
$| = 1;

package Giraf::Admin;

use strict;
use warnings;

use Giraf::Config;
use Giraf::Module;
use Giraf::Chan;
use Giraf::User;
use Giraf::Trigger;

use DBI;
use Switch;

# Public vars

# Private vars
our $_kernel;
our $_irc;
our $_dbh;
our $_botname;
our $_tbl_config='config';
our $_tbl_modules_access='modules_access';
our $_tbl_users;
our $_tbl_chans;
our $_tbl_modules;
our $_auth_modules;

sub init {
	my ( $classe, $ker, $irc_session, $botname) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;
	$_botname = $botname;

	Giraf::Core::debug("Giraf::Admin::init()");
	
	$_tbl_chans=$Giraf::Chan::_tbl_chans;
	$_tbl_modules=$Giraf::Module::_tbl_modules;

	$_dbh=get_dbh();
	$_dbh->do("BEGIN TRANSACTION");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_config (name TEXT PRIMARY KEY, value TEXT);");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_modules_access (module_name TEXT REFERENCES $_tbl_modules (name), chan_name TEXT REFERENCES $_tbl_chans (name), disabled NUMERIC DEFAULT 0, UNIQUE (module_name,chan_name) );");
	$_dbh->do("COMMIT");

	Giraf::Trigger::register('public_function','core','bot_admin_main',\&bot_admin_main,'admin.*');
	Giraf::Trigger::register('public_function','core','bot_register',\&bot_register,'register.*');
	Giraf::Admin::module_authorized_update();
}

#Utility subs
sub set_param {
	my ($param,$value)=@_;

	Giraf::Core::debug("Giraf::Admin::set_param($param,$value)");

	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_config(name,value) VALUES(?,?)");
	$sth->execute($param,$value);
	return $param;
}

sub get_param {
	my ($name) = @_;
	
	Giraf::Core::debug("Giraf::Admin::get_param($name)");
	
	my $value;
	my $sth=$_dbh->prepare("SELECT value FROM $_tbl_config WHERE name LIKE ?");
	$sth->bind_columns(\$value);
	$sth->execute($name);
	$sth->fetch();
	return $value;
}

sub get_dbh {
	if( !$_dbh )
	{
		$_dbh=DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	}
	return $_dbh;
}

#Admin subs
sub bot_admin_main {
	my ($nick,$dest,$what)=@_;

	Giraf::Core::debug("bot_admin_main");

	my @return;
	my ($sub_func,$args);
	$what=~m/^admin\s+(.+?)(\s+(.+))?$/;

	$sub_func=$1;
	$args=$3;

	Giraf::Core::debug("admin main : sub_func=$sub_func");

	switch ($sub_func)
	{
#		case 'ignore'{       push(@return,bot_ignore_user($nick,$dest,$args)); }
		case 'module'		{	push(@return,bot_admin_module($nick,$dest,$args)); }
		case 'user'		{	push(@return,bot_admin_user($nick,$dest,$args)); }
		case 'join'		{	push(@return,bot_join($nick,$dest,$args)); }
		case 'part'		{	push(@return,bot_part($nick,$dest,$args)); }
	}

	return @return;
}

sub bot_admin_module {
	my ($nick,$dest,$what)=@_;

	Giraf::Core::debug("bot_admin_module($what)");

	my @return;
	my ($sub_func,$args);
	$what=~m/^(.+?)(\s+(.+))?$/;

	$sub_func=$1;
	$args=$3;

	Giraf::Core::debug("admin module : sub_func=$sub_func");

	switch ($sub_func)
	{
		case 'enable'           {       push(@return,bot_disable_module(0,$nick,$dest,$args)); }
		case 'disable'          {       push(@return,bot_disable_module(1,$nick,$dest,$args)); }
	}

	return @return;
}

sub bot_admin_user {
        my ($nick,$dest,$what)=@_;

        Giraf::Core::debug("bot_admin_user");

        my @return;
        my ($sub_func,$args);
        $what=~m/^(.+?)(\s+(.+))?$/;

        $sub_func=$1;
        $args=$3;

        Giraf::Core::debug("admin user : sub_func=$sub_func");

        switch ($sub_func)
        {
#                case 'enable'           {       push(@return,bot_disable_user(0,$nick,$dest,$args)); }
#                case 'disable'          {       push(@return,bot_disable_user(1,$nick,$dest,$args)); }
		 case 'register'	 {	 push(@return,bot_register_user($nick,$dest)); }
        }

        return @return;
}


sub bot_disable_module {
	my ($disabled,$nick,$dest,$what) = @_;

	Giraf::Core::debug("bot_disable_module");

	my @return;
	my ($ligne,$chan,$module_name);

	$what=~m/^(#.+?)\s+(.+?)$/;

	$chan=$1;
	$module_name=$2;

	if(Giraf::User::is_user_auth($nick,10000) && $module_name ne 'core')
	{
		if(Giraf::Module::module_exists($module_name) && Giraf::Chan::known_chan($chan) )
		{
			my $mot;
			if(!$disabled)
			{
				$mot="activé";
			}
			else
			{
				$mot="desactivé";
			}
			my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_modules_access (module_name,chan_name,disabled) VALUES (?,?,?)");
			$sth->execute($module_name,$chan,$disabled);
			$_auth_modules->{$chan}->{$module_name}={disabled=>$disabled};
			$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] '.$mot.' pour [c=green]'.$chan.'[/c]!'};
		}
		else
		{
			$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] inconnu ou [c=green]'.$chan.'[/c] inconnu !'};
		}
		push (@return,$ligne);
	}
	return @return;
}

sub bot_join {
	my ($nick,$dest,$what) = @_;

	Giraf::Core::debug("bot_join");

	my @return;
	my ($chan,$reason);

	$what=~m/^(#\S+?)$/;

	$chan=$1;
	if( Giraf::User::is_user_auth($nick,10000) )
	{
		Giraf::Chan->join($chan);
	}
	return @return;
}

sub bot_part {
	my ($nick,$dest,$what) = @_;

	Giraf::Core::debug("bot_part");

	my @return;
	my ($chan,$reason);

	$what=~m/^(#.+?)(\s+(.+?))?$/;

	$chan=$1;
	$reason = $3;

	Giraf::Core::debug("part $chan, $reason");

	if( Giraf::User::is_user_auth($nick,10000) )
	{
		Giraf::Chan->part($chan,$reason);
	}
	return @return;
}

sub bot_register_user {
	my ($nick,$dest) = @_;
	my @return;
	my $ligne;
	if(Giraf::User->user_register($nick))
	{
		$ligne={ action =>"MSG",dest=>$dest,msg=>'Utilisateur [c=red]'.Giraf::User::getUUID($nick).'[/c] enregistré !'};
	}
	else
	{
		$ligne={ action =>"MSG",dest=>$dest,msg=>'Impossible d\'enregistrer [c=red]'.Giraf::User::getUUID($nick).'[/c] !'};
	}
	push(@return,$ligne);	
	return @return;
}


#Admin utility subs
sub module_authorized {
	my ($module_name,$chan) = @_;
	return (!$_auth_modules->{$chan}->{$module_name}->{disabled});
}

sub module_authorized_update {

	Giraf::Core::debug("module_authorized_update()");

	undef $_auth_modules;

	my ($disabled,$module_name,$chan);
	my $sth=$_dbh->prepare("SELECT disabled,module_name,chan_name FROM $_tbl_modules_access");
	$sth->bind_columns(\$disabled,\$module_name,\$chan);
	$sth->execute();
	while($sth->fetch())
	{
		$_auth_modules->{$chan}->{$module_name}={disabled=>$disabled};
	}
}

1;
