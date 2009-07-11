#! /usr/bin/perl
$| = 1;

package Giraf::Module;

use strict;
use warnings;

use Giraf::Config;
use Giraf::Admin;
use Giraf::Trigger;

use DBI;
use Switch;

# Public vars

# Private vars
our $_kernel;
our $_irc;
our $_dbh;
our $_tbl_modules = 'modules';
our $_tbl_users = 'users';
our $_tbl_config = 'config';

sub mod_load {
	my ($mod) = @_;
	
	eval ("require Giraf::Modules::$mod;");
	return $@;
}

sub mod_run {
	my ($mod, $fn, @args) = @_;
	my $ret;

	eval ('$ret = ' . '&Giraf::Modules::' . $mod . '::' . $fn . '(@args);');
	return $ret;
}

sub mod_mark_loaded {
	my ($mod,$bool) = @_;

	my $req = $_dbh->prepare("UPDATE $_tbl_modules SET loaded=? WHERE name LIKE ?");
	$req->execute($bool,$mod);
}

sub init {
	my ( $classe, $ker, $irc_session ) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;

	my ($req);

	Giraf::Core::debug("Giraf::Module::init()");
	

	$_dbh = Giraf::Admin::get_dbh();
	$_dbh->do("BEGIN TRANSACTION");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_modules (autorun NUMERIC, file TEXT PRIMARY KEY, name TEXT,session NUMERIC, loaded NUMERIC);");
#	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_users (name TEXT PRIMARY KEY, privileges NUMERIC);");
#	$req=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_users(name,privileges) VALUES(?,10000);");
#	$req->execute(Giraf::Config::get('botadmin'));
	# Mark all modules as not loaded
	$_dbh->do("UPDATE $_tbl_modules SET loaded=0");
	$_dbh->do("COMMIT");

	Giraf::Trigger::register('public_function','core','bot_say',\&bot_say,'say .*');
	Giraf::Trigger::register('public_function','core','bot_do',\&bot_do,'do .*');
	Giraf::Trigger::register('public_function','core','bot_quit',\&bot_quit,'quit.*');
	Giraf::Trigger::register('public_function','core','bot_module_main',\&bot_module_main,'module.*');

	my $sth=$_dbh->prepare("SELECT file,name,autorun FROM $_tbl_modules");
	my ($module, $module_name, $autorun);
	$sth->bind_columns( \$module, \$module_name, \$autorun );
	$sth->execute();
	while($sth->fetch() )
	{
		if($autorun > 0)
		{
			my $err = mod_load($module_name);
			if ($err) {
				print "Error while loading module \"$module_name\" ! Reason: $err\n";
				mod_mark_loaded($module_name,0);
			}
			else {
				mod_run($module_name, 'init', $ker, $irc_session);
				# Mark module as loaded
				mod_mark_loaded($module_name,1);
			}
		}
	}

}

#Basic module sub
sub bot_say {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= "say (.*)";
	my ($txt) = $what=~/$regex/ ;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>$txt};
	push(@return,$ligne);
	return @return;
}

sub bot_do {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= "do (.*)";
	my ($txt) = $what=~/$regex/ ;
	my $ligne={ action =>"ACTION",dest=>$dest,msg=>$txt};
	push(@return,$ligne);
	return @return;
}

sub bot_quit {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("bot_quit()");

	my @return;
	if(Giraf::User::is_user_auth($nick,10000))
	{
		my $reason="All your bot are belong to us";
		if($what=~m/quit (.+)/)
		{
			$reason=$1;
		}
		Giraf::Trigger->on_bot_quit($reason);
	}
	return @return
}

#modules s methods
sub bot_module_main {
	my ($nick,$dest,$what)=@_;
	
	Giraf::Core::debug("bot_module_main");
	
	my @return;
	my ($sub_func,$args);
	$what=~m/^module\s+(.+?)(\s+(.+))?$/;
	
	$sub_func=$1;
	$args=$3;
	
	Giraf::Core::debug("main : sub_func=$sub_func");

	switch ($sub_func)
	{
		case 'available' 	{	push(@return,bot_available_module($nick,$dest,$args)); }
		case 'list' 	{	push(@return,bot_list_module($nick,$dest,$args)); }
		case 'add'	{	push(@return,bot_add_module($nick,$dest,$args)); }
		case 'del'	{	push(@return,bot_del_module($nick,$dest,$args)); }
		case 'load'	{	push(@return,bot_load_module($nick,$dest,$args)); }
		case 'set'	{	push(@return,bot_set_module($nick,$dest,$args)); }
		case 'unload'	{	push(@return,bot_unload_module($nick,$dest,$args)); }
		case 'reload'	{	push(@return,bot_reload_modules($nick,$dest,$args)); }
	}

	return @return;
}

sub bot_reload_modules
{
	my ($nick,$dest,$what)=@_;

	Giraf::Core::debug("bot_reload_modules()");

	my @return;
	my $ligne;
	if(Giraf::User::is_user_auth($nick,10000) )
	{
		foreach my $file_pm (keys %INC) {
			if( my ($module_name) = $file_pm =~/^Giraf\/Modules\/(.+)\.pm$/)
			{
				Giraf::Core::debug("Reloading module : $module_name");
				if( module_exists($module_name) && module_loaded($module_name) )
				{
					my $err = mod_load($module_name);       
					mod_mark_loaded($module_name, 0);
					mod_run($module_name, 'unload');
					delete($INC{$file_pm});
					$err = mod_load($module_name);
					if ($err) {
						print "Error while loading module \"$module_name\" ! Reason: $err\n";
						$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] borken ! (non chargé)'};
					}
					else {
						mod_run($module_name, 'init', $_kernel, $_irc); # TODO: check return
						mod_mark_loaded($module_name, 1);
						$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] rechargé !'};
					}
					push(@return,$ligne);
				}
			}	
		}
	}
	return @return;
}

sub bot_load_module {
	my($nick, $dest, $module_name)=@_;
	my @return;

	Giraf::Core::debug("bot_load_module()");

	if(Giraf::User::is_user_auth($nick,10000))
	{

		if(module_exists($module_name))
		{
			my $ligne;
			if(!module_loaded($module_name))
			{

				my $err = mod_load($module_name);
				if ($err) {
					print "Error while loading module \"$module_name\" ! Reason: $err\n";
					$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] borken ! (non chargé)'};
				}
				else {
					mod_run($module_name, 'init', $_kernel, $_irc); # TODO: check return
					mod_mark_loaded($module_name,1);
					$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] chargé !'};
				}
			}
			else
			{
				$ligne={action=>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] déja chargé !'};
			}
			push(@return,$ligne);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] non trouve !'};
			push(@return,$ligne);
		}

	}
	return @return;
}


sub bot_unload_module {
	my($nick, $dest, $module_name)=@_;

	Giraf::Core::debug("bot_unload_module()");

	my @return;

	if(Giraf::User::is_user_auth($nick,10000))
	{
		if( module_exists($module_name) )
		{
			mod_run($module_name, 'unload'); # TODO: check return
			mod_mark_loaded($module_name,0);
			delete($INC{'Giraf/Modules/'.$module_name.'.pm'});
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] déchargé !'};
			push(@return,$ligne);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] non trouve !'};
			push(@return,$ligne);
		}
	}
	return @return;
}


sub bot_add_module {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("bot_add_module()");

	my $regex= '(.+)\s+(.+\.pm)\s+([0-9]*)';
	my @return;
	if(Giraf::User::is_user_auth($nick,10000))
	{
		if( my ($name,$file,$autorun) = $what=~/$regex/ )
		{
			if( -e "lib/Giraf/Modules/".$file )
			{
				my $sth=$_dbh->prepare("INSERT INTO $_tbl_modules (name,file,autorun) VALUES (?,?,?)");
				$sth->execute($name,$file,$autorun);
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] ajoute !'};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] non ajoute ! Fichier non existant !'};
				push(@return,$ligne);
			}
		}
		else
		{	
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$what".'[/c] non ajoute ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}

	}
	return @return
}

sub bot_del_module {
	my($nick, $dest, $module_name)=@_;

	Giraf::Core::debug("bot_del_module()");

	my @return;

	if(Giraf::User::is_user_auth($nick,10000))
	{
		if (!$module_name)
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$module_name".'[/c] non retiré ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}
		else 
		{
			if(module_exists($module_name))
			{
				my $sth=$_dbh->prepare("DELETE FROM $_tbl_modules WHERE name LIKE ?");
				$sth->execute($module_name);
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] retiré !'};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] non trouvé !'};
				push(@return,$ligne);
			}
		}
	}
	return @return

}

sub bot_list_module {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("bot_list_module()");

	my $sth=$_dbh->prepare("SELECT name,autorun,session,loaded FROM $_tbl_modules");
	my @return;
	my ($module_name,$autorun,$session,$loaded);
	$sth->bind_columns( \$module_name, \$autorun, \$session, \$loaded);
	$sth->execute();
	while($sth->fetch())
	{
		my $ligne= {action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$module_name.'[/c] : autorun=[color=orange]'.$autorun.'[/color];loaded=[c=teal]'.$loaded.'[/c]'};
		push(@return,$ligne);
	}
	return @return
}

sub bot_available_module {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("bot_available_module()");

	my @return;
	my @dir;
	my ($ligne,$output);

	opendir MODDIR, "lib/Giraf/Modules/";
	@dir = readdir MODDIR;
	closedir MODDIR;

	foreach my $file (@dir)
	{
		if($file=~/\.pm$/)
		{
			if($output)
			{
				$output=$output.", ".$file;
			}
			else
			{
				$output=$file;
			}
		}
	}
	$ligne= {action =>"MSG",dest=>$dest,msg=> "Module [c=red] ".$output." [/c]" };
	push(@return,$ligne);
	return @return
}

sub bot_set_module {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= '(.*)\s+(.*)\s+(.*)';

	Giraf::Core::debug("bot_set_module()");

	if(Giraf::User::is_user_auth($nick,10000))
	{
		Giraf::Core::debug("regex=$regex : what=$what");
		if( my ($name,$param,$value) = $what=~/^$regex$/ )
		{
			my $tbl_param;
			switch($param)
			{
				case 'autorun'	{$tbl_param='autorun'}
			}
			if(module_exists($name))
			{
				my $sth=$_dbh->prepare("UPDATE modules SET ".$tbl_param."=? WHERE name LIKE ?");
				$sth->execute($value,$name);
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] updaté ('.$param.'='.$value.') !'};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] inconnu !'};
				push(@return,$ligne);
			}
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$what".'[/c] non updaté ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}

	}
	return @return
}

sub modules_on_quit {
        my ($module,$module_name,$sth);

        Giraf::Core::set_quit();
        Giraf::Core::debug("modules_on_quit()");

        $sth=$_dbh->prepare("SELECT file,name FROM $_tbl_modules WHERE loaded=1");
        $sth->bind_columns( \$module , \$module_name);
        $sth->execute();

        while($sth->fetch())
        {
                my $err = mod_load($module_name);       # XXX: why ??
                mod_mark_loaded($module_name, 0);
                mod_run($module_name, 'unload');
                mod_run($module_name, 'quit');
        }

        return 0;

}

#Utility subs
sub module_exists {
	my ($module_name) = @_;

	my $count;

	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_modules WHERE name LIKE ?");
	$sth->bind_columns( \$count );
	$sth->execute($module_name);
	$sth->fetch();

	return $count;

}

sub module_loaded {
	my ($mod) =@_;
	my $count;
	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_modules WHERE loaded=1 AND name LIKE ?");
	$sth->bind_columns(\$count);
	$sth->execute($mod);
	$sth->fetch();
	return $count;
}

1;
