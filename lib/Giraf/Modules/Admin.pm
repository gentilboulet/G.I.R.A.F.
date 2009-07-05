#! /usr/bin/perl
$| = 1;

package Giraf::Modules::Admin;

use strict;
use warnings;
use DBI;

our $kernel;
our $irc;
our $triggers;
our $public_functions;
our $private_functions;
our $on_nick_functions;
our $on_join_functions;
our $on_part_functions;
our $on_quit_functions;
our $public_parsers;
our $private_parsers;
our $dbh;


sub init_sessions {

	$dbh=DBI->connect("dbi:SQLite:dbname=Modules/DB/modules.db","","");
	my $sth=$dbh->prepare("SELECT file,name FROM modules WHERE session>0");
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
	$kernel  = $ker;
	$irc     = $irc_session;
	$triggers=$set_triggers;
	$public_functions->{bot_say}={function=>\&bot_say,regex=>'say (.*)'};
	$public_functions->{bot_do}={function=>\&bot_do,regex=>'do (.*)'};
	$public_functions->{bot_load_module}={function=>\&bot_load_module,regex=>'module load (.+)'};
	$public_functions->{bot_unload_module}={function=>\&bot_unload_module,regex=>'module unload (.+)'};
	$public_functions->{bot_add_module}={function=>\&bot_add_module,regex=>'module add (.+)'};
	$public_functions->{bot_del_module}={function=>\&bot_del_module,regex=>'module del (.+)'};
	$public_functions->{bot_list_module}={function=>\&bot_list_module,regex=>'module list'};
	$public_functions->{bot_quit}={function=>\&bot_quit,regex=>'quit(.*)'};
	$public_functions->{bot_reload_modules}={function=>\&bot_reload_modules,regex=>'module reload'};

        $dbh=DBI->connect("dbi:SQLite:dbname=Modules/DB/modules.db","","");
	$dbh->do("CREATE TABLE IF NOT EXISTS modules (autorun NUMERIC, file TEXT, name TEXT,session NUMERIC, loaded NUMERIC);");
	$dbh->do("CREATE TABLE IF NOT EXISTS users (name TEXT PRIMARY KEY, privileges NUMERIC);");
	$dbh->do("CREATE TABLE IF NOT EXISTS config (name TEXT PRIMARY KEY, value TEXT);");
	$dbh->do("INSERT INTO users(name,privileges) VALUES('GentilBoulet',0);");

	my $sth=$dbh->prepare("SELECT file,name FROM modules WHERE autorun>0");
	my ($module, $module_name);
	$sth->bind_columns( \$module, \$module_name );
	$sth->execute();
	while($sth->fetch() )
	{
		eval "require Giraf::Modules::$module_name;";
		eval "&Giraf::Modules::$module_name" . '::init($Admin::kernel,$Admin::irc_session);';
	}
	$dbh->do("UPDATE modules SET loaded=1 WHERE autorun>0");
	$kernel->yield("connect");
}

sub on_part {
	my ($classe, $nick, $channel ) = @_;
	my @return;
        foreach my $key (keys %$on_part_functions)
	{
		my $element=$on_part_functions->{$key};
		push(@return,$element->{function}->($nick,$channel));
	}

	return @return;
}

sub on_quit {
	my ($classe, $nick) = @_;
	my @return;
        foreach my $key (keys %$on_quit_functions)
	{
		my $element=$on_quit_functions->{$key};
		push(@return,$element->{function}->($nick));
	}

	return @return;
}

sub on_nick {
	my ($classe, $nick, $nick_new ) = @_;
	my @return;
	foreach my $key (keys %$on_nick_functions)
	{
		my $element=$on_nick_functions->{$key};
		push(@return,$element->{function}->($nick,$nick_new));
	}
	return @return;
}

sub on_join {
	my ($classe, $nick, $channel ) = @_;
	my @return;
	foreach my $key (keys %$on_join_functions)
	{
		my $element=$on_join_functions->{$key};
		push(@return,$element->{function}->($nick,$channel));
	}

	return @return;
}

sub on_bot_quit {
	my ($classe,$reason)=@_;
	my ($count,$module,$module_name,$sth);
        Giraf::Core::set_quit();
	$sth=$dbh->prepare("SELECT COUNT(*),file,name FROM modules WHERE loaded=1");

	$sth->bind_columns( \$count, \$module , \$module_name);
	$sth->execute();
	while($sth->fetch())
	{
		require($module);
		$sth=$dbh->prepare("UPDATE modules SET loaded=0 WHERE name LIKE ?");
		$sth->execute($module_name);
		eval "&".$module_name.'::unload();';
                eval "&".$module_name.'::quit();'
	}
	$kernel->signal( $kernel, 'POCOIRC_SHUTDOWN', $reason );
	return 0;

}

sub public_msg
{
	my ($classe, $nick, $channel, $what )=@_;
	my @return;

	foreach my $key (keys %$public_functions) 
	{
		my $element=$public_functions->{$key};
		my $regex=$triggers.$element->{regex};
		if ($what =~/^$regex$/)
		{
			push(@return,$element->{function}->($nick,$channel,$what));
		}
	}
	foreach my $key (keys %$public_parsers)
	{
		my $element=$public_parsers->{$key};
		my $regex=$element->{regex};
		if ($what =~/$regex/)
		{
			push(@return,$element->{function}->($nick,$channel,$what));
		}
	}
	return @return;

}

sub private_msg
{
	my ($classe, $nick, $who, $where, $what )=@_;
	my @return;
	foreach my $key (keys %$private_functions) 
	{
		my $element=$private_functions->{$key};
		my $regex=$triggers.$element->{regex};
		if ($what =~/^$regex$/)
		{
			push(@return,$element->{function}->($nick,$nick,$what));
		}
	}
	foreach my $key2 (keys %$private_parsers)
	{
		my $element=$private_parsers->{$key2};
		my $regex=$element->{regex};
		if ($what =~/$regex/)
		{
			push(@return,$element->{function}->($nick,$where,$what));
		}
	}
	return @return;

}

sub set_param
{
	my ($param,$value)=@_;
	my $sth=$dbh->prepare("INSERT OR REPLACE INTO config(name,value) VALUES(?,?)");
	$sth->execute($param,$value);
	return $param;
}

sub get_param
{
	my ($what)=@_;
	my $value;
	my $sth=$dbh->prepare("SELECT value FROM config WHERE name LIKE ?");
	$sth->bind_columns(\$value);
	$sth->execute($what);
	$sth->fetch();
	return $value;

}

sub bot_say {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= $triggers."say (.*)";
	my ($txt) = $what=~/$regex/ ;
	my $ligne={ action =>"MSG",dest=>$dest,msg=>$txt};
	push(@return,$ligne);
	return @return;
}

sub bot_do {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= $triggers."do (.*)";
	my ($txt) = $what=~/$regex/ ;
	my $ligne={ action =>"ACTION",dest=>$dest,msg=>$txt};
	push(@return,$ligne);
	return @return;
}

sub bot_reload_modules
{
	Giraf::debug('AACallVote start !!');
	Giraf::debug('BBCallVote start !!');
}

sub bot_load_module {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= $triggers."module load (.+)";
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	if($count > 0)
	{

		$sth=$dbh->prepare("SELECT COUNT(*),file,name FROM modules WHERE name LIKE ?");
		my ($module,$module_name);
		$sth->bind_columns( \$count, \$module , \$module_name);
		if( my ($txt) = $what=~/$regex/ )
		{
			$sth->execute($txt);
			$sth->fetch();
			if($count > 0)
			{
				eval "require Giraf::Modules::$module_name;";
				$sth=$dbh->prepare("UPDATE modules SET loaded=1 WHERE name LIKE ?");
				$sth->execute($txt);
				eval "&Giraf::Modules::$module_name" . '::init($Admin::kernel,$Admin::irc_session);';
				my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] chargé !'};
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
	my $regex= $triggers."module unload (.+)";
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	if($count > 0)
	{
		$sth=$dbh->prepare("SELECT COUNT(*),file,name FROM modules WHERE name LIKE ?");
		my ($module,$module_name);
		$sth->bind_columns( \$count, \$module , \$module_name);
		if( my ($txt) = $what=~/$regex/ )
		{
			$sth->execute($txt);
			$sth->fetch();
			if($count > 0)
			{
				$sth=$dbh->prepare("UPDATE modules SET loaded=0 WHERE name LIKE ?");
				$sth->execute($txt);
				eval "&Giraf::Modules::$module_name" . '::unload();';
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
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges >= 10000");
	my $regex= $triggers."module add (.+) (.+\.pm) ([0-9]*)";
	my $count;
	my @return;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	if($count > 0)
	{
		$sth=$dbh->prepare("INSERT INTO modules (name,file,autorun) VALUES (?,?,?)");
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
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges >= 10000");
	my $regex= $triggers."module del (.+)";
	my $count;
	my @return;

	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();

	if($count > 0)
	{
		my ($name) = $what=~/$regex/;
		if (!$name)
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$name".'[/c] non retiré ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}
	 	else 
		{
			$sth=$dbh->prepare("DELETE FROM modules WHERE name=?");
			$sth->execute($name);
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$name.'[/c] retiré !'};
			push(@return,$ligne);
		}
	}
	return @return

}

sub bot_list_module {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("SELECT name,autorun,session,loaded FROM modules");
	my $regex= $triggers."module list";
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
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges >= 10000");
	my $count;
	my @return;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	my $regex= $triggers."quit (\\S.*)";
	if($count > 0)
	{
		my $reason="All your bot are belong to us";
		if($what=~/$regex/ )
		{
			$reason=$1;
		}
		Giraf::Modules::Admin::on_bot_quit($reason);
	}
	return @return
}

1;
