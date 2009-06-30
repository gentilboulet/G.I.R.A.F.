#! /usr/bin/perl
$| = 1;

package Admin;
use Chan;
use Reload;
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
our $module_list;
our $dbh;


sub init_sessions {

	$dbh=DBI->connect("dbi:SQLite:dbname=db/modules.db","","");
	my $sth=$dbh->prepare("SELECT file,name FROM modules WHERE session>0");
        my ($module, $module_name);
        $sth->bind_columns( \$module, \$module_name );
        $sth->execute();
        while($sth->fetch() )
        {
		require($module);
	       #eval "&".$module_name.'::init_session();';
        }

}

sub init {
	my ( $classe, $ker, $irc_session, $set_triggers) = @_;
	$kernel  = $ker;
	$irc     = $irc_session;
	$triggers=$set_triggers;
	$public_functions->{bot_say}={function=>\&bot_say,regex=>'say (.*)'};
	$public_functions->{bot_do}={function=>\&bot_do,regex=>'do (.*)'};
	$public_functions->{bot_load_module}={function=>\&bot_load_module,regex=>'load (.*)'};
	$public_functions->{bot_add_module}={function=>\&bot_add_module,regex=>'add module (.*)'};
	$public_functions->{bot_quit}={function=>\&bot_quit,regex=>'quit (.*)'};

        $dbh=DBI->connect("dbi:SQLite:dbname=db/modules.db","","");
	$dbh->do("CREATE TABLE modules (autorun NUMERIC, file TEXT, name TEXT,session NUMERIC);");
	$dbh->do("CREATE TABLE users (name TEXT PRIMARY KEY, privileges NUMERIC);");
	$dbh->do("INSERT  INTO users(name,privileges) VALUES('GentilBoulet',0);");

	my $sth=$dbh->prepare("SELECT file,name FROM modules WHERE autorun>0");
	my ($module, $module_name);
	$sth->bind_columns( \$module, \$module_name );
	$sth->execute();
	while($sth->fetch() )
	{
		require($module);
		eval "&".$module_name.'::init($Admin::kernel,$Admin::irc_session);';
	}
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

sub reload_modules
{
	Reload->check;

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
			push(@return,$element->{function}->($nick,$channel,$what));
		}
	}
	return @return;

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

sub bot_load_module {
	my($nick, $dest, $what)=@_;
	my @return;
	my $regex= $triggers."load (.*)";
	my $sth=$dbh->prepare("SELECT COUNT(*),file,name FROM modules WHERE name LIKE ?");
	my ($count,$module,$module_name);
	$sth->bind_columns( \$count, \$module , \$module_name);
	if( my ($txt) = $what=~/$regex/ )
	{
		$sth->execute($txt);
		$sth->fetch();
		if($count > 0)
		{
			require($module);
			eval "&".$module_name.'::init($Admin::kernel,$Admin::irc_session);';
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] chargé !'};
			push(@return,$ligne);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'.$txt.'[/c] non trouve !'};
			push(@return,$ligne);
		}
	}
	return @return;
}


sub bot_add_module {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges < 1");
	my $regex= $triggers."add module (.*) (.*\.pm) ([0-9]*)";
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
			if( -e "./Modules/".$file )
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
			$ligne={ action =>"MSG",dest=>$dest,msg=>'Module [c=red]'."$name $file $autorun".'[/c] non ajoute ! Ligne indechiffrable !'};
			push(@return,$ligne);
		}

	}
	return @return
}

sub bot_quit {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("SELECT COUNT(*) FROM users WHERE name LIKE ? AND privileges < 1");
	my $count;
	my @return;
	$sth->bind_columns( \$count);
	$sth->execute($nick);
	$sth->fetch();
	my $regex= $triggers."quit (.*)";
	if($count > 0)
	{
		if( my ($reason) = $what=~/$regex/ )
		{
			$kernel->signal( $kernel, 'POCOIRC_SHUTDOWN', $reason );
		}
		else
		{
			$reason="All your bot is belong to us";
			$kernel->signal( $kernel, 'POCOIRC_SHUTDOWN', $reason );
		}
	}
	$sth=$dbh->prepare("SELECT name FROM modules");
        my ($module_name);
        $sth->bind_columns( \$module_name);
        $sth->execute();
        while($sth->fetch() )
        {
		eval "&".$module_name.'::quit();'
        }

	return @return
}

1;
