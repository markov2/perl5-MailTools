# This code is part of the bundle MailTools.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md for Copyright.
# Licensed under the same terms as Perl itself.

package Mail::Send;

use strict;

use Mail::Mailer ();

sub Version { our $VERSION }

#------------------
=chapter NAME

Mail::Send - Simple electronic mail interface

=chapter SYNOPSIS

  require Mail::Send;

  $msg = Mail::Send->new;
  $msg = Mail::Send->new(Subject => 'example', To => 'timbo');

  $msg->to('user@host');
  $msg->to('user@host', 'user2@example.com');
  $msg->subject('example subject');
  $msg->cc('user@host');
  $msg->bcc('someone@else');

  $msg->set($header, @values);
  $msg->add($header, @values);
  $msg->delete($header);

  # Launch mailer and set headers. The filehandle returned
  # by open() is an instance of the Mail::Mailer class.
  # Arguments to the open() method are passed to the Mail::Mailer
  # constructor.

  $fh = $msg->open;   # some default mailer
  $fh = $msg->open('sendmail'); # explicit
  print $fh "Body of message";
  $fh->close          # complete the message and send it
      or die "couldn't send whole message: $!\n";

=chapter DESCRIPTION
M<Mail::Send> creates e-mail messages without using the M<Mail::Header>
knowledge, which means that all escaping and folding must be done by
you!  Also: do not forget to escape leading dots.  Simplicity has its price.

When you have time, take a look at M<Mail::Transport> which is part of
the MailBox suite.

=chapter METHODS

=section Constructors

=c_method new PAIRS
A list of header fields (provided as key-value PAIRS) can be used to
initialize the object, limited to the few provided as method: C<to>,
C<subject>, C<cc>, and C<bcc>.  For other header fields, use M<add()>.

=cut

sub new(@)
{   my ($class, %attr) = @_;
    my $self = bless {}, $class;

    while(my($key, $value) = each %attr)
    {	$key = lc $key;
        $self->$key($value);
    }

    $self;
}

#---------------
=section Header fields

=method set $fieldname, @values
The @values will replace the old values for the $fieldname.  Returned is
the LIST of values after modification.
=cut

sub set($@)
{   my ($self, $hdr, @values) = @_;
    $self->{$hdr} = [ @values ] if @values;
    @{$self->{$hdr} || []};	# return new (or original) values
}

=method add $fieldname, @values
Add values to the list of defined values for the $fieldname.
=cut

sub add($@)
{   my ($self, $hdr, @values) = @_;
    push @{$self->{$hdr}}, @values;
}

=method delete $fieldname
=cut

sub delete($)
{   my($self, $hdr) = @_;
    delete $self->{$hdr};
}

=method to @values
=method cc @values
=method bcc @values
=method subject @values
=cut

sub to		{ my $self=shift; $self->set('To', @_); }
sub cc		{ my $self=shift; $self->set('Cc', @_); }
sub bcc		{ my $self=shift; $self->set('Bcc', @_); }
sub subject	{ my $self=shift; $self->set('Subject', join (' ', @_)); }

#---------------
=section Sending

=method open %options
The %options are used to initiate a mailer object via
M<Mail::Mailer::new()>.  Then M<Mail::Mailer::open()> is called
with the knowledge collected in this C<Mail::Send> object.

Be warned: this module implements raw smtp, which means that you have
to escape lines which start with a dot, by adding one in front.
=cut

sub open(@)
{   my $self = shift;
    Mail::Mailer->new(@_)->open($self);
}

1;
