use strict;
package Reload;
use vars qw($VERSION $Debug %Stat);
$VERSION = "1.07";

sub check {
    my $c=0;
    while (my($key,$file) = each %INC) {
	next if $file eq $INC{"Module/Reload.pm"};  #too confusing
	local $^W = 0;
	my $mtime = (stat $file)[9];
	$Stat{$file} = $^T
	    unless defined $Stat{$file};
	warn "Module::Reload: stat '$file' got $mtime >? $Stat{$file}\n"
	    if $Debug >= 3;
	if ($mtime > $Stat{$file}) {
	    delete $INC{$key};
	    eval { 
		local $SIG{__WARN__} = \&warn;
		require $key;
	    };
	    if ($@) {
		warn "Module::Reload: error during reload of '$key': $@\n"
	    }
	    elsif ($Debug) {
		warn "Module::Reload: process $$ reloaded '$key'\n"
		    if $Debug == 1;
		warn("Module::Reload: process $$ reloaded '$key' (\@INC=".
		     join(', ',@INC).")\n")
		    if $Debug >= 2;
	    }
	    ++$c;
	}
	$Stat{$file} = $mtime;
    }
    $c;
}

1;

__END__

=head1 NAME

Module::Reload - Reload %INC files when updated on disk

=head1 SYNOPSIS

  Module::Reload->check;

=head1 DESCRIPTION

When Perl pulls a file via C<require>, it stores the filename in the
global hash C<%INC>.  The next time Perl tries to C<require> the same
file, it sees the file in C<%INC> and does not reload from disk.  This
module's handler iterates over C<%INC> and reloads the file if it has
changed on disk. 

Set $Module::Reload::Debug to enable debugging output.

=head1 BUGS

A growing number of pragmas (C<base>, C<fields>, etc.) assume that
they are loaded once only.  When you reload the same file again, they
tend to become confused and break.  If you feel motivated to submit
patches for these problems, I would encourage that.

=head1 SEE ALSO

Event

=head1 AUTHOR

Copyright © 1997-1998 Doug MacEachern & Joshua Pritikin.  All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty.  It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)
