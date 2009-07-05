#! /usr/bin/perl
$|=1 ;

package Giraf::Modules::Karma;

use DBI;
use List::Util qw[min max];

our $dbh;

sub init {
	my ($kernel,$irc) = @_;
	$Admin::public_functions->{bot_get_karma}={function=>\&bot_get_karma,regex=>'karma.*'};
	$Admin::public_parsers->{bot_karma_plusplus}={function=>\&bot_karma_pp,regex=>'(\w+)\+\+'};
	$Admin::public_parsers->{bot_karma_moinsmoins}={function=>\&bot_karma_mm,regex=>'(\w+)--'};

	$dbh=DBI->connect("dbi:SQLite:dbname=Modules/DB/karma.db","","");
	$dbh->do("BEGIN TRANSACTION;");
	$dbh->do("CREATE TABLE karma (karma INTEGER , keyword TEXT UNIQUE);");
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
	my $sth=$dbh->prepare("SELECT karma FROM karma WHERE keyword LIKE ?");
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
	my $sth=$dbh->prepare("INSERT INTO karma (keyword,karma) VALUES (?,0);");
	my ($kw) = $what =~/(\w+)\+\+/ ;
	if($nick ne $kw)
	{
		$sth->execute($kw);
		$sth=$dbh->prepare("UPDATE karma SET karma=karma+1 WHERE keyword LIKE ?");
		$sth->execute($kw);
	}
	return @return;
}

sub bot_karma_mm {
	my($nick, $dest, $what)=@_;
	my $sth=$dbh->prepare("INSERT INTO karma (keyword,karma) VALUES (?,0);");
	my ($kw) = $what =~/(\w+)--/ ;
	if($nick ne $kw)
	{
		$sth->execute($kw);
		$sth=$dbh->prepare("UPDATE karma SET karma=karma-1 WHERE keyword LIKE ?");
		$sth->execute($kw);
	}
	return @return;
}


sub quit {
	$dbh->disconnect();
}

1;
