#! /usr/bin/perl
$|=1;
package Giraf::Modules::String;
use strict;
use warnings;
use Giraf::Admin;

sub init {
	my ($kernel,$irc) = @_;
	Giraf::Trigger::register('public_function','String','bot_reverse',\&bot_reverse,'reverse');
	Giraf::Trigger::register('public_function','String','bot_rot13',\&bot_rot13,'rot13');
	Giraf::Trigger::register('public_function','String','bot_hex_str',\&bot_hex_str,'hex_str');
}
sub unload {
        my ($kernel,$irc) = @_;
        Giraf::Trigger::unregister('public_function','String','bot_reverse');
        Giraf::Trigger::unregister('public_function','String','bot_rot13');
        Giraf::Trigger::unregister('public_function','String','bot_hex_str');
}

sub bot_reverse {
	Giraf::Core::debug("bot_reverse()");
	my ($nick,$dest,$what) = @_;
	my $str=$what;
	utf8::decode($str);
	chomp($str);
	my ($result,$char,$ligne,@return);
	$result='';
	while(length($str)) {
		$char = chop($str);
		$result = $result.$char;
	}
	utf8::encode($result);
	$ligne = {action=>"MSG",dest=>$dest,msg=>$result};
	push(@return,$ligne);
	return @return;
}

sub bot_rot13 {
	Giraf::Core::debug("bot_rot13");
	my ($nick,$dest,$what) = @_;
	my $str=$what;
	$str=~tr/A-Za-z/N-ZA-Mn-za-m/;
	my ($char,$ligne,@return);
	$ligne = {action=>"MSG",dest=>$dest,msg=>$str};
	push(@return,$ligne);
	return @return;
}

sub bot_hex_str {
        Giraf::Core::debug("bot_hex_str()");
        my ($nick,$dest,$what) = @_;
        my $str="$what\0";
	my $first = substr($str,0,1);
	my $tail = substr($str,1,length($str)-1);
        my ($result,$char,$ligne,@return);
        $result=" };";
        while($char = chop($tail)) {
                $result = sprintf(", 0x%x%s",ord($char),$result);
        }
	$result = sprintf("%s: const char str[] = { 0x%x%s",$nick,ord($first),$result);
        $ligne = {action=>"MSG",dest=>$dest,msg=>$result};
        push(@return,$ligne);
        return @return;

}

1;
