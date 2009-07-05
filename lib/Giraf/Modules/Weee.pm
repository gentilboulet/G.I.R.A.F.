#/usr/bin/perl
$|=1;

package Giraf::Modules::Weee;

my @ovations=(['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/'], ['\o/','\\\\o','o//'], ['<o/'],['\\o>'],['\o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/ \o/'] );


sub init {
	my ($kernel,$irc) = @_;
	$Giraf::Modules::Admin::public_parsers->{bot_weee}={function=>\&bot_weee,regex=>'(\B[<>/|_\\\]o[/<>|_\\\]\B)|(\B[</|_\\\>]{2}o)|(o[/<>|_\\\]{2}\B)'};
}

sub unload {
	delete($Giraf::Modules::Admin::public_parsers->{bot_weee});
}

sub bot_weee {
	my($nick, $dest, $what)=@_;
	my @return;
	my $rand=int(rand(scalar(@ovations)));
	my $ref=$ovations[$rand];
	foreach my $e (@$ref)
	{
		my $ligne={ action =>"MSG",dest=>$dest,msg=>"$e"};
		push(@return,$ligne);
	}
	return @return;
}

1;

