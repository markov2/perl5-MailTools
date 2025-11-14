#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Mailer::sendmail;
use base 'Mail::Mailer::rfc822';

use strict;
use warnings;

sub exec($$$$)
{	my($self, $exe, $args, $to, $sender) = @_;
	# Fork and exec the mailer (no shell involved to avoid risks)

	# We should always use a -t on sendmail so that Cc: and Bcc: work
	#  Rumor: some sendmails may ignore or break with -t (AIX?)
	# Chopped out the @$to arguments, because -t means
	# they are sent in the body, and postfix complains if they
	# are also given on command line.

	exec $exe, '-t', @$args;
}

1;
