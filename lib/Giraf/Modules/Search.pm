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

	Giraf::Module::register('public_function','search','bot_search',\&bot_search,'search\s+?(.+)');
	Giraf::Module::register('public_function','search','bot_searchn',\&bot_searchn,'searchn\s+?[0-9]+\s+?(.+)');
	#http://code.google.com/intl/fr/apis/ajaxsearch/documentation/reference.html#_restUrlBase
	Giraf::Module::set_param('Search_GoogleAPIURL','http://ajax.googleapis.com/ajax/services/search/web?v=1.0&rsz=large');
	Giraf::Module::set_param('Search_GoogleSafeSearch','off');
	if(!$_ua)
	{
		$_ua=LWP::UserAgent->new;
	}
}

sub unload {
	Giraf::Module::unregister('public_function','search','bot_search');
	Giraf::Module::unregister('public_function','search','bot_searchn');
}

sub bot_search {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("bot_search()");

	my @return;
	my $referer=Giraf::Module::get_param('Search_referer');
	my $GoogleAPIKey=Giraf::Module::get_param('Search_GoogleAPIKey');
	my $GoogleAPIUrl=Giraf::Module::get_param('Search_GoogleAPIURL');
	my $GoogleSafeSearch=Giraf::Module::get_param('Search_GoogleSafeSearch');
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
	
	Giraf::Core::debug("bot_searchn()");
        
	my @return;
        my $referer=Giraf::Module::get_param('Search_referer');
        my $GoogleAPIKey=Giraf::Module::get_param('Search_GoogleAPIKey');
        my $GoogleAPIUrl=Giraf::Module::get_param('Search_GoogleAPIURL');
	my $GoogleSafeSearch=Giraf::Module::get_param('Search_GoogleSafeSearch');
        if( my ($num,$search_str)= $what=~/searchn\s+?([0-9]+)\s+?(.+)/)
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
			my $matchednum=0;
                        while($data=~m/$regex_single/g && $matchednum<=4 && $matchednum < $num)
                        {
				$matchednum++;		
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
	$data=~s/\\u003e/\>/g;
	$data=~s/\\u003d/=/g;
	$data=~s/\\u0026/\\\&/g;
	$data=~s/\\u003c/\</g;
	return $data;
}
1;
