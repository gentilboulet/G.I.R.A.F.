package Giraf::Modules::HaroBattle;

use strict;

use Giraf::Module;

use List::Util qw[min max];
use POSIX qw(ceil floor);
use Switch;
use POE;

# Private vars
our $_kernel;
my $_chan = "#harobattle";

my $_match_en_cours;
my $_paris_ouverts;
my $_champion;
my $_challenger;
my $_continuer;


sub init {
	my ($ker,$irc_session) = @_;
	$_kernel=$ker;
	$_kernel->post( $irc_session => join => $_chan );
	Giraf::Module::register('public_function','harobattle','harobattle_main',\&harobattle_main,'harobattle.*');
	# Giraf::Module::register('public_function','harobattle','harobattle_vote',\&harobattle_vote,'[fF][12]\s*');
	# Giraf::Module::register('on_nick_function','harobattle','harobattle_nick',\&harobattle_nick);
}
 
sub unload {
	Giraf::Module::unregister('public_function','harobattle','harobattle_main');
	# Giraf::Module::unregister('public_function','harobattle','harobattle_vote');
	# Giraf::Module::unregister('on_nick_function','harobattle','harobattle_nick');
}

sub harobattle_main {
	my ($nick, $dest, $what)=@_;
	my @return;
	my ($sub_func, $args);
	$what=~m/^harobattle(\s+(.+?))?(\s+(.+))?$/;

	$sub_func = $2;
	$args = $4;

	Giraf::Core::debug("harobattle_main : sub_func = \"$sub_func\"");

	switch ($sub_func) {
		case 'help'     { push(@return, harobattle_help($nick, $dest, $args)); }
		case 'original' { push(@return, harobattle_launch($nick, $dest, $args)); }
		case 'stop'     { push(@return, harobattle_stop($nick, $dest, $args)); }
		else            { harobattle_caracs($nick, $dest, $sub_func); }
	}
 
	return @return;
}

sub harobattle_launch {
	my ($nick, $dest, $args) = @_;
	my @return;

	Giraf::Core::debug("harobattle_launch : args = \"$args\"");

	if ($_match_en_cours) {
		push(@return, linemaker("Un match est déjà en cours, un peu de patience."));
		return @return;
	}

	my $champion = int(rand(8) + 1);
	$_champion = chargement($champion);
	$_match_en_cours = 1;
	$_continuer = 1;

	$_kernel->post('harobattle_core', 'harobattle_original', $dest, 1);

	return @return;
}

sub harobattle_caracs {
	my ($nick, $dest, $sub_func) = @_;
	my @return;

	Giraf::Core::debug("harobattle_stats : args = \"$args\"");

	push(@return, linemaker("http://urltemporairequimarchepas.com"));

	return @return;
}

sub harobattle_stop {
	my ($nick, $dest, $args) = @_;
	my @return;

	Giraf::Core::debug("harobattle_stop : args = \"$args\"");

	$_continuer = 0;

	push(@return, linemaker("OK, on arrête après le prochain duel."));
	return @return;
}

sub linemaker {
	my ($texte) = @_;

	return { action =>"MSG", dest=>$_chan, msg=>$texte };
}


sub nom {
	my ($haro) = @_;

	# Renvoie le nom du haro avec les tags de couleur

	return "[c=".$haro->{couleur}."]haro[".$haro->{nom}."][/c]";
}

sub sante {
	# Renvoie la barre de santé des haros

	my $scale = ceil((18 * $_champion->{points_vie}) / $_champion->{points_vie_total});

	my $result = "[[c=vert]";
	for (my $i = 18; $i > 0; $i--) {

		# Met les couleurs
		if ($i == 12) {
			$result .= "[/c][c=jaune]";
		}
		else {
			if ($i == 6) {
				$result .= "[/c][c=rouge]";
			}
		}

		# Affiche la barre
		if ($i > $scale) {
			$result .= " ";
		}
		else {
			$result .= "|";
		}
	}
	$result .= "[/c]] ".nom($_champion)." / ".nom($_challenger)." [[c=rouge]";

	$scale = ceil((18 * $_challenger->{points_vie}) / $_challenger->{points_vie_total});
	
	for (my $i = 1; $i < 19; $i++) {

		# Met les couleurs
		if ($i == 7) {
			$result .= "[/c][c=jaune]";
		}
		else {
			if ($i == 13) {
				$result .= "[/c][c=vert]";
			}
		}

		# Affiche la barre
		if ($i > $scale) {
			$result .= " ";
		}
		else {
			$result .= "|";
		}
	}
	$result .= "[/c]]";
}

sub chargement {
	my ($ref) = @_;
	# Charge un haro à partir de la base de données

	my $haro1 = {
		id => 1,
		nom => "vert",
		couleur => "vert",
		precision => 10,
		esquive => 7,
		charisme => 5,
		armure => 2,
		points_vie => 1,
		points_vie_total => 1,
		arme => "Fusil de sniper",
		puissance => 20,
		coups => 1,
		recharge => 2,
		munitions => 4
	};
	my $haro2 = {
		id => 2,
		nom => "bleu",
		couleur => "bleu_royal",
		precision => 3,
		esquive => 1,
		charisme => 8,
		armure => 7,
		points_vie => 13,
		points_vie_total => 13,
		arme => "Submachine gun",
		puissance => 12,
		coups => 3,
		recharge => 0,
		munitions => 18
	};
	my $haro3 = {
		id => 3,
		nom => "rose",
		couleur => "rose",
		precision => 5,
		esquive => 4,
		charisme => 8,
		armure => 5,
		points_vie => 15,
		points_vie_total => 15,
		arme => "Desert Eagle",
		puissance => 15,
		coups => 1,
		recharge => 0,
		munitions => 12
	};
	my $haro4 = {
		id => 4,
		nom => "rouge",
		couleur => "rouge",
		precision => 7,
		esquive => 4,
		charisme => 2,
		armure => 6,
		points_vie => 12,
		points_vie_total => 12,
		arme => "Fusil à deux canons",
		puissance => 15,
		coups => 2,
		recharge => 1,
		munitions => 8
	};
	my $haro5 = {
		id => 5,
		nom => "jaune",
		couleur => "jaune",
		precision => 10,
		esquive => 10,
		charisme => 3,
		armure => 8,
		points_vie => 12,
		points_vie_total => 12,
		arme => "Lance-flammes",
		puissance => 6,
		coups => 1,
		recharge => 0,
		munitions => 15
	};
	my $haro6 = {
		id => 6,
		nom => "violet",
		couleur => "violet",
		precision => 6,
		esquive => 1,
		charisme => 10,
		armure => 8,
		points_vie => 20,
		points_vie_total => 20,
		arme => "Piou-piou",
		puissance => 8,
		coups => 2,
		recharge => 0,
		munitions => 20
	};
      my $haro7 = {
		id => 7,
		nom => "orange",
		couleur => "orange",
		precision => 5,
		esquive => 3,
		charisme => 4,
		armure => 6,
		points_vie => 20,
		points_vie_total => 20,
		arme => "M16",
		puissance => 15,
		coups => 2,
		recharge => 1,
		munitions => 18
	};
	my $haro8 = {
		id => 8,
		nom => "cyan",
		couleur => "teal",
		precision => 3,
		esquive => 1,
		charisme => 2,
		armure => 6,
		points_vie => 20,
		points_vie_total => 20,
		arme => "MG42",
		puissance => 15,
		coups => 3,
		recharge => 2,
		munitions => 12
	};

	if ($ref == 1) { return $haro1;}
	if ($ref == 2) { return $haro2;}
	if ($ref == 3) { return $haro3;}
	if ($ref == 4) { return $haro4;}
	if ($ref == 5) { return $haro5;}
	if ($ref == 6) { return $haro6;}
	if ($ref == 7) { return $haro7;}
	if ($ref == 7) { return $haro7;}
	if ($ref == 8) { return $haro8;}
}

sub initiative {
	# renvoie nombre de coups d'avance du haro champion

	my $jet1 = taunt($_champion);
	my $jet2 = taunt($_challenger);

	return $jet1 - $jet2;
}

sub taunt {
	my ($haro) = @_;
	my @return;
	my ($texte, $taunt);

	# prends en parametre un haro
	# envoie un message de taunt approprie sur la sortie, et renvoie le resultat du jet

	my $de = int(rand(12))+1;

	if ($de == 12) {
		# Envoie un message de taunt qui faile violemment

		push(@return, linemaker(nom($haro)." : <insert here a EPIC FAILing taunt>"));
		Giraf::Core::emit(@return);

		$haro->{charisme_fail}++;
		return -1;
	}
	elsif ($de > $haro->{charisme}) {
		# Envoie un mauvais message de taunt (ou rien)

		push(@return, linemaker(nom($haro)." : ..."));
		Giraf::Core::emit(@return);

		return 0;
	}
	else {
		# Envoie un message de taunt qui win

		push(@return, linemaker(nom($haro)." : <insert here a winning taunt> !"));
		Giraf::Core::emit(@return);

		return 1;
	}
}

sub combat {
	my ($initiative) = @_;

	# Déroulement du combat

	for( my $i = 1; round($initiative, $i) && ($i != 50); $i++){};
	# print(sante()."\n");

	if ($_champion->{points_vie} > 0) {
		return 1;
	}
	if ($_challenger->{points_vie} > 0) {
		return -1;
	}
	return 0;
}

sub debuffs {
	$_champion->{charisme} -= $_champion->{charisme_fail};
	$_champion->{precision} -= $_champion->{precision_fail};
	$_challenger->{charisme} -= $_challenger->{charisme_fail};
	$_challenger->{precision} -= $_challenger->{precision_fail};

	$_champion->{charisme_fail} = 0;
	$_champion->{precision_fail} = 0;
	$_challenger->{charisme_fail} = 0;
	$_challenger->{precision_fail} = 0;

	if ($_champion->{charisme} < 1) { $_champion->{charisme} = 1; }
	if ($_champion->{precision} < 1) { $_champion->{precision} = 1; }
	if ($_challenger->{charisme} < 1) { $_challenger->{charisme} = 1; }
	if ($_challenger->{precision} < 1) { $_challenger->{precision} = 1; }
}

sub round {
	my ($initiative, $i) = @_;

	my @return;

	# Déroulement d'un round
	push(@return, linemaker("Round ".$i));
	push(@return, linemaker(sante()));

	Giraf::Core::emit(@return);
	undef @return;

	debuffs();
	my ($k, $l);

	if ($initiative > 0) {
		$k = $i;
		$l = $i - $initiative;
	}
	else {
		$k = $i + $initiative;
		$l = $i;
	}

	if ($i > -$initiative) {
		push(@return, attaque($_champion, $_challenger, $k));
	}
	else {
		push(@return, linemaker(nom($_champion)." n'as pas encore compris que le match avait commencé."));
	}

	if ($i > $initiative) {
		push(@return, attaque($_challenger, $_champion, $l));
	}
	else {
		push(@return, linemaker(nom($_challenger)." n'as pas encore compris que le match avait commencé."));
	}

	Giraf::Core::emit(@return);

	return ($_champion->{points_vie} > 0) && ($_challenger->{points_vie} > 0) && ($_champion->{munitions} || $_challenger->{munitions});
}

sub attaque {
	my ($haro1, $haro2, $i) = @_;

	my @return;

	# Une attaque

	if ((($i - 1) % ($haro1->{recharge} + 1)) || (!$haro1->{munitions})) {
		if(taunt($haro1) == 1) {
			$haro2->{precision_fail}++;
			push(@return, linemaker(nom($haro2)." semble destabilisé"));
		}
	}
	else {
		for (my $j = 0; $j < $haro1->{coups}; $j++) {
			my $de1 = int(rand(12))+1;
			my $de2 = int(rand(12))+1;
			my $armure = $haro2->{armure} - int(rand($haro2->{armure}/2));

			if ($armure > $haro1->{puissance}) {
				$armure = $haro1->{puissance};
			}

			if ($de1 == 12) {
				$haro1->{charisme_fail}++;
				if ($de2 == 12) {
					push(@return, linemaker(nom($haro1)." et ".nom($haro2)." trébuchent tous les deux comme des n[c=rouge]00[/c]bs !"));
				}
				else {
					push(@return, linemaker(nom($haro1)." trébuche comme un n[c=rouge]00[/c]b !"));
				}
			}
			elsif ($de1 > $haro1->{precision}) {
				push(@return, linemaker(nom($haro1)." tire avec son ".$haro1->{arme}." et rate."));
				if ($de2 == 12) {
					$haro2->{charisme_fail}++;
					push(@return, linemaker(nom($haro2)." se casse la figure et se prends quand même le coup, le n[c=rouge]00[/c]b ! ".($haro1->{puissance} - $armure)." dégats infligés."));
					$haro2->{points_vie} -= ($haro1->{puissance} - $armure);
				}
			}
			else {
				my $chaine = nom($haro1)." tire avec son ".$haro1->{arme};
				if ($de2 == 12) {
					$haro2->{charisme_fail}++;
					push(@return, linemaker($chaine.", ".nom($haro2)." glisse et perds son armure (comme un n[c=rouge]00[/c]b) : ".$haro1->{puissance}." dégats infligés."));
					$haro2->{points_vie} -= $haro1->{puissance};
				}
				elsif ($de2 > $haro2->{esquive}) {
					push(@return, linemaker($chaine." et inflige ".($haro1->{puissance} - $armure)." dégats à ".nom($haro2)."."));
					$haro2->{points_vie} -= ($haro1->{puissance} - $armure);
				}
				else {
					push(@return, linemaker($chaine." mais ".nom($haro2)." esquive la balle."));
				}
			}
		}
		$haro1->{munitions} -= $haro1->{coups};
	}
	return @return;
}

sub match {

	#####################################################################
	# Chargement des caractéristiques des deux haros qui vont combattre #
	#####################################################################
	$_champion = chargement(2);
	$_challenger = chargement(5);

	# ouverture des paris
	$_paris_ouverts=1;

	for (my $i=5; $i>0; $i--) {
		# print("Le prochain duel va opposer ".nom($_champion)." et ".nom($_challenger)." dans ".$i." minutes\n");
		#sleep(60);
	}

	#fermeture des paris
	$_paris_ouverts=0;

	for (my $i=5; $i>0; $i--) {
		print($i."\n");
		#sleep(1);
	}

	##############
	# Initiative #
	##############

	my $initiative = initiative();

	##########
	# Combat #
	##########

	combat($initiative);
}

# match();
# stats();

sub stats {
	my $nul = 0;
	my $nuls = 0;
	my $statistiques = "Statistiques :";

	my @stats_table = (
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0]
	);

	for (my $j = 2; $j < 9; $j++) {
	for (my $k = 1; $k < $j; $k++) {

		for (my $i = 0; $i < 10000; $i++) {
			$_champion = chargement($k);
			$_challenger = chargement($j);

			my $stat = combat(initiative());

			if ($stat == 1) {
				$stats_table[$k-1][$j-1]++;
				$stats_table[$k-1][8]++;
				$stats_table[8][$j-1]++;
			}
			if ($stat == -1) {
				$stats_table[$j-1][$k-1]++;
				$stats_table[$j-1][8]++;
				$stats_table[8][$k-1]++;
			}
			if($stat == 0) {
				$nuls++;
				$nul++;
			}
		}
		# $statistiques .= nom($_champion)." vs ".nom($_challenger)." : ".$_champion_win." / ".$_challenger_win;
		# $statistiques .= ", nuls : ".(10000 - $_champion_win - $_challenger_win)." / 10000 matches\n";

		print("Stats pour ".nom($_champion)." vs ".nom($_challenger)." terminées, nuls : ".int($nul/100)."%\n");
		$nul = 0;
	}}

	for (my $j = 0; $j < 9; $j++) {
		$statistiques .= "\n+";
		for (my $k = 0; $k < 9; $k++) {
			$statistiques .= "----+";
		}
		$statistiques .= "\n|";
		for (my $k = 0; $k < 9; $k++) {
			$statistiques .= " ".int($stats_table[$j][$k] / (100 + (700 * ($k == 8 || $j == 8))))." |";
		}
	}
	$statistiques .= "\n+";
	for (my $k = 0; $k < 9; $k++) {
		$statistiques .= "----+";
	}

	print($statistiques."\n");

	print("Nuls : ".int($nuls / 3400)."%\n");
}


######## ##     ## ######## ##    ## ########    ##     ##    ###    ##    ## ########  ##       ######## ########   ######  
##       ##     ## ##       ###   ##    ##       ##     ##   ## ##   ###   ## ##     ## ##       ##       ##     ## ##    ## 
##       ##     ## ##       ####  ##    ##       ##     ##  ##   ##  ####  ## ##     ## ##       ##       ##     ## ##       
######   ##     ## ######   ## ## ##    ##       ######### ##     ## ## ## ## ##     ## ##       ######   ########   ######  
##        ##   ##  ##       ##  ####    ##       ##     ## ######### ##  #### ##     ## ##       ##       ##   ##         ## 
##         ## ##   ##       ##   ###    ##       ##     ## ##     ## ##   ### ##     ## ##       ##       ##    ##  ##    ## 
########    ###    ######## ##    ##    ##       ##     ## ##     ## ##    ## ########  ######## ######## ##     ##  ######  

sub hb_init {
  my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
  $_[KERNEL]->alias_set('harobattle_core');
}
 
sub hb_stop {
}

sub hb_original {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0 ];
	my @return;

	Giraf::Core::debug("hb_original");

	my $challenger = int(rand(7) + 1);

	if($challenger >= $_champion->{id}) {
		$challenger++;
	}

	$_challenger = chargement($challenger);

	push(@return, linemaker("Le prochain duel va opposer le champion ".nom($_champion)." au challenger ".nom($_challenger)." dans 5 minutes."));
	push(@return, linemaker("Les paris sont ouverts !"));

	$_paris_ouverts = 1;

	$kernel->delay_set('harobattle_annonce', 60, $dest, 4);

	Giraf::Core::emit(@return);
}

sub hb_championnat {
}

sub hb_annonce {
	my ($kernel, $heap, $dest, $delai) = @_[ KERNEL, HEAP, ARG0, ARG1 ];
	my @return;
	my $new_delai = $delai - 1;

	Giraf::Core::debug("hb_annonce");

	push(@return, linemaker("Le prochain duel va opposer ".nom($_champion)." et ".nom($_challenger)." dans ".$delai." minutes."));

	if ($new_delai) {
		$kernel->delay_set('harobattle_annonce', 60, $dest, $new_delai);
	}
	else {
		$kernel->delay_set('harobattle_initiative', 60, $dest);
	}
	Giraf::Core::emit(@return);
}

sub hb_initiative {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0 ];

	Giraf::Core::debug("hb_initiative");

	$_paris_ouverts = 0;
	my $initiative = initiative();

	$kernel->delay_set('harobattle_round', 15, $dest, $initiative, 1);
}

sub hb_round {
	my ($kernel, $heap, $dest, $initiative, $i) = @_[ KERNEL, HEAP, ARG0, ARG1, ARG2 ];

	Giraf::Core::debug("hb_round");

	if(round($initiative, $i)) {
		$kernel->delay_set('harobattle_round', 20, $dest, $initiative, $i + 1);
	}
	else {
		$kernel->delay_set('harobattle_atwi', 20, $dest);
	}
}

sub hb_atwi {
	my ($kernel, $heap, $dest) = @_[ KERNEL, HEAP, ARG0 ];
	my @return;

	Giraf::Core::debug("hb_atwi");

	push(@return, linemaker(sante()));

	if (($_champion->{munitions} == 0) && ($_challenger->{munitions} == 0) && ($_champion->{points_vie} > 0) && ($_challenger->{points_vie} >0)) {
		push(@return, linemaker("Match nul ! Le champion ".nom($_champion)." conserve son titre."));
		$_champion = chargement($_champion->{id});
	}
	elsif ($_champion->{points_vie} > 0) {
		push(@return, linemaker("Bravo à ".nom($_champion).", qui conserve son titre de champion."));
		$_champion = chargement($_champion->{id});
	}
	elsif ($_challenger->{points_vie} > 0) {
		push(@return, linemaker("Bravo à ".nom($_challenger).", le nouveau champion, ".nom($_champion)." est humilié."));
		$_champion = chargement($_challenger->{id});
	}
	else {
		push(@return, linemaker("Match nul ! Le champion ".nom($_champion)." conserve son titre."));
		$_champion = chargement($_champion->{id});
	}

	if($_continuer) {
		push(@return, linemaker("Prochain match dans 1 minute."));
		$kernel->delay_set('harobattle_original', 60, $dest);
	}
	else {
		push(@return, linemaker("C'est tout pour le moment, rendez-vous très bientôt."));
		$_match_en_cours = 0;
	}

	Giraf::Core::emit(@return);
}

POE::Session->create(
	inline_states => {
		_start => \&Giraf::Modules::HaroBattle::hb_init,
		_stop => \&Giraf::Modules::HaroBattle::hb_stop,
		harobattle_original => \&Giraf::Modules::HaroBattle::hb_original,
		harobattle_championnat => \&Giraf::Modules::HaroBattle::hb_championnat,
		harobattle_annonce => \&Giraf::Modules::HaroBattle::hb_annonce,
		harobattle_initiative => \&Giraf::Modules::HaroBattle::hb_initiative,
		harobattle_round => \&Giraf::Modules::HaroBattle::hb_round,
		harobattle_atwi => \&Giraf::Modules::HaroBattle::hb_atwi,
	},
);

1;

