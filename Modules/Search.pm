#! /usr/bin/perl
$|=1 ;
package Search;
use DBI;
use SOAP::WSDL

our $dbh;

sub init {
	my ($kernel,$irc) = @_;
	$Admin::public_functions->{bot_search}={function=>\&bot_search,regex=>'search (.*)'};
}

sub bot_search {
	my($nick, $dest, $what)=@_;
	my $regex=$triggers."search (.*)";
	my ($search_string) = $what=~/$regex/ ;	
	 my $soap = SOAP::WSDL->new( wsdl => 'http://sitening.com/evilapi/api/GoogleSearch.wsdl' );
	  $soap->wsdlinit();
	  $soap->servicename( 'GoogleSearchService' );
	  $soap->portname( 'GoogleSearchPort' );

	     my $som = $soap->call( 'doGoogleSearch' =>  (
			     key => 'value' ,
			     querry => 'google' ) );
		
	     print "$som";
	     my @return;
	     return @return;
     }



     1;
