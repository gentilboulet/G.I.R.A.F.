#! /usr/bin/perl
$|=1 ;
package Urls;
use DBI;
use List::Util qw[min max];

our $dbh;

sub init {
	my ($kernel,$irc) = @_;
	$Admin::public_functions->{bot_list_urls}={function=>\&bot_list_urls,regex=>'urls.*'};
	$Admin::public_parsers->{bot_add_urls}={function=>\&bot_add_urls,regex=>'((((https?|ftp):\/\/)|www\.)(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)|localhost|([a-zA-Z0-9\-]+\.)*[a-zA-Z0-9\-]+\.(com|net|org|info|biz|gov|name|edu|[a-zA-Z][a-zA-Z]))(:[0-9]+)?((\/|\?)[^ "]*[^ ,;\.:">)])?)'};
	$dbh=DBI->connect("dbi:SQLite:dbname=Modules/db/urls.db","","");
	$dbh->do("BEGIN TRANSACTION;");
	$dbh->do("CREATE TABLE urls (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, date TEXT, url TEXT);");
	$dbh->do("COMMIT;");
}

sub bot_list_urls {
	my($nick, $dest, $what)=@_;
	my @return;
	my $sth=$dbh->prepare("SELECT user,channel,date,url FROM urls WHERE channel LIKE ? ORDER BY -id LIMIT 0,?");
	my ($usr,$channel,$date,$url);
	print "list_urls !!";
	$sth->bind_columns( \$usr, \$channel , \$date, \$url );
	if( my ($search) = $what =~/urls search (.*)/ )
	{
		my $sth2=$dbh->prepare("SELECT user,channel,date,url FROM urls WHERE urls LIKE ? OR  user LIKE ? LIMIT 0,10");
		$sth2->bind_columns( \$usr, \$channel , \$date, \$url );
		$sth2->execute($search,$search);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}elsif( my ($search,$num) = $what =~/urls search (.*) (\d*)/ )
	{
		my $sth2=$dbh->prepare("SELECT user,channel,date,url FROM urls WHERE urls LIKE %?% OR  user LIKE %?% LIMIT 0,?");
		$sth2->bind_columns( \$usr, \$channel , \$date, \$url );
		$sth2->execute($search,$search,$num);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}
	elsif( my ($chan) = $what =~/urls (#.*)/ )
	{
		print 1;
		$sth->execute($chan,5);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}
	elsif ( my ($num,$chan) = $what =~/urls (\d*) (#.*)/ )
	{
		print 2;
		$sth->execute($chan,min($num,10));
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}
	elsif ( my ($num) = $what =~/urls (\d+)/)
	{
		print 3;
		$sth->execute($dest,min($num,10));
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$dest."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}
	} 
	elsif ( $what =~/urls.*/ )
	{
		print 4;
		$sth->execute($dest,1);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$dest."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}
	}
	print 5;
	return @return;
}

sub bot_add_urls {
	my($nick, $dest, $what)=@_;
	print "ajout url !!";
	my $regex=$Admin::public_parsers->{bot_add_urls}->{regex};
	my ($url) = $what=~/$regex/ ;
	my $sth=$dbh->prepare("INSERT INTO urls (url,user,channel,date) VALUES (?,?,?,datetime('now','localtime'));");
	$sth->execute($url,$nick,$dest);
	my @return;
	return @return;
}



1;
