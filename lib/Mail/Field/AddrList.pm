use strict;

package Mail::Field::AddrList;
use base 'Mail::Field';

use Carp;
use Mail::Address;

=chapter NAME 

Mail::Field::AddrList - object representation of e-mail address lists

=chapter SYNOPSIS

  use Mail::Field::AddrList;

  $to   = Mail::Field->new('To');
  $from = Mail::Field->new('From', 'poe@daimi.aau.dk (Peter Orbaek)');
  
  $from->create('foo@bar.com' => 'Mr. Foo', poe => 'Peter');
  $from->parse('foo@bar.com (Mr Foo), Peter Orbaek <poe>');

  # make a RFC822 header string
  print $from->stringify(),"\n";

  # extract e-mail addresses and names
  @addresses = $from->addresses(); # strings
  @names     = $from->names();     # strings
  @addr      = $from->addr_list(); # Mail::Address objects (v2.00)

  # adjoin a new address to the list
  $from->set_address('foo@bar.com', 'Mr. Foo');

=chapter DESCRIPTION

Defines parsing and formatting of address field, for the following
fields: C<To>, C<From>, C<Cc>, C<Reply-To>, and C<Sender>.

All the normally used features of the address field specification of
RFC2822 are implemented, but some complex (and therefore hardly ever used)
constructs will not be inderstood.  Use M<Mail::Message::Field::Full>
in MailBox if you need full RFC compliance.

=chapter METHODS
=cut

my $x = bless [];
$x->register('To');
$x->register('From');
$x->register('Cc');
$x->register('Reply-To');
$x->register('Sender');

sub create(@)
{   my ($self, %arg)  = @_;
    $self->{AddrList} = {};

    while(my ($e, $n) = each %arg)
    {   $self->{AddrList}{$e} = Mail::Address->new($n, $e);
    }

    $self;
}

sub parse($)
{   my ($self, $string) = @_;
    foreach my $a (Mail::Address->parse($string))
    {   my $e = $a->address;
	$self->{AddrList}{$e} = $a;
    }
    $self;
}

sub stringify()
{   my $self = shift;
    join(", ", map { $_->format } values %{$self->{AddrList}});
}

=section Smart accessors

=method addresses
Returns a list if email addresses, found in the field content.
=cut

sub addresses { keys %{shift->{AddrList}} }

=method addr_list
Returns the collected M<Mail::Address> objects.
=cut

# someone forgot to implement a method to return the Mail::Address
# objects.  Added in 2.00; a pitty that the name addresses() is already
# given :(  That one should have been named emails()
sub addr_list { values %{shift->{AddrList}} }

=method names
Returns a list of nicely formatted named, for each of the addresses
found in the content.
=cut

sub names { map { $_->name } values %{shift->{AddrList}} }

=method set_address EMAIL, NAME
Add/replace an EMAIL address to the field.
=cut

sub set_address($$)
{   my ($self, $email, $name) = @_;
    $self->{AddrList}{$email} = Mail::Address->new($name, $email);
    $self;
}

1;
