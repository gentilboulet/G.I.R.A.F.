#! /usr/bin/perl -w
$| = 1;
unshift( @INC, "./Modules/" );
use lib './Modules/';
package Giraf;
use Chan;
use Admin;
use POSIX;
use strict;
use POE qw(Component::IRC);
use Getopt::Long;
use Data::Dumper;
use IO::Socket;
use Modules::Reload;

my $version = '0.0.2';
my $config = 'giraf.conf';    # default name of the config file
my $botname;                   #botname
my $triggers;
my $kernel;
readconfig();

our %opts;

GetOptions(
	\%opts,       "help",       "server=s",   "serverpass=s",	"botpass=s",
	"botnick=s",  "botuser=s",  "botrlnm=s",  "botchan=s",
	"botident=s", "botmodes=s", "botopcmd=s", "maxtries=i",
	"botadmin=s", "logfile=s",  "debug=i",	  "triggers=s",
  )
  or debug( "Error: Could not parse command line. Try $0 --help\n", 1 );

$botname = $opts{botnick};
$triggers=$opts{triggers};

Admin->init_sessions();

# We create a new PoCo-IRC object and component.
my $irc = POE::Component::IRC->spawn(
	nick     => $botname,
	server   => $opts{server},
	port     => $opts{port},
	ircname  => $opts{botrlnme},
	username => $opts{botuser},
	debug    => 0,
  )
  or die "Oh noooo! $!";

POE::Session->create(
	package_states => [
		'Giraf' => [
			_start   => "_start",
			_stop    => "_stop",
			_default => "_default",
			irc_001  => "irc_001",
			irc_433  => "irc_433",

			irc_public       => "irc_public",
			irc_msg		 => "irc_msg",
			irc_disconnected => "irc_disconnected",
			irc_error        => "irc_error",
			irc_socketerr    => "irc_socketerr",
			sigint           => "sigint",
			irc_notice       => "irc_notice",
			irc_nick         => "irc_nick",
			irc_part         => "irc_part",
			irc_join         => "irc_join",
			irc_quit         => "irc_quit",
			irc_mode	 => "irc_mode",
		],
	],
	heap => { irc => $irc },
);

$poe_kernel->run();

exit 0;

sub irc_001
{
	my ( $kernel, $sender ) = @_[ KERNEL, SENDER ];
	$Giraf::kernel=$kernel;
	# Get the component's object at any time by accessing the heap of
	# the SENDER
	my $poco_object = $sender->get_heap();
	debug( "Connected to " . $poco_object->server_name() );

	# In any irc_* events SENDER will be the PoCo-IRC session
	foreach my $nom ( @{ $opts{botchan} } )
	{
		Chan->join($nom);
	}
	undef;
}

sub irc_433
{
	my ($kernel) = @_[KERNEL];
	$botname = "Mr_Bobby";
	$kernel->post( $irc => nick => $botname );
	Chan->init( $kernel, $irc, $botname );
	debug($botname);
	sleep 1;
}

sub _default
{
	my ( $event, $args ) = @_[ ARG0 .. $#_ ];

	if ( $event =~ /^irc_(353)$/ )
	{
		irc_names( @_[ARG1] );
	} else
	{
		#debug("unhandled $event");

		my $arg_number = 0;
		my $str;
		foreach (@$args)
		{
			$str = "  ARG$arg_number = ";
			if ( ref($_) eq 'ARRAY' )
			{
				$str .= "$_ = [", join( ", ", @$_ ), "]";
			} else
			{
				$str .= "'$_'";
			}

			#debug($str);
			$arg_number++;
		}
		return 0;    # Don't handle signals.
	}
}

sub irc_disconnected
{
	debug( "Lost connection to server " . $opts{server} . ".\n" );
	irc_reconnect( $_[KERNEL] );
}

sub irc_error
{
	my $err = $_[ARG0];
	debug("Server error occurred! $err\n");
	sleep 60;
	irc_reconnect( $_[KERNEL] );
}

sub irc_join
{
	my ( $kernel, $sender, $who, $where ) = @_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick = ( split /!/, $who )[0];
	Chan->add_user( $where, $nick );
	debug("$nick join $where");
}

sub irc_msg
{
	my ( $kernel, $sender, $who, $where, $what ) = @_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick = ( split /!/, $who )[0];
	#debug("@$where:$nick : $what");
	emit(Admin->private_msg( $nick, $who, $where, $what ) );
}

sub irc_public
{
	my ( $kernel, $sender, $who, $where, $what ) = @_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick = ( split /!/, $who )[0];
	my $channel = $where->[0];
	#debug("@$where:$nick : $what");
	emit(Admin->public_msg( $nick, $channel, $what ) );
	my $regex=$triggers."reload";
	if ( $what =~ /^$regex$/ )
	{
		#reload_modules();
	}
	undef;
}

sub irc_names
{
	my ($info) = @_;
	$info = @$info[1];
	$info =~ /= (#.*) :(.*) /;
	my $chan = $1;
	my @users_list = split( / / , $2 );
	foreach my $k (@users_list)
	{
		debug( "Sur " . $chan . " il y a {" . $k . "}" );
		Chan->add_user( $chan, $k );
	}
}

sub irc_nick
{
	my ( $kernel, $sender, $who, $new_nick ) = @_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick = ( split /!/, $who )[0];
	debug("nick_user($nick,$new_nick);"); 
	Chan->nick_user( $nick, $new_nick );
	emit(Admin->on_nick( $nick, $new_nick ) );
}

sub irc_notice
{
	my ( $kernel, $sender, $who, $where, $what ) =
	@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick = ( split /!/, $who )[0];
	debug( " : $nick $what\n" );
}

sub irc_part
{
	my ( $kernel, $sender, $who, $where ) = @_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick = ( split /!/, $who )[0];
	Chan->part_user( $where, $nick );
	debug("$nick part $where");
}

sub irc_quit
{
	my ( $kernel, $sender, $who, $message ) = @_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick = ( split /!/, $who )[0];
	Chan->quit_user($who);
	debug("$nick quit : $message");
}

sub irc_mode
{
	my ($kernel, $sender, $who, $what, $mode_string, $args) = @_[ KERNEL, SENDER, ARG0, ARG1, ARG2, ARG3 ];
	my $nick = ( split /!/, $who )[0];
	if( $what =~/^#.*/ )
	{
		debug("chan_mode : $what,$mode_string,$args");
		Chan->chan_mode($what,$mode_string,$args);
	}
	else
	{
		debug("user_mode : $what,$mode_string,$args");
		Chan->user_mode($what,$mode_string,$args);
	}

}

sub irc_reconnect
{
	$_[0]->post( $irc => connect => {} );
}

sub sigint
{
	my $kernel = $_[KERNEL];
	$kernel->post( $irc => quit => "Adieu monde cruel!" );
	debug("Ca piiiiiiique!!!!!!");
	$kernel->sig('INT');
	$kernel->sig_handled();
}

sub irc_socketerr
{
	my $err = $_[ARG0];
	debug("Couldn't connect to server: $err\n");
	sleep 60;
	irc_reconnect( $_[KERNEL] );
}

sub _start
{
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

	# We get the session ID of the component from the object
	# and register and connect to the specified server.
	my $irc_session = $heap->{irc}->session_id();
	$kernel->post( $irc_session => register => 'all' );
	$kernel->post( $irc_session => connect => {} );
	undef;
	Chan->init( $kernel,  $irc ,$botname);
	Admin->init( $kernel, $irc ,$triggers);
	$kernel->post ($irc_session =>  'privmsg' => nickserv => "IDENTIFY ".$opts{botpass});


}

sub _stop
{
	debug("STOP ?! \n");
}

sub bbcode
{
	my ($msg_text) = @_;
	my $colors = {
		black      => "01",
		navy_blue  => "02",
		green      => "03",
		red        => "04",
		brown      => "05",
		purple     => "06",
		olive      => "07",
		orange     => "07",
		yellow     => "08",
		lime_green => "09",
		teal       => "10",
		aqua_light => "11",
		royal_blue => "12",
		hot_pink   => "13",
		dark_gray  => "14",
		light_gray => "15",
		white      => "16",

		#more colors
		noir        => "01",
		bleu_marine => "02",
		vert        => "03",
		rouge       => "04",
		marron      => "05",
		violet      => "06",
		olive       => "07",
		jaune       => "08",
		vert_clair  => "09",
		bleu_vert   => "10",
		bleu_clair  => "11",
		bleu        => "12",
		bleu_royal  => "12",
		rose        => "13",
		gris_fonce  => "14",
		gris_clair  => "15",
		blanc       => "16",
	};

	my $bold      = "bold|b";
	my $underline = "underline|u";
	my $color     = "color|c";
	my $bgcolor   = "bgcolor|bgc|color|c";
	my $reverse   = "reverse|r";
	
	foreach my $i (0..4)
	{
		#bold
		$msg_text =~ s/\[($bold)\](.*?)\[\/($bold)\]/\002$2\002/gi;

		#underline
		$msg_text =~ s/\[($underline)\](.*?)\[\/($underline)\]/\037$2\037/gi;

		#color
		$msg_text =~
		s/\[($color)=(.*?)\](.*?)\[\/($color)\]/\003$colors->{$2}$3\003/gi;

		#bgcolor
		$msg_text =~
		s/\[($bgcolor)=(.*?),(.*)\](.*?)\[\/($bgcolor)\]/\003$colors->{$2},$colors->{$3}$4\003/gi;

		#reverse
		$msg_text =~ s/\[($reverse)\](.*?)\[\/($reverse)\]/\026$2\026/gi;
	}
	return $msg_text;
}

sub debug
{
	my ($text) = @_;
#	if ( $opts{debug} )
	{
		print ts() . "$text\n";
	}
	return $text;
}

sub emit
{
	my ( @tab ) = @_;
	foreach my $ligne (@tab)
	{

		if ( $ligne->{action} eq "ACTION" )
		{
			$Giraf::kernel->post( $irc=> 'ctcp' => $ligne->{dest} => "ACTION " . bbcode($ligne->{msg}) );
		} elsif ( $ligne->{action} eq "PRIVMSG" )
		{
			$Giraf::kernel->post( $irc=> 'privmsg' => $ligne->{dest} => bbcode($ligne->{msg}) );
		} elsif ( $ligne->{action} eq "MSG" )
		{
			$Giraf::kernel->post( $irc=> 'privmsg' => $ligne->{dest} => bbcode($ligne->{msg}) );
		} elsif ( $ligne->{action} eq "NOTICE" )
		{
			$Giraf::kernel->post( $irc=> 'notice' => $ligne->{dest} => bbcode($ligne->{msg}) );
		}
	}
}

sub quit
{
	my ( $kernel, $reason ) = @_;
	if ( !$reason )
	{
		$reason = "All your bot is belong to us";
	}
	my $kernel = shift;
	$kernel->signal( $kernel, 'POCOIRC_SHUTDOWN', $reason );
}

sub readconfig
{
	if ( !-e $config )
	{
		debug(
			"Error: Cannot find $config. Copy it to this directory, "
			. "please.",
			1
		);
	} else
	{
		open( CONF, "<$config" ) or do
		{
			debug( "Failed to open config file $config $!", 1 );
		};
		my ( $line, $key, $val );
		while ( $line = <CONF> )
		{
			next() if $line =~ /^#/;    # skip comments
			$line =~ s/[\r\n]//g;
			$line =~ s/^\s+//g;
			next() if !length($line);    # skip blank lines
			( $key, $val ) = split( /\s+/, $line, 2 );
			$key = lc($key);
			if ( lc($val) eq "on" || lc($val) eq "yes" )
			{
				$val = 1;
			} elsif ( lc($val) eq "off" || lc($val) eq "no" )
			{
				$val = 0;
			}
			if ( $key eq "die" )
			{
				die(    "Please edit the file $config to setup your bot's "
					  . "options. Also, read the README file if you haven't "
					  . "yet.\n" );
			} elsif ( $key eq "server" )
			{
				my @port = split( ":", $val, 2 );
				$opts{server} = $port[0];
				$opts{port}   = $port[1];
			} elsif ( $key eq "botchan" )
			{
				push( @{ $opts{botchan} }, $val );
			} else
			{
				$opts{$key} = $val;
			}
		}
	}
}

sub reload_modules
{
	#debug("Rechargement des modules");
	#Admin->reload_modules;
	#Reload->check;
}

sub ts
{    # timestamp
	my @ts = localtime( time() );
	return sprintf(
		"[%02d/%02d/%02d %02d:%02d:%02d] ",
		$ts[4] + 1,
		$ts[3], $ts[5] % 100,
		$ts[2], $ts[1], $ts[0]
	);
}

