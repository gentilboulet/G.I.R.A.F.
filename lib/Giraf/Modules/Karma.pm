#! /usr/bin/perl
$|=1 ;

package Giraf::Modules::Karma;

use strict;
use warnings;

use Giraf::Config;

use DBI;
use List::Util qw[min max];

our $dbh;

my $tbl_karm = 'mod_karma_karma';

sub init {
	my ($kernel,$irc) = @_;
	$Admin::public_functions->{bot_get_karma}={function=>\&bot_get_karma,regex=>'karma.*'};
	$Admin::public_parsers->{bot_karma_plusplus}={function=>\&bot_karma_pp,regex=>'(\w+)\+\+'};
	$Admin::public_parsers->{bot_karma_moinsmoins}={function=>\&bot_karma_mm,regex=>'(\w+)--'};

	$dbh=DBI->connect(Giraf::Config::get('dbsrc'), Giraf::Config::get('dbuser'), Giraf::Config::get('dbpass'));
	$dbh->do("BEGIN TRANSACTION;");
	$dbh->do("CREATE TABLE $tbl_karma (karma INTEGER , keyword TEXT UNIQUE);");
	$dbh->do("COMMIT;");
}

sub unload {
	delete($Admin::public_functions->{bot_get_karma});
	delete($Admin::public_parsers->{bot_karma_plusplus});
	delete($Admin::public_parsers->{bot_karma_moinsmoins});
}

sub bot_get_karma 
{
	my($nick, $dest, $what)=@_;
	my @return;
	my $karma;
	my $sth=$dbh->prepare("SELECT karma FROM $tbl_$tbl_karma WHERE keyword LIKE ?");
	$sth->bind_columns( \$karma );
	if( my ($kw) = $what =~/karma show (\w+).*/)
	{
		$sth->execute($kw);
		$sth->fetch();
		if($karma>0 || $karma <0)
		{
			my $color;
			my $adj;
			if($karma >0)
			{
				$color="green";
				$adj="bon";

			}
			else
			{
				$color="red";
				$adj="mauvais";
			}
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=$color]".$kw."[/c] a un $adj karma ($karma) !"};
			push(@return,$ligne);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"$kw a un karma neutre !"};
			push(@return,$ligne);
		}

	}
	elsif( my ($kw) = $what =~/karma (\w+).*/ )
	{
		$sth->execute($kw);
		$sth->fetch();
		if($karma>0 || $karma <0)
		{
			my $color;
			my $adj;
			if($karma >0)
			{
				$color="green";
				$adj="bon";

			}
			else
			{
				$color="red";
				$adj="mauvais";
			}
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"[c=$color]".$kw."[/c] a un $adj karma !"};
			push(@return,$ligne);
		}
		else
		{
			my $ligne={ action =>"MSG",dest=>$dest,msg=>"$kw a un karma neutre !"};
			push(@return,$ligne);
		}

	}
	return @return;
}

sub bot_karma_pp {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("INSERT INTO $tbl_karma (keyword,karma) VALUES (?,0);");
	my ($kw) = $what =~/(\w+)\+\+/ ;
	if($nick ne $kw)
	{
		$sth->execute($kw);
		$sth=$dbh->prepare("UPDATE $tbl_karma SET karma=karma+1 WHERE keyword LIKE ?");
		$sth->execute($kw);
	}
	return @return;
}

sub bot_karma_mm {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("INSERT INTO $tbl_karma (keyword,karma) VALUES (?,0);");
	my ($kw) = $what =~/(\w+)--/ ;
	if($nick ne $kw)
	{
		$sth->execute($kw);
		$sth=$dbh->prepare("UPDATE $tbl_karma SET karma=karma-1 WHERE keyword LIKE ?");
		$sth->execute($kw);
	}
	return @return;
}


sub quit {
	$dbh->disconnect();
}

1;
