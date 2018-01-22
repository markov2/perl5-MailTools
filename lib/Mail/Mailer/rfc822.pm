# This code is part of the bundle MailTools.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md for Copyright.
# Licensed under the same terms as Perl itself.

package Mail::Mailer::rfc822;
use base 'Mail::Mailer';

use strict;

sub set_headers
{   my ($self, $hdrs) = @_;

    local $\ = "";

    foreach (keys %$hdrs)
    {   next unless m/^[A-Z]/;

        foreach my $h ($self->to_array($hdrs->{$_}))
        {   $h =~ s/\n+\Z//;
            print $self "$_: $h\n";
        }
    }

    print $self "\n";	# terminate headers
}

1;
