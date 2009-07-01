#! /usr/bin/perl
$|=1 ;
package Search;
use DBI;
use LWP::UserAgent;

our $dbh;
our $ua;

sub init {
	my ($kernel,$irc) = @_;
	$Admin::public_functions->{bot_search}={function=>\&bot_search,regex=>'search (.*)'};
	$Admin::public_functions->{bot_searchn}={function=>\&bot_searchn,regex=>'searchn ([0-9]+) (.*)'};
	Admin::set_param('Search_GoogleAPIURL','http://ajax.googleapis.com/ajax/services/search/web?v=1.0');
	$ua=LWP::UserAgent->new;
}

sub unload {
	delete($Admin::public_functions->{bot_search});
}

sub bot_search {
	my($nick, $dest, $what)=@_;
	my @return;
	my $referer=Admin::get_param('Search_referer');
	my $GoogleAPIKey=Admin::get_param('Search_GoogleAPIKey');
	my $GoogleAPIUrl=Admin::get_param('Search_GoogleAPIURL');
	if( my ($search_str)= $what=~/search (.*)/)
	{
		$GoogleAPIUrl=$GoogleAPIUrl.'&key='.$GoogleAPIKey if defined $GoogleAPIKey;
		$GoogleAPIUrl =$GoogleAPIUrl.'&q='.$search_str;
		print 'Request url : '.$GoogleAPIUrl."\n";
		my $request=$ua->get($GoogleAPIUrl,referer=>$referer);
	        if($request->is_success)
		{
			my $data=$request->content;
			#Parsing JSON
			my $regex_single="{\"GsearchResultClass\":\"GwebSearch\",\"unescapedUrl\":\"(.*?)\",\"url\":\"(.*?)\",\"visibleUrl\":\"(.*?)\",\"cacheUrl\":\"(.*?)\",\"title\":\"(.*?)\",\"titleNoFormatting\":\"(.*?)\",\"content\":\"(.*?)\"}";

			if($data=~m/$regex_single/g)
			{
				my ($unescapedUrl,$url,$visibleUrl,$cacheUrl,$title,$titleNoFormatting,$content) = ($1,$2,$3,$4,$5,$6,$7);
#				print "unescapedUrl=$unescapedUrl\nurl=$url\nvisibleUrl=$visibleUrl\ncacheUrl=$cacheUrl\ntitle=$title\ntitleNoFormatting=$titleNoFormatting\ncontent=$content\n";
				my $ligne= {action =>"MSG",dest=>$dest,msg=>'[b]'.$titleNoFormatting.'[/b] - [c=teal]'.json_decode($unescapedUrl).'[/c]'};
				push(@return,$ligne);
			}
			else
			{
				my $ligne={action=>"MSG",dest=>$dest,msg=>'Pas de résultats pour [c=red]'.$search_str.'[/c]'};
				push(@return,$ligne)
			}
		}
	}
	return @return;
}

sub bot_searchn {
        my($nick, $dest, $what)=@_;
        my @return;
        my $referer=Admin::get_param('Search_referer');
        my $GoogleAPIKey=Admin::get_param('Search_GoogleAPIKey');
        my $GoogleAPIUrl=Admin::get_param('Search_GoogleAPIURL');
        if( my ($num,$search_str)= $what=~/searchn ([0-9]+) (.*)/)
        {
                $GoogleAPIUrl=$GoogleAPIUrl.'&key='.$GoogleAPIKey if defined $GoogleAPIKey;
                $GoogleAPIUrl =$GoogleAPIUrl.'&q='.$search_str;
                print 'Request url : '.$GoogleAPIUrl."\n";
                my $request=$ua->get($GoogleAPIUrl,referer=>$referer);
                if($request->is_success)
                {
                        my $data=$request->content;
                        #Parsing JSON
                        my $regex_single="{\"GsearchResultClass\":\"GwebSearch\",\"unescapedUrl\":\"(.*?)\",\"url\":\"(.*?)\",\"visibleUrl\":\"(.*?)\",\"cacheUrl\":\"(.*?)\",\"title\":\"(.*?)\",\"titleNoFormatting\":\"(.*?)\",\"content\":\"(.*?)\"}";
			my $matchednum=0;
                        while($data=~m/$regex_single/g && $matchednum<=4 && $matchednum < $num)
                        {
				$matchednum++;		
				print "num=$num,matchednum=$matchednum\n";
                                my ($unescapedUrl,$url,$visibleUrl,$cacheUrl,$title,$titleNoFormatting,$content) = ($1,$2,$3,$4,$5,$6,$7);
                                my $ligne= {action =>"MSG",dest=>$dest,msg=>'[c=purple]'.$matchednum.'[/c] : [b]'.$titleNoFormatting.'[/b] - [c=teal]'.json_decode($unescapedUrl).'[/c]'};
                                push(@return,$ligne);
                        }
			
			if($matchednum==0)
                        {
                                my $ligne={action=>"MSG",dest=>$dest,msg=>'Pas de résultats pour [c=red]'.$search_str.'[/c]'};
                                push(@return,$ligne)
                        }
                }
        }
        return @return;
}

sub json_decode {
	my ($data)=@_;
	$data=~s/\\\\u003e/\>/g;
	$data=~s/\\\\u003d/=/g;
	$data=~s/\\\\u0026/\\\&/g;
	$data=~s/\\\\u003c/\</g;
	return $data;
}
1;
