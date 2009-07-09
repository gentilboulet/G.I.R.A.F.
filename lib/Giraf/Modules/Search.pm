#! /usr/bin/perl
$|=1 ;

package Giraf::Modules::Search;

use strict;
use warnings;

use Giraf::Admin;

use LWP::UserAgent;

# Private vars
our $_dbh;
our $_ua;

sub init {
	my ($kernel,$irc) = @_;

	Giraf::Core::debug("Giraf::Modules::Search::init()");

	Giraf::Trigger::register('public_function','Search','bot_search',\&bot_search,'search\s+?(.+)');
	Giraf::Trigger::register('public_function','Search','bot_searchn',\&bot_searchn,'searchn\s+?[0-9]+\s+?(.+)');
	if(!$_ua)
	{
		$_ua=LWP::UserAgent->new;
	}
	#http://code.google.com/intl/fr/apis/ajaxsearch/documentation/reference.html#_restUrlBase
	Giraf::Admin::set_param('Search_GoogleAPIURL','http://ajax.Googleapis.com/ajax/services/search/web?v=1.0&rsz=large');
	Giraf::Admin::set_param('Search_GoogleSafeSearch','off');
}

sub unload {

	Giraf::Core::debug("Giraf::Modules::Search::unload()");

	Giraf::Trigger::unregister('public_function','Search','bot_search');
	Giraf::Trigger::unregister('public_function','Search','bot_searchn');
}

sub bot_search {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("Giraf::Modules::Search::bot_search()");

	my @return;
	my $referer=Giraf::Admin::get_param('Search_referer');
	my $GoogleAPIKey=Giraf::Admin::get_param('Search_GoogleAPIKey');
	my $GoogleAPIUrl=Giraf::Admin::get_param('Search_GoogleAPIURL');
	my $GoogleSafeSearch=Giraf::Admin::get_param('Search_GoogleSafeSearch');
	if( my ($search_str)= $what=~/search\s+?(.+)/)
	{
		$GoogleAPIUrl=$GoogleAPIUrl.'&key='.$GoogleAPIKey if defined $GoogleAPIKey;
		$GoogleAPIUrl =$GoogleAPIUrl.'&safe='.$GoogleSafeSearch;
		$GoogleAPIUrl =$GoogleAPIUrl.'&q='.$search_str;
		my $request=$_ua->get($GoogleAPIUrl,referer=>$referer);
	        if($request->is_success)
		{
			my $data=$request->content;
			#Parsing JSON
			my $regex_single="{\"GsearchResultClass\":\"GwebSearch\",\"unescapedUrl\":\"(.*?)\",\"url\":\"(.*?)\",\"visibleUrl\":\"(.*?)\",\"cacheUrl\":\"(.*?)\",\"title\":\"(.*?)\",\"titleNoFormatting\":\"(.*?)\",\"content\":\"(.*?)\"}";

			if($data=~m/$regex_single/g)
			{
				my ($unescapedUrl,$url,$visibleUrl,$cacheUrl,$title,$titleNoFormatting,$content) = ($1,$2,$3,$4,$5,$6,$7);
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
	
	Giraf::Core::debug("Giraf::Modules::Search::bot_searchn()");
        
	my @return;
        my $referer=Giraf::Admin::get_param('Search_referer');
        my $GoogleAPIKey=Giraf::Admin::get_param('Search_GoogleAPIKey');
        my $GoogleAPIUrl=Giraf::Admin::get_param('Search_GoogleAPIURL');
	my $GoogleSafeSearch=Giraf::Admin::get_param('Search_GoogleSafeSearch');
        if( my ($num,$search_str)= $what=~/searchn\s+?([0-9]+)\s+?(.+)/)
        {
                $GoogleAPIUrl=$GoogleAPIUrl.'&key='.$GoogleAPIKey if defined $GoogleAPIKey;
		$GoogleAPIUrl =$GoogleAPIUrl.'&safe='.$GoogleSafeSearch;
                $GoogleAPIUrl =$GoogleAPIUrl.'&q='.$search_str;
                my $request=$_ua->get($GoogleAPIUrl,referer=>$referer);
                if($request->is_success)
                {
                        my $data=$request->decoded_content;
                        #Parsing JSON
                        my $regex_single="{\"GsearchResultClass\":\"GwebSearch\",\"unescapedUrl\":\"(.*?)\",\"url\":\"(.*?)\",\"visibleUrl\":\"(.*?)\",\"cacheUrl\":\"(.*?)\",\"title\":\"(.*?)\",\"titleNoFormatting\":\"(.*?)\",\"content\":\"(.*?)\"}";
			my $matchednum=0;
			$data=json_decode($data);
                        while($data=~m/$regex_single/g && $matchednum<=4 && $matchednum < $num)
                        {
				$matchednum++;		
                                my ($unescapedUrl,$url,$visibleUrl,$cacheUrl,$title,$titleNoFormatting,$content) = ($1,$2,$3,$4,$5,$6,$7);
                                my $ligne= {action =>"MSG",dest=>$dest,msg=>'[c=purple]'.$matchednum.'[/c] : [b]'.xhtml_decode($titleNoFormatting).'[/b] - [c=teal]'.$unescapedUrl.'[/c]'};
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
	
	$data=~s/\\u003e/\>/g;
	$data=~s/\\u003d/=/g;
	$data=~s/\\u0026/\&/g;
	$data=~s/\\u003c/\</g;
	return $data;
}

sub xhtml_decode {
	my ($data) = @_;
	Giraf::Core::debug($data);
	$data=~s/\&#39\;/\'/g;
	Giraf::Core::debug($data);
	return $data;
}

1;
