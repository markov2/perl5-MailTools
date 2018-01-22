# This code is part of the bundle MailTools.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md for Copyright.
# Licensed under the same terms as Perl itself.

package Mail::Mailer::qmail;
use base 'Mail::Mailer::rfc822';

use strict;

sub exec($$$$)
{   my($self, $exe, $args, $to, $sender) = @_;
    my $address = defined $sender && $sender =~ m/\<(.*?)\>/ ? $1 : $sender;

    exec($exe, (defined $address ? "-f$address" : ()));
    die "ERROR: cannot run $exe: $!";
}

1;
