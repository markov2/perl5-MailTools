#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Field::Generic;
use base 'Mail::Field';

use strict;
use warnings;

use Carp;

#--------------------
=chapter NAME

Mail::Field::Generic - implementation for inspecific fields

=chapter SYNOPSIS

  use Mail::Field;
  my $field = Mail::Field->new('Subject', 'some subject text');
  my $field = Mail::Field->new(subject => 'some subject text');

=chapter DESCRIPTION

A generic implementation for header fields without own
implementation. This is fine for fields like C<Subject>, C<X-Mailer>,
etc., where the field holds only a string of no particular
importance/format.

=chapter METHODS

=method create %options
=option  Text STRING
=default Text ''

=cut

sub create
{	my ($self, %arg) = @_;
	$self->{Text} = delete $arg{Text};

	! keys %arg or croak "Unknown options " . join(",", keys %arg);

	$self;
}

=method parse [STRING]
Set the new text, which is empty when no STRING is provided.
=cut

sub parse
{	my $self = shift;
	$self->{Text} = shift || "";
	$self;
}

sub stringify { $_[0]->{Text} }

1;
