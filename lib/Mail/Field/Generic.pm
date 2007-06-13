package Mail::Field::Generic;

use Carp;
use base 'Mail::Field';

=chapter NAME
Mail::Field::Generic - implementation for inspecific fields

=chapter DESCRIPTION
A generic package for those not defined in their own package. This is
fine for fields like Subject, X-Mailer etc. where the field holds only
a string of no particular importance/format.

=chapter METHODS

=method create OPTIONS
=option  Text STRING
=default Text ''
=cut

sub create
{   my ($self, %arg) = @_;
    $self->{Text} = delete $arg{Text};

    croak "Unknown options " . join(",", keys %arg)
       if %arg;

    $self;
}

=method parse [STRING]
Set the new text, which is empty when no STRING is provided.
=cut

sub parse
{   my $self = shift;
    $self->{Text} = shift || "";
    $self;
}

=method stringify
Returns the field as string.
=cut

sub stringify { shift->{Text} }

1;
