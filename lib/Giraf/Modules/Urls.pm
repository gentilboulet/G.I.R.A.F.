#! /usr/bin/perl
$|=1 ;

package Giraf::Modules::Urls;

use strict;
use warnings;

use Giraf::Admin;
use Giraf::Config;

use DBI;
use List::Util qw[min max];

our $version=1;
# Private vars
our $_dbh;
our $_tbl_urls = 'mod_urls_urls';

sub init {
	my ($kernel,$irc) = @_;
	$Giraf::Admin::public_functions->{bot_list_urls}={function=>\&bot_list_urls,regex=>'urls.*'};
	$Giraf::Admin::public_parsers->{bot_add_urls}={function=>\&bot_add_urls,regex=>'((((https?|ftp):\/\/)|www\.)(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)|localhost|([a-zA-Z0-9\-]+\.)*[a-zA-Z0-9\-]+\.(com|net|org|info|biz|gov|name|edu|[a-zA-Z][a-zA-Z]))(:[0-9]+)?((\/|\?)[^ "]*[^ ,;\.:">)])?)'};
	$_dbh=DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	$_dbh->do("BEGIN TRANSACTION;");
	$_dbh->do("CREATE TABLE $_tbl_urls (id INTEGER PRIMARY KEY, user TEXT, channel TEXT, date TEXT, url TEXT);");
	$_dbh->do("COMMIT;");
}

sub unload {
	delete($Giraf::Admin::public_functions->{bot_list_urls});
	delete($Giraf::Admin::public_parsers->{bot_add_urls});
}

sub bot_list_urls {
	my($nick, $dest, $what)=@_;
	my @return;
	my $sth=$_dbh->prepare("SELECT user,channel,date,url FROM $_tbl_urls WHERE channel LIKE ? ORDER BY -id LIMIT 0,?");
	my ($usr,$channel,$date,$url);
	$sth->bind_columns( \$usr, \$channel , \$date, \$url );
	if( my ($search) = $what =~/urls search (.*)/ )
	{
		my $sth2=$_dbh->prepare("SELECT user,channel,date,url FROM $_tbl_urls WHERE urls LIKE ? OR  user LIKE ? LIMIT 0,10");
		$sth2->bind_columns( \$usr, \$channel , \$date, \$url );
		$sth2->execute($search,$search);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}elsif( my ($search,$num) = $what =~/urls search (.*) (\d*)/ )
	{
		my $sth2=$_dbh->prepare("SELECT user,channel,date,url FROM $_tbl_urls WHERE urls LIKE %?% OR  user LIKE %?% LIMIT 0,?");
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
		$sth->execute($chan,5);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}
	elsif ( my ($num,$chan) = $what =~/urls (\d*) (#.*)/ )
	{
		$sth->execute($chan,min($num,10));
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$chan."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}

	}
	elsif ( my ($num) = $what =~/urls (\d+)/)
	{
		$sth->execute($dest,min($num,10));
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$dest."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}
	} 
	elsif ( $what =~/urls.*/ )
	{
		$sth->execute($dest,1);
		while($sth->fetch())
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>'['.$date.']'." [c=navy_blue]".$dest."[/c] [c=green]<$usr>[/c] $url"};
			push(@return,$ligne);
		}
	}
	return @return;
}

sub bot_add_urls {
	my($nick, $dest, $what)=@_;
	my $regex=$Admin::public_parsers->{bot_add_urls}->{regex};
	my ($url) = $what=~/$regex/ ;
	my $sth=$_dbh->prepare("INSERT INTO $_tbl_urls (url,user,channel,date) VALUES (?,?,?,datetime('now','localtime'));");
	$sth->execute($url,$nick,$dest);
	my @return;
	return @return;
}



1;
