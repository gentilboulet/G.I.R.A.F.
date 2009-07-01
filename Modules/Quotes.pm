#! /usr/bin/perl
$|=1 ;
package Quotes;
use DBI;

our $dbh;

sub init {
	my ($kernel,$irc) = @_;
	#$Admin::public_functions->{bot_get_quote}={function=>\&bot_get_karma,regex=>'karma.*'};
	#$Admin::public_parsers->{bot_karma_plusplus}={function=>\&bot_karma_pp,regex=>'(\w+)\+\+'};
	#$Admin::public_parsers->{bot_karma_moinsmoins}={function=>\&bot_karma_mm,regex=>'(\w+)--'};

	$dbh=DBI->connect("dbi:SQLite:dbname=Modules/DB/quote.db","","");
	$dbh->do("BEGIN TRANSACTION;");
	$dbh->do("CREATE TABLE quote (numero INTEGER, channel TEXT, quote TEXT , date TEXT, quoteur TEXT);");
	$dbh->do("COMMIT;");
}

sub unload {

}

sub connect_DBI {
	my $dbh = DBI->connect('DBI:Oracle:payroll')
                or die "le quartier général des informations est kaput : " . DBI->errstr;
	return $dbh;
}

sub getNb {
	my ( $channel, $dbh) = @_;

	my $sth = $dbh->prepare('SELECT * FROM quote_table WHERE channel = ?')
		or die "j'arrive pas à préparer un modèle pour le QG des infos (n00b) : " . $dbh->errstr;
	$sth->execute($channel);
	return $sth->rows + 1;
}

sub addquote {
	my ( $classe, $who, $channel, $what ) = @_;

	# modèle d'insertion d'une quote à la con : le numéro, le channel (qui forment une clé)
	# puis la date (évitons les 32/14/-2076), puis le con qui quote, puis la quote de merde
	
	my $sth = $dbh->prepare("INSERT INTO quote_table(num, channel, date, who, what) VALUES ?,?,DATETIME('NOW','LOCALTIME'),?,?")
                or die "j'arrive pas à préparer un modèle pour le QG des infos (n00b) : " . $dbh->errstr;

	$num = this->getNb( $channel, $dbh );
	$sth->execute($num, $channel, $who, $what) or return 0;

	#%tab{$chan}=%tab{$chan}+1;

	return 1;
}

sub searchquote {
	my ( $classe, $channel, $what ) = @_;
	
	#my $dbh = this->connect_DBI();

	my $sth = $dbh->prepare('SELECT * FROM quote_table WHERE channel = ? AND quote LIKE ?')
                or die "j'arrive pas à préparer un modèle pour le QG des infos (n00b) : " . $dbh->errstr;

	$sth->execute($channel, $what);

	while (@data = $sth->fetchrow_array()) 
	{

	}
	if ($sth->rows == 0) {
		$ret = "Pas de quote contenant : \"" + $what + "\" :(";
	}

}


sub getquote {
	my ( $classe, $channel, $num ) = @_;
	
	my $sth = $dbh->prepare('SELECT * FROM quote_table WHERE numero = ?')
                or die "j'arrive pas à préparer un modèle pour le QG des infos (n00b) : " . $dbh->errstr;
    
    $sth->execute($num);
    
    if ($sth->rows == 0) {
		$ret = "Quote n° " + $num + " inexistante. :(";
	}
	else {
		@data = $sth->fetchrow_array();
		$ret = "Quote n° : " + @data[quote];
	}
	return $ret;
}

sub infoquote {
	my ( $classe, $channel, $num ) = @_;
	return;
}

1;
