use strict;

package Mail::Mailer;
use base 'IO::Handle';

use POSIX qw/_exit/;

use Carp;
use Config;

=chapter NAME

Mail::Mailer - Simple interface to electronic mailing mechanisms 

=chapter SYNOPSIS

  use Mail::Mailer;
  use Mail::Mailer qw(mail);    # specifies default mailer

  $mailer = Mail::Mailer->new;
  $mailer = Mail::Mailer->new($type, @args);

  $mailer->open(\%headers);
  print $mailer $body;
  $mailer->close
      or die "couldn't send whole message: $!\n";


=chapter DESCRIPTION

Sends mail using any of the built-in methods.  As TYPE argument
to M<new()>, you can specify any of

=over 4

=item C<sendmail>
Use the C<sendmail> program to deliver the mail.

=item C<smtp>

Use the C<smtp> protocol via Net::SMTP to deliver the mail. The server
to use can be specified in C<@args> with

    $mailer = Mail::Mailer->new('smtp', Server => $server);

The smtp mailer does not handle C<Cc> and C<Bcc> lines, neither their
C<Resent-*> fellows. The C<Debug> options enables debugging output
from C<Net::SMTP>.

You may also use the C<< Auth => [ $user, $password ] >> option for SASL
authentication (requires L<Authen::SASL> and L<MIME::Base64>).

=item C<qmail>

Use qmail's qmail-inject program to deliver the mail.

=item C<testfile>

Used for debugging, this displays the data to the file named in
C<$Mail::Mailer::testfile::config{outfile}> which defaults to a file
named C<mailer.testfile>.  No mail is ever sent.

=back

C<Mail::Mailer> will search for executables in the above order. The
default mailer will be the first one found.

=chapter METHODS

=section Constructors
=cut


sub is_exe($);

sub Version { our $VERSION }

our @Mailers =
  ( sendmail => '/usr/lib/sendmail;/usr/sbin/sendmail;/usr/ucblib/sendmail'
  , smtp     => undef
  , qmail    => '/usr/sbin/qmail-inject;/var/qmail/bin/qmail-inject'
  , testfile => undef
  );

push @Mailers, map { split /\:/, $_, 2 }
                   split /$Config{path_sep}/, $ENV{PERL_MAILERS}
    if $ENV{PERL_MAILERS};

our %Mailers = @Mailers;
our $MailerType;
our $MailerBinary;

# does this really need to be done? or should a default mailer be specfied?

$Mailers{sendmail} = 'sendmail'
    if $^O eq 'os2' && ! is_exe $Mailers{sendmail};

if($^O =~ m/MacOS|VMS|MSWin|os2|NetWare/i )
{   $MailerType   = 'smtp';
    $MailerBinary = $Mailers{$MailerType};
}
else
{   for(my $i = 0 ; $i < @Mailers ; $i += 2)
    {   $MailerType = $Mailers[$i];
        if(my $binary = is_exe $Mailers{$MailerType})
        {   $MailerBinary = $binary;
            last;
        }
    }
}

sub import
{   shift;  # class
    @_ or return;

    my $type = shift;
    my $exe  = shift || $Mailers{$type};

    is_exe $exe
        or carp "Cannot locate '$exe'";

    $MailerType = $type;
    $Mailers{$MailerType} = $exe;
}

sub to_array($)
{   my ($self, $thing) = @_;
    ref $thing ? @$thing : $thing;
}

sub is_exe($)
{   my $exe = shift || '';

    foreach my $cmd (split /\;/, $exe)
    {   $cmd =~ s/^\s+//;

        # remove any options
        my $name = ($cmd =~ /^(\S+)/)[0];

        # check for absolute or relative path
        return $cmd
            if -x $name && ! -d $name && $name =~ m![\\/]!;

        if(defined $ENV{PATH})
        {   foreach my $dir (split /$Config{path_sep}/, $ENV{PATH})
            {   return "$dir/$cmd"
        	    if -x "$dir/$name" && ! -d "$dir/$name";
            }
        }
    }
    0;
}

=c_method new TYPE, ARGS
The TYPE is one of the back-end sender implementations, as described in
the DESCRIPTION chapter of this manual page.  The ARGS are passed to
that back-end.
=cut

sub new($@)
{   my ($class, $type, @args) = @_;

    unless($type)
    {   $MailerType or croak "No MailerType specified";

        warn "No real MTA found, using '$MailerType'"
             if $MailerType eq 'testfile';

        $type = $MailerType;
    }

    my $exe = $Mailers{$type};

    if(defined $exe)
    {   $exe   = is_exe $exe
            if defined $type;

        $exe ||= $MailerBinary
            or croak "No mailer type specified (and no default available), thus can not find executable program.";
    }

    $class = "Mail::Mailer::$type";
    eval "require $class" or die $@;

    my $glob = $class->SUPER::new;   # object is a GLOB!
    %{*$glob} = (Exe => $exe, Args => [ @args ]);
    $glob;
}

=method open HASH
The HASH consists of key and value pairs, the key being the name of
the header field (eg, C<To>), and the value being the corresponding
contents of the header field.  The value can either be a scalar
(eg, C<gnat@frii.com>) or a reference to an array of scalars
(C<< eg, ['gnat@frii.com', 'Tim.Bunce@ig.co.uk'] >>).

=cut

sub open($)
{   my ($self, $hdrs) = @_;
    my $exe    = *$self->{Exe};   # no exe, then direct smtp
    my $args   = *$self->{Args};

    my @to     = $self->who_to($hdrs);
    my $sender = $self->who_sender($hdrs);
    
    $self->close;	# just in case;

    if(defined $exe)
    {   # Fork and start a mailer
        my $child = open $self, '|-';
        defined $child or die "Failed to send: $!";

        if($child==0)
        {   # Child process will handle sending, but this is not real exec()
            # this is a setup!!!
            unless($self->exec($exe, $args, \@to, $sender))
            {   warn $!;     # setup failed
                _exit(1);    # no DESTROY(), keep it for parent
            }
        }
    }
    else
    {   $self->exec($exe, $args, \@to, $sender)
            or die $!;
    }

    $self->set_headers($hdrs);
    $self;
}

sub _cleanup_hdrs($)
{   foreach my $h (values %{(shift)})
    {   foreach (ref $h ? @$h : $h)
        {   s/\n\s*/ /g;
            s/\s+$//;
        }
    }
}

sub exec($$$$)
{   my($self, $exe, $args, $to, $sender) = @_;

    # Fork and exec the mailer (no shell involved to avoid risks)
    my @exe = split /\s+/, $exe;
    exec @exe, @$args, @$to;
}

sub can_cc { 1 }	# overridden in subclass for mailer that can't

sub who_to($)
{   my($self, $hdrs) = @_;
    my @to = $self->to_array($hdrs->{To});
    unless($self->can_cc)  # Can't cc/bcc so add them to @to
    {   push @to, $self->to_array($hdrs->{Cc} ) if $hdrs->{Cc};
        push @to, $self->to_array($hdrs->{Bcc}) if $hdrs->{Bcc};
    }
    @to;
}

sub who_sender($)
{   my ($self, $hdrs) = @_;
    ($self->to_array($hdrs->{Sender} || $hdrs->{From}))[0];
}

sub epilogue {
    # This could send a .signature, also see ::smtp subclass
}

sub close(@)
{   my $self = shift;
    fileno $self or return;

    $self->epilogue;
    CORE::close $self;
}

sub DESTROY { shift->close }

=chapter DETAILS

=section ENVIRONMENT VARIABLES

=over 4

=item PERL_MAILERS

Augments/override the build in choice for binary used to send out
our mail messages.

Format:

    "type1:mailbinary1;mailbinary2;...:type2:mailbinaryX;...:..."

Example: assume you want you use private sendmail binary instead
of mailx, one could set C<PERL_MAILERS> to:

    "mail:/does/not/exists:sendmail:$HOME/test/bin/sendmail"

On systems which may include C<:> in file names, use C<|> as separator
between type-groups.

    "mail:c:/does/not/exists|sendmail:$HOME/test/bin/sendmail"

=back

=section BUGS

Mail::Mailer does not help with folding, and does not protect
against various web-script hacker attacks, for instance where
a new-line is inserted in the content of the field.

=cut

1;
