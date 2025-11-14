#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Mailer::qmail;
use base 'Mail::Mailer::rfc822';

use strict;
use warnings;

sub exec($$$$)
{	my($self, $exe, $args, $to, $sender) = @_;
	my $address = defined $sender && $sender =~ m/\<(.*?)\>/ ? $1 : $sender;

	exec($exe, (defined $address ? "-f$address" : ()));
	die "ERROR: cannot run $exe: $!";
}

1;
