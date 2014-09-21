#! /usr/bin/perl
$|=1 ;

package Giraf::Modules::GPS;

use strict;
use warnings;

use Giraf::Admin;

use LWP::UserAgent;
use JSON;
use Data::Dumper;
use List::Util qw(sum);
use Math::Trig;
use Math::Trig ':radial';
use utf8;

our $version=1;
# Private vars
our $_dbh;
our $_ua;

my $_x;
my $_y;
my $_z;

sub init {
	my ($kernel,$irc) = @_;

	Giraf::Core::debug("Giraf::Modules::GPS::init()");

	Giraf::Trigger::register('public_function','GPS','bot_gps',\&bot_gps,'gps\s+');
	Giraf::Trigger::register('public_function','GPS','bot_middle',\&bot_middle,'middle');
	if(!$_ua)
	{
		$_ua=LWP::UserAgent->new;
	}
	# https://developers.google.com/maps/articles/geocodestrat
	Giraf::Admin::set_param('GPS_GoogleAPIURL','http://maps.googleapis.com/maps/api/geocode/json?language=fr&address=');
}

sub unload {

	Giraf::Core::debug("Giraf::Modules::GPS::unload()");

	Giraf::Trigger::unregister('public_function','GPS','bot_gps');
	Giraf::Trigger::unregister('public_function','GPS','bot_middle');
}

sub bot_gps {
	my($nick, $dest, $what, $middle)=@_;

	Giraf::Core::debug("Giraf::Modules::GPS::bot_gps()");

	my @return;

	my $referer=Giraf::Admin::get_param('GPS_referer');
	my $GoogleAPIUrl=Giraf::Admin::get_param('GPS_GoogleAPIURL');
	my $search_str=$what;
	utf8::decode($search_str);
	$GoogleAPIUrl =$GoogleAPIUrl.$search_str;
	my $request=$_ua->get($GoogleAPIUrl,referer=>$referer);
	if($request->is_success)
	{
		my $data=$request->content;
		my $data_decode = decode_json($data);
		my $message = '';

		# Giraf::Core::debug(Dumper($data_decode));
		# Parsing JSON

		
		if ( $data_decode->{'status'} eq 'ZERO_RESULTS') {
			$message .= 'Pas de résultat trouvé pour [c=red]'.$search_str.'[/c].' if $middle == undef;
			$message .= "[c=orange]Un seul[/c] point a \x{e9}t\x{e9} entr\x{e9} : " if $middle == 1;
			$message .= "Le [c=teal]centre[/c] de ces [c=orange]".$middle."[/c] points se situe \x{e0} ces coordonn\x{e9}es : " if $middle > 1;
			$message .= "[c=yellow]".$what.'[/c]. https://www.google.com/maps/?q='.$what if $middle > 0;
		} else {
			my $lat = $data_decode->{'results'}[0]->{'geometry'}->{'location'}->{'lat'};
			my $lng = $data_decode->{'results'}[0]->{'geometry'}->{'location'}->{'lng'};
			my $txt_address = $data_decode->{'results'}[0]->{'formatted_address'};

			$message .= "Coordonn\x{e9}es GPS pour " if $middle == undef;
			$message .= "[c=orange]Un seul[/c] point a \x{e9}t\x{e9} entr\x{e9} : " if $middle == 1;
			$message .= "Le [c=teal]centre[/c] de ces [c=orange]$middle [/c]points est : " if $middle > 1;

			$message .= "[c=green]".$txt_address.'[/c] : ';

			$message .= '[c=yellow]'.sprintf("%.7f,%.7f", $lat, $lng).'[/c]' if $middle == undef;
			$message .= "[c=yellow]".$what.'[/c]. https://www.google.com/maps/?q='.$what if $middle > 0;

			if ($middle == undef) {
				my $theta = deg2rad($lng);
				my $phi = deg2rad(90 - $lat);
				my ($x, $y, $z) = spherical_to_cartesian(1, $theta, $phi);
				
				push(@{$_x->{$dest}}, $x);
				push(@{$_y->{$dest}}, $y);
				push(@{$_z->{$dest}}, $z);
			}
		}

		$message .= " Suppression des [c=purple]points enregistr\x{e9}s[/c]." if $middle > 0;

		utf8::encode($message);
		my $ligne={action=>"MSG",dest=>$dest,msg=>$message};
		push(@return,$ligne);

	}
	return @return;
}

sub bot_middle {
	my($nick, $dest, $what)=@_;

	Giraf::Core::debug("Giraf::Modules::GPS::bot_middle()");

	my $message = '';
	my @return;


	if ($_x && @{$_x->{$dest}}) {
		my $x = sum(@{$_x->{$dest}}) / @{$_x->{$dest}};
		my $y = sum(@{$_y->{$dest}}) / @{$_y->{$dest}};
		my $z = sum(@{$_z->{$dest}}) / @{$_z->{$dest}};

     	my ($rho, $theta, $phi) = cartesian_to_spherical($x, $y, $z);
		if ($rho > 1e-7) {
			my $lat = 90 - rad2deg($phi);
			my $lng = rad2deg($theta);
			
			@return = bot_gps ($nick, $dest, sprintf("%.7f,%.7f", $lat, $lng), scalar(@{$_x->{$dest}}));
		} else {
			$message .= "Il n'est pas possible de trouver un [c=teal]point central[/c]. Suppression des [c=purple]points enregistr\x{e9}s[/c].";
			utf8::encode($message);
			my $ligne={action=>"MSG",dest=>$dest,msg=>$message};
			push(@return,$ligne);
		}
		@{$_x->{$dest}} = ();
		@{$_y->{$dest}} = ();
		@{$_z->{$dest}} = ();
	} else {
		$message .= "Pas de [c=purple]points enregistr\x{e9}s[/c] pour l'instant.";
		utf8::encode($message);
		my $ligne={action=>"MSG",dest=>$dest,msg=>$message};
		push(@return,$ligne);
	}


	return @return;
}


1;
