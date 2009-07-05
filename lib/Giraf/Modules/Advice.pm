#! /usr/bin/perl
$|=1 ;
package Giraf::Modules::Advice;

use strict;
use warnings;

use Giraf::Config;

use DBI;

# Private vars
our $_dbh;
our $_advices;
our $_tbl_advices = 'mod_advice_advices';
our $_tbl_infos = 'mod_advice_infos';
our $_tbl_tmp = 'mod_advice_tmp';

sub init {
	my ($kernel,$irc) = @_;
	$_dbh=DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE IF NOT EXISTS tmp (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, infoId INTEGER REFERENCES infos (id), advice TEXT UNIQUE)");
	$_dbh->do("CREATE TABLE IF NOT EXISTS infos (id INTEGER PRIMARY KEY, name TEXT UNIQUE, regex TEXT UNIQUE, color TEXT DEFAULT 'teal')");
	$_dbh->do("CREATE TABLE IF NOT EXISTS advices (id INTEGER PRIMARY KEY, typeId INTEGER, advice TEXT UNIQUE, infoId INTEGER REFERENCES infos (id))");
	$_dbh->do("INSERT OR REPLACE INTO $_tbl_infos (id,name,regex,color) VALUES (1,'Courage Wolf','couragewolf','red')");
	$_dbh->do("COMMIT;");
	$_advices->{regex}="advice";
	my $sth=$_dbh->prepare("SELECT id,name,regex,color FROM $_tbl_infos");
	my ($id,$name,$regex,$color);
	$sth->bind_columns(\$id,\$name,\$regex,\$color);
	$sth->execute();
	while($sth->fetch())
	{
		$_advices->{regex}=$_advices->{regex}."|".$regex;
		$_advices->{$id}={name=>$name,regex=>$regex,color=>$color};
	}
	$Admin::public_functions->{bot_advice}={function=>\&bot_advice,regex=>$_advices->{regex}.'(\s+(\d+))?'};
	$Admin::public_functions->{bot_advice_suggest}={function=>\&bot_advice_suggest,regex=>$_advices->{regex}.'\s+suggest\s+.+'};
	$Admin::public_functions->{bot_advice_validate}={function=>\&bot_advice_validate,regex=>$_advices->{regex}.'\s+validate(\s+(\d+))?'};
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
			my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_advices");
			$sth->bind_columns(\$count);
			$sth->execute();
			$sth->fetch();
			$adid=POSIX::floor(rand($count))+1; #1<=Id<=N
		}
		$sth=$_dbh->prepare("SELECT typeId,advice,infoId FROM $_tbl_advices WHERE id=?");
		my ($typeid,$advice,$infoId);
		$sth->bind_columns(\$typeid,\$advice,\$infoId);
		$sth->execute($adid);
		if($sth->fetch())
		{
			$ligne={ action=> "MSG",dest=>$dest,msg=> "Advice [c=yellow]".$adid."[/c] ([c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}."[/c] [c=yellow]".$typeid."[/c]) : [c=".$_advices->{$infoId}->{color}."]".$advice."[/c]"};
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
		foreach $id (sort keys %$_advices) 
		{
			$regex=$triggers.$_advices->{$id}->{regex}.'(\s+(\d+))?';
			if ($id!='regex' and $what=~/$regex$/)
			{
				my $adid;
				my $rgx=$triggers.$_advices->{$id}->{regex}.'\s+(\d+)';
				if($what=~/$rgx$/)
				{
					$adid=$1;
				}
				else
				{
					my $sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_advices WHERE infoId=?");
					$sth->bind_columns(\$count);
					$sth->execute($id);
					$sth->fetch();
					$adid=POSIX::floor(rand($count))+1; #1<=Id<=N
				}
				$sth=$_dbh->prepare("SELECT id,advice,infoId FROM $_tbl_advices WHERE infoId=? and typeId=?");
				my ($totalid,$advice,$infoId);
				$sth->bind_columns(\$totalid,\$advice,\$infoId);
				$sth->execute($id,$adid);
				if($sth->fetch())
				{
					$ligne={ action=> "MSG",dest=>$dest,msg=> "[c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}."[/c] [c=yellow]".$adid."[/c] (Advice [c=yellow]".$totalid."[/c]) : [c=".$_advices->{$infoId}->{color}."]".$advice."[/c]"};
					push(@return,$ligne);
				}
				else
				{
					$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$_advices->{$id}->{name}." for U ! (not found)"};
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
	foreach $id (sort keys %$_advices) 
	{
		$regex=$triggers.$_advices->{$id}->{regex}.'\s+suggest\s+(.+)';
		if ($id!='regex' and $what=~/$regex/)
		{
			my $sth=$_dbh->prepare("INSERT INTO $_tbl_tmp (user,channel,infoId,advice) VALUES (?,?,?,?)");
			$sth->execute($nick,$dest,$id,$1);
			if($sth->rows()>0)
			{
				$ligne={ action=> "MSG",dest=>$dest,msg=> "[c=".$_advices->{$id}->{color}."]".$_advices->{$id}->{name}."[/c] added !"};
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
#	$_dbh->do("CREATE TABLE IF NOT EXISTS tmp (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, infoId INTEGER REFERENCES infos (id), advice TEXT UNIQUE)");	
	my ($advice,$infoId,$typeId);
	if($what=~/$regex$/)
	{
		my $adid;
		my $regex=$triggers.'advice\s+validate\s+(\d+)';
		if($what=~/$regex$/)
		{
			my $tmpid=$1;
			#Number to validate
			my $sth=$_dbh->prepare("SELECT infoId,advice FROM $_tbl_tmp WHERE id=?");
			$sth->bind_columns(\$infoId,\$advice);
			$sth->execute($tmpid);
			if($sth->fetch())
			{
				$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_advices WHERE infoId=?");
				$sth->bind_columns(\$typeId);
				$sth->execute($infoId);
				$sth->fetch();
				$typeId++;
				$_dbh->do("BEGIN TRANSACTION");
				$sth=$_dbh->prepare("INSERT INTO $_tbl_advices (typeId,advice,infoId)VALUES(?,?,?)");
				$sth->execute($typeId,$advice,$infoId);
				$sth=$_dbh->prepare("DELETE FROM $_tbl_tmp WHERE id=?");
				$sth->execute($tmpid);
				$_dbh->do("COMMIT");
				$ligne={action =>"MSG",dest=>$dest,msg=>"Advice validated ([c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}."[/c] ".$typeId.")"};
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
			my $sth=$_dbh->prepare("SELECT id,infoId,advice,user,channel FROM $_tbl_tmp");
			$sth->bind_columns(\$tmpid,\$infoId,\$advice,\$tmpwho,\$tmpwhere);
			$sth->execute();
			my $count=0;
			while($sth->fetch())
			{
				$count++;
				$ligne={action=>"MSG",dest=>$dest,msg=>"[c=yellow]".$tmpid."[/c] - [c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}." : ".$advice."[/c] by ".$tmpwho." @ ".$tmpwhere};
				push(@return,$ligne);
			}

			if($count==0)
			{
				$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$_advices->{$id}->{name}." to validate for U ! (not found)"};
				push(@return,$ligne);
			}

		}		
	}
	else
	{
		foreach $id (sort keys %$_advices) 
		{
			$regex=$triggers.$_advices->{$id}->{regex}.'\s+validate(\s+(\d+))?';
			if ($id!='regex' and $what=~/$regex$/)
			{
				my $rgx=$triggers.$_advices->{$id}->{regex}.'\s+validate\s+(\d+)';
				if($what=~/$rgx$/)
				{
					my $tmpid=$1;
					#Number to validate
					my $sth=$_dbh->prepare("SELECT infoId,advice FROM $_tbl_tmp WHERE id=?");
					$sth->bind_columns(\$infoId,\$advice);
					$sth->execute($tmpid);
					if($sth->fetch())
					{
						$sth=$_dbh->prepare("SELECT COUNT(*) FROM $_tbl_advices WHERE infoId=?");
						$sth->bind_columns(\$typeId);
						$sth->execute($infoId);
						$sth->fetch();
						$typeId++;
						$_dbh->do("BEGIN TRANSACTION");
						$sth=$_dbh->prepare("INSERT INTO $_tbl_advices (typeId,advice,infoId)VALUES(?,?,?)");
						$sth->execute($typeId,$advice,$infoId);
						$sth=$_dbh->prepare("DELETE FROM $_tbl_tmp WHERE id=?");
						$sth->execute($tmpid);
						$_dbh->do("COMMIT");
						$ligne={action =>"MSG",dest=>$dest,msg=>"Advice validated ([c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}."[/c] $typeId)"};
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
					my $sth=$_dbh->prepare("SELECT id,infoId,advice,user,channel FROM $_tbl_tmp WHERE infoId=?");
					my ($tmpid,$tmpwho,$tmpwhere);
					$sth->bind_columns(\$tmpid,\$infoId,\$advice,\$tmpwho,\$tmpwhere);
					$sth->execute($id);
					my $count=0;


					while($sth->fetch())
					{
						$count++;
						$ligne={action=>"MSG",dest=>$dest,msg=>"[c=yellow]".$tmpid."[/c] - [c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}." : ".$advice."[/c] by ".$tmpwho." @ ".$tmpwhere};
						push(@return,$ligne);
					}

					if($count==0)
					{
						$ligne={ action =>"MSG",dest=>$dest,msg=>"no ".$_advices->{$id}->{name}." to validate for U ! (not found)"};
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
	my $sth=$_dbh->prepare("SELECT COUNT(*),infoId FROM $_tbl_advices GROUP BY (infoId);");
	$sth->bind_columns(\$count,\$infoId);
	$sth->execute();
	while($sth->fetch())
	{
		$i++;
		$output=$output."[c=".$_advices->{$infoId}->{color}."]".$_advices->{$infoId}->{name}."[/c] - [c=yellow]".$count."[/c];";
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
