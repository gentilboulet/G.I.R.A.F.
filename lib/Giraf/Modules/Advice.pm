#! /usr/bin/perl
$|=1 ;
package Giraf::Modules::Advice;
use DBI;

our $dbh;
our $advices;

sub init {
	my ($kernel,$irc) = @_;
	$dbh=DBI->connect("dbi:SQLite:dbname=Modules/DB/Advice.db","","");
	$dbh->do("BEGIN TRANSACTION;");
	$dbh->do("CREATE TABLE IF NOT EXISTS tmp (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, infoId INTEGER REFERENCES infos (id), advice TEXT UNIQUE)");
	$dbh->do("CREATE TABLE IF NOT EXISTS infos (id INTEGER PRIMARY KEY, name TEXT UNIQUE, regex TEXT UNIQUE, color TEXT DEFAULT 'teal')");
	$dbh->do("CREATE TABLE IF NOT EXISTS advices (id INTEGER PRIMARY KEY, typeId INTEGER, advice TEXT UNIQUE, infoId INTEGER REFERENCES infos (id))");
	$dbh->do("INSERT OR REPLACE INTO infos (id,name,regex,color) VALUES (1,'Courage Wolf','couragewolf','red')");
	$dbh->do("COMMIT;");
	$advices->{regex}="advice";
	my $sth=$dbh->prepare("SELECT id,name,regex,color FROM infos");
	my ($id,$name,$regex,$color);
	$sth->bind_columns(\$id,\$name,\$regex,\$color);
	$sth->execute();
	while($sth->fetch())
	{
		$advices->{regex}=$advices->{regex}."|".$regex;
		$advices->{$id}={name=>$name,regex=>$regex,color=>$color};
	}
	$Admin::public_functions->{bot_advice}={function=>\&bot_advice,regex=>$advices->{regex}.'(\s+(\d+))?'};
	$Admin::public_functions->{bot_advice_suggest}={function=>\&bot_advice_suggest,regex=>$advices->{regex}.'\s+suggest\s+.+'};
	$Admin::public_functions->{bot_advice_validate}={function=>\&bot_advice_validate,regex=>$advices->{regex}.'\s+validate(\s+(\d+))?'};
	$Admin::public_functions->{bot_advice_stats}={function=>\&bot_advice_stats,regex=>'advice\s+stats'};
#	$Admin::public_functions->{bot_advice_new}={function=>\&bot_advice_new,regex=>'advice\s(.+)'};
}

sub unload {
	delete($Admin::public_functions->{bot_advice});
	delete($Admin::public_functions->{bot_advice_suggest});
	delete($Admin::public_functions->{bot_advice_validate});
	delete($Admin::public_functions->{bot_advice_stats});
#	delete($Admin::public_functions->{bot_advice_new});
}

sub bot_advice_new {
        my($nick, $dest, $what)=@_;
        my @return;
#	my $ligne= {action =>"MSG",dest=>$dest,msg=>'[b]'.$titleNoFormatting.'[/b] - [c=teal]'.json_decode($unescapedUrl).'[/c]'};
	push(@return,$ligne);
	return @return;

}


sub bot_advice {
        my($nick, $dest, $what)=@_;
        my @return;
	my $ligne;
	my $regex=$triggers.'advice(\s+(\d+))?';
	if($what=~/$regex$/)
	{
		my $adid;
		my $regex=$triggers.'advice\s+(\d+)';
		if($what=~/$regex$/)
		{
			$adid=$1;
		}
		else
		{
			my $sth=$dbh->prepare("SELECT COUNT(*) FROM advices");
			$sth->bind_columns(\$count);
			$sth->execute();
			$sth->fetch();
			$adid=POSIX::floor(rand($count))+1; #1<=Id<=N
		}
		$sth=$dbh->prepare("SELECT typeId,advice,infoId FROM advices WHERE id=?");
		my ($typeid,$advice,$infoId);
		$sth->bind_columns(\$typeid,\$advice,\$infoId);
		$sth->execute($adid);
		if($sth->fetch())
		{
			$ligne={ action=> "MSG",dest=>$dest,msg=> "Advice [c=yellow]".$adid."[/c] ([c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}."[/c] [c=yellow]".$typeid."[/c]) : [c=".$advices->{$infoId}->{color}."]".$advice."[/c]"};
			push(@return,$ligne);
		}
		else
		{
			$ligne={ action =>"MSG",dest=>$dest,msg=>"no advice for U ! (not found)"};
			push(@return,$ligne);
		}
	}
	else
	{
		foreach $id (sort keys %$advices) 
		{
			$regex=$triggers.$advices->{$id}->{regex}.'(\s+(\d+))?';
			if ($id!='regex' and $what=~/$regex$/)
			{
				my $adid;
				my $rgx=$triggers.$advices->{$id}->{regex}.'\s+(\d+)';
				if($what=~/$rgx$/)
				{
					$adid=$1;
				}
				else
				{
					my $sth=$dbh->prepare("SELECT COUNT(*) FROM advices WHERE infoId=?");
					$sth->bind_columns(\$count);
					$sth->execute($id);
					$sth->fetch();
					$adid=POSIX::floor(rand($count))+1; #1<=Id<=N
				}
				$sth=$dbh->prepare("SELECT id,advice,infoId FROM advices WHERE infoId=? and typeId=?");
				my ($totalid,$advice,$infoId);
				$sth->bind_columns(\$totalid,\$advice,\$infoId);
				$sth->execute($id,$adid);
				if($sth->fetch())
				{
					$ligne={ action=> "MSG",dest=>$dest,msg=> "[c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}."[/c] [c=yellow]".$adid."[/c] (Advice [c=yellow]".$totalid."[/c]) : [c=".$advices->{$infoId}->{color}."]".$advice."[/c]"};
					push(@return,$ligne);
				}
				else
				{
					$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$advices->{$id}->{name}." for U ! (not found)"};
					push(@return,$ligne);
				}
			}
		}

	}
	return @return;

}


sub bot_advice_suggest {
	my($nick, $dest, $what)=@_;
	my @return;
	my $ligne;
	foreach $id (sort keys %$advices) 
	{
		$regex=$triggers.$advices->{$id}->{regex}.'\s+suggest\s+(.+)';
		if ($id!='regex' and $what=~/$regex/)
		{
			my $sth=$dbh->prepare("INSERT INTO tmp (user,channel,infoId,advice) VALUES (?,?,?,?)");
			$sth->execute($nick,$dest,$id,$1);
			if($sth->rows()>0)
			{
				$ligne={ action=> "MSG",dest=>$dest,msg=> "[c=".$advices->{$id}->{color}."]".$advices->{$id}->{name}."[/c] added !"};
				push(@return,$ligne);
			}
			else
			{
				$ligne={ action =>"MSG",dest=>$dest,msg=>"Problem occured"};
				push(@return,$ligne);
			}
		}

	}
	return @return;

}


sub bot_advice_validate {
	my($nick, $dest, $what)=@_;
	my @return;
	my $ligne;
	my $regex=$triggers.'advice\s+validate(\s+(\d+))?';
#	$dbh->do("CREATE TABLE IF NOT EXISTS tmp (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, infoId INTEGER REFERENCES infos (id), advice TEXT UNIQUE)");	
	my ($advice,$infoId,$typeId);
	if($what=~/$regex$/)
	{
		my $adid;
		my $regex=$triggers.'advice\s+validate\s+(\d+)';
		if($what=~/$regex$/)
		{
			my $tmpid=$1;
			#Number to validate
			my $sth=$dbh->prepare("SELECT infoId,advice FROM tmp WHERE id=?");
			$sth->bind_columns(\$infoId,\$advice);
			$sth->execute($tmpid);
			if($sth->fetch())
			{
				$sth=$dbh->prepare("SELECT COUNT(*) FROM advices WHERE infoId=?");
				$sth->bind_columns(\$typeId);
				$sth->execute($infoId);
				$sth->fetch();
				$typeId++;
				$dbh->do("BEGIN TRANSACTION");
				$sth=$dbh->prepare("INSERT INTO advices (typeId,advice,infoId)VALUES(?,?,?)");
				$sth->execute($typeId,$advice,$infoId);
				$sth=$dbh->prepare("DELETE FROM tmp WHERE id=?");
				$sth->execute($tmpid);
				$dbh->do("COMMIT");
				$ligne={action =>"MSG",dest=>$dest,msg=>"Advice validated ([c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}."[/c] ".$typeId.")"};
				push(@return,$ligne);

			}
			else
			{
				$ligne={ action =>"MSG",dest=>$dest,msg=>"no advice to validate for U ! (not found)"};
				push(@return,$ligne);
			}
		}
		else
		{
			my ($tmpid,$tmpwho,$tmpwhere);
			my $sth=$dbh->prepare("SELECT id,infoId,advice,user,channel FROM tmp");
			$sth->bind_columns(\$tmpid,\$infoId,\$advice,\$tmpwho,\$tmpwhere);
			$sth->execute();
			my $count=0;
			while($sth->fetch())
			{
				$count++;
				$ligne={action=>"MSG",dest=>$dest,msg=>"[c=yellow]".$tmpid."[/c] - [c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}." : ".$advice."[/c] by ".$tmpwho." @ ".$tmpwhere};
				push(@return,$ligne);
			}

			if($count==0)
			{
				$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$advices->{$id}->{name}." to validate for U ! (not found)"};
				push(@return,$ligne);
			}

		}		
	}
	else
	{
		foreach $id (sort keys %$advices) 
		{
			$regex=$triggers.$advices->{$id}->{regex}.'\s+validate(\s+(\d+))?';
			if ($id!='regex' and $what=~/$regex$/)
			{
				my $rgx=$triggers.$advices->{$id}->{regex}.'\s+validate\s+(\d+)';
				if($what=~/$rgx$/)
				{
					my $tmpid=$1;
					#Number to validate
					my $sth=$dbh->prepare("SELECT infoId,advice FROM tmp WHERE id=?");
					$sth->bind_columns(\$infoId,\$advice);
					$sth->execute($tmpid);
					if($sth->fetch())
					{
						$sth=$dbh->prepare("SELECT COUNT(*) FROM advices WHERE infoId=?");
						$sth->bind_columns(\$typeId);
						$sth->execute($infoId);
						$sth->fetch();
						$typeId++;
						$dbh->do("BEGIN TRANSACTION");
						$sth=$dbh->prepare("INSERT INTO advices (typeId,advice,infoId)VALUES(?,?,?)");
						$sth->execute($typeId,$advice,$infoId);
						$sth=$dbh->prepare("DELETE FROM tmp WHERE id=?");
						$sth->execute($tmpid);
						$dbh->do("COMMIT");
						$ligne={action =>"MSG",dest=>$dest,msg=>"Advice validated ([c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}."[/c] $typeId)"};
						push(@return,$ligne);

					}
					else
					{
						$ligne={ action =>"MSG",dest=>$dest,msg=>"no advice to validate for U ! (not found)"};
						push(@return,$ligne);
					}

				}
				else
				{
					my $sth=$dbh->prepare("SELECT id,infoId,advice,user,channel FROM tmp WHERE infoId=?");
					my ($tmpid,$tmpwho,$tmpwhere);
					$sth->bind_columns(\$tmpid,\$infoId,\$advice,\$tmpwho,\$tmpwhere);
					$sth->execute($id);
					my $count=0;


					while($sth->fetch())
					{
						$count++;
						$ligne={action=>"MSG",dest=>$dest,msg=>"[c=yellow]".$tmpid."[/c] - [c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}." : ".$advice."[/c] by ".$tmpwho." @ ".$tmpwhere};
						push(@return,$ligne);
					}

					if($count==0)
					{
						$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$advices->{$id}->{name}." to validate for U ! (not found)"};
						push(@return,$ligne);
					}
				}
			}
		}

	}
	return @return;

}


sub bot_advice_stats {
	my($nick, $dest, $what)=@_;
	my @return;
	my ($ligne,$count,$infoId,$output);
	$i=0;
	$output="Advice bot stats : ";
	my $sth=$dbh->prepare("SELECT COUNT(*),infoId FROM advices GROUP BY (infoId);");
	$sth->bind_columns(\$count,\$infoId);
	$sth->execute();
	while($sth->fetch())
	{
		$i++;
		$output=$output."[c=".$advices->{$infoId}->{color}."]".$advices->{$infoId}->{name}."[/c] - [c=yellow]".$count."[/c];";
	}

	if($i>0)
	{
		$ligne={ action=> "MSG",dest=>$dest,msg=> $output};
		push(@return,$ligne);
	}
	else
	{
		$ligne={ action =>"MSG",dest=>$dest,msg=>"Problem occured"};
		push(@return,$ligne);
	}
	return @return;

}

1;
