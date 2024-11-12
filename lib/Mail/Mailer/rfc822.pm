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

        if (_is_single_instance_header($_))
        {
            print $self "$_: ", join(', ', $self->to_array($hdrs->{$_})), "\n";
        }
        else {
            foreach my $h ($self->to_array($hdrs->{$_})) {
                $h =~ s/\n+\Z//;
                print $self "$_: $h\n";
            }
        }
    }

    print $self "\n";	# terminate headers
}

# RFC5322 says that these headers should only appear ONCE in the message
sub _is_single_instance_header {
  my $header = shift;

  return 1 if lc $header eq 'reply-to';
  return 1 if lc $header eq 'to';
  return 1 if lc $header eq 'cc';
  return 1 if lc $header eq 'bcc';
  return 0;
}

1;
