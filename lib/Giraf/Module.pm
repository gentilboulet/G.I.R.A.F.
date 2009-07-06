#! /usr/bin/perl
$| = 1;

package Giraf::Module;

use strict;
use warnings;

use Giraf::Config;

use DBI;

# Public vars

# Private vars
our $_kernel;
our $_irc;
our $_triggers;
our $_dbh;
our $_tbl_modules = 'modules';
our $_tbl_users = 'users';
our $_tbl_config = 'config';

our $_public_functions;
our $_private_functions;
our $_on_nick_functions;
our $_on_join_functions;
our $_on_part_functions;
our $_on_quit_functions;
our $_public_parsers;
our $_private_parsers;

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

sub mod_mark {
	my ($mod,$bool) = @_;

	my $req = $_dbh->prepare("UPDATE $_tbl_modules SET loaded=? WHERE name = ?");
	$req->execute($bool,$mod);
}

sub init_sessions {
	$_dbh = DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	my $sth=$_dbh->prepare("SELECT file,name FROM $_tbl_modules WHERE session>0");
        my ($module, $module_name);
        $sth->bind_columns( \$module, \$module_name );
        $sth->execute();
        while($sth->fetch() )
        {
		require($module);
	        eval "&".$module_name.'::init_session();';
        }

}

sub init {
	my ( $classe, $ker, $irc_session, $set_triggers) = @_;
	$_kernel  = $ker;
	$_irc     = $irc_session;
	$_triggers=$set_triggers;

	my ($req);
	
	register_public_function('core','bot_say',\&bot_say,'say .*');
	register_public_function('module','bot_load_module',\&bot_load_module,'module load (.+)');
	register_public_function('module','bot_unload_module',\&bot_unload_module,'module unload (.+)');
	register_public_function('module','bot_add_module',\&bot_add_module,'module add (.+)');
	register_public_function('module','bot_del_module',\&bot_del_module,'module del (.+)');
	register_public_function('module','bot_list_module',\&bot_list_module,'module list');
	register_public_function('module','bot_quit',\&bot_quit,'quit(.*)');
	register_public_function('module','bot_reload_modules',\&bot_reload_modules,'module reload');

	$_dbh = DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_modules (autorun NUMERIC, file TEXT, name TEXT,session NUMERIC, loaded NUMERIC);");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_users (name TEXT PRIMARY KEY, privileges NUMERIC);");
	$_dbh->do("CREATE TABLE IF NOT EXISTS $_tbl_config (name TEXT PRIMARY KEY, value TEXT);");
	$req=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_users(name,privileges) VALUES(?,10000);");
	$req->execute(Giraf::Config::get('botadmin'));

	# Mark all modules as not loaded
	$_dbh->do("UPDATE $_tbl_modules SET loaded=0");

	my $sth=$_dbh->prepare("SELECT file,name FROM $_tbl_modules WHERE autorun>0");
	my ($module, $module_name);
	$sth->bind_columns( \$module, \$module_name );
	$sth->execute();
	while($sth->fetch() )
	{
		my $err = mod_load($module_name);
		if ($err) {
			print "Error while loading module \"$module_name\" ! Reason: $err\n";
		}
		else {
			mod_run($module_name, 'init', $ker, $irc_session);
			# Mark module as loaded
			mod_mark($module_name,1);
		}
	}
	$_kernel->yield("connect");
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
	my ($classe,$reason)=@_;
	my ($count,$module,$module_name,$sth);
	Giraf::Core::set_quit();
	$sth=$_dbh->prepare("SELECT COUNT(*),file,name FROM $_tbl_modules WHERE loaded=1");

	$sth->bind_columns( \$count, \$module , \$module_name);
	$sth->execute();
	while($sth->fetch())
	{
		my $err = mod_load($module_name);	# XXX: why ??
		mod_mark($module_name, 0);
		mod_run($module_name, 'unload');
		mod_run($module_name, 'quit');
	}
	$_kernel->signal( $_kernel, 'POCOIRC_SHUTDOWN', $reason );
	return 0;

}

sub public_msg
{
	my ($classe, $nick, $channel, $what )=@_;
	my @return;

	foreach my $key (keys %$_public_functions) 
	{
		my $module=$_public_functions->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};
			#First we check for triggers
			if(my ($arg)=($what=~/^$_triggers(.*)$/))
			{
				my $regex=$element->{regex};
				if ($arg =~/^$regex$/)
				{
					push(@return,$element->{function}->($nick,$channel,$arg));
				}
			}
		}
	}

	foreach my $key (keys %$_public_parsers)
	{
		my $module=$_public_parsers->{$key};
		foreach my $func (keys %$module)
		{
			my $element = $module->{$func};
			#First we check for triggers
			my $regex=$element->{regex};
			if ($what =~/^$regex$/)
			{
				push(@return,$element->{function}->($nick,$channel,$what));
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
		return @return;

	}
}

#Registration sub
sub register_public_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_public_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};	
}

sub register_public_parser {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_public_parsers->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
}

sub register_on_nick_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_on_nick_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
}

sub register_on_join_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_on_join_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
}

sub register_on_part_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_on_part_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
}

sub register_on_quit_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_on_quit_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
}


sub register_private_function {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_private_functions->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};	
}

sub register_private_parser {
	my ($module_name,$function_name,$function,$regex)=@_;

	$_private_parsers->{$module_name}->{$function_name}={function=>\&$function_name,regex=>$regex};
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

#modules s methods
sub bot_module_main {
	my ($nick,$dest,$what)=@_;

}

sub bot_reload_modules
{
}

sub bot_load_module {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= $_triggers."module load (.+)";
	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	if($count > 0)
	{

		$sth=$_dbh->prepare("SELECT COUNT(*),file,name FROM $_tbl_modules WHERE name LIKE ?");
		my ($module,$module_name);
		$sth->bind_columns( \$count, \$module , \$module_name);
		if( my ($txt) = $what=~/$regex/ )
		{
			$sth->execute($txt);
			$sth->fetch();
			if($count > 0)
			{
				my $ligne;
				my $err = mod_load($module_name);
				if ($err) {
					print "Error while loading module \"$module_name\" ! Reason: $err\n";
					$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] borken ! (non chargé)'};
				}
				else {
					mod_run($module_name, 'init', $_kernel, $_irc); # TODO: check return
					$sth=$_dbh->prepare("UPDATE $_tbl_modules SET loaded=1 WHERE name LIKE ?");
					$sth->execute($txt);
					$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] chargé !'};
				}
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] non trouve !'};
				push(@return,$ligne);
			}
		}
	}
	return @return;
}


sub bot_unload_module {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= "module unload (.+)";
	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	if($count > 0)
	{
		$sth=$_dbh->prepare("SELECT COUNT(*),file,name FROM $_tbl_modules WHERE name LIKE ?");
		my ($module,$module_name);
		$sth->bind_columns( \$count, \$module , \$module_name);
		if( my ($txt) = $what=~/$regex/ )
		{
			$sth->execute($txt);
			$sth->fetch();
			if($count > 0)
			{
				mod_run($module_name, 'unload'); # TODO: check return
				$sth=$_dbh->prepare("UPDATE $_tbl_modules SET loaded=0 WHERE name LIKE ?");
				$sth->execute($txt);
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] déchargé !'};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] non trouve !'};
				push(@return,$ligne);
			}
		}
	}
	return @return;
}


sub bot_add_module {
	my($nick, $dest, $what)=@_;
	my $regex= "module add (.+) (.+\.pm) ([0-9]*)";
	my @return;
	if(is_user_auth($nick,10000))
	{
		my $sth=$_dbh->prepare("INSERT INTO $_tbl_modules (name,file,autorun) VALUES (?,?,?)");
		if( my ($name,$file,$autorun) = $what=~/$regex/ )
		{
			if( -e "lib/Giraf/Modules/".$file )
			{

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
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$name $file $autorun".'[/c] non ajoute ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}

	}
	return @return
}

sub bot_del_module {
	my($nick, $dest, $what)=@_;
	my $regex= "module del (.+)";
	my @return;

	if(is_user_auth($nick,10000))
	{
		my ($name) = $what=~/$regex/;
		if (!$name)
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$name".'[/c] non retiré ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}
		else 
		{
			my $sth=$_dbh->prepare("DELETE FROM $_tbl_modules WHERE name=?");
			$sth->execute($name);
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] retiré !'};
			push(@return,$ligne);
		}
	}
	return @return

}

sub bot_list_module {
	my($nick, $dest, $what)=@_;
	my $sth=$_dbh->prepare("SELECT name,autorun,session,loaded FROM $_tbl_modules");
	my $regex= "module list";
	my @return;
	my $name; 
	my $autorun;
	my $session;
	my $loaded;
	$sth->bind_columns( \$name, \$autorun, \$session, \$loaded);
	$sth->execute();
	while($sth->fetch())
	{
		my $ligne= {action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] : autorun=[color=orange]'.$autorun.'[/color];loaded=[c=teal]'.$loaded.'[/c]'};
		push(@return,$ligne);
	}
	return @return

}


sub bot_quit {
	my($nick, $dest, $what)=@_;
	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	my @return;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	my $regex= "quit (\\S.*)";
	if($count > 0)
	{
		my $reason="All your bot are belong to us";
		if($what=~/$regex/ )
		{
			$reason=$1;
		}
		on_bot_quit($reason);
	}
	return @return
}

#Utility subs
sub is_module_exists {

}

#TEMPORARY while no User module
sub is_user_auth {
	my ($username,$level) = @_;

	my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_users WHERE name LIKE ? AND privileges >= ?");
	my $count;

	$sth->bind_columns( \$count);
	$sth->execute($username);
	$sth->fetch();
	return ($count > 0)
}

#Parameter value
sub set_param
{
	my ($param,$value)=@_;
	my $sth=$_dbh->prepare("INSERT OR REPLACE INTO $_tbl_config(name,value) VALUES(?,?)");
	$sth->execute($param,$value);
	return $param;
}

sub get_param
{
	my ($what)=@_;
	my $value;
	my $sth=$_dbh->prepare("SELECT value FROM $_tbl_config WHERE name LIKE ?");
	$sth->bind_columns(\$value);
	$sth->execute($what);
	$sth->fetch();
	return $value;

}
1;
