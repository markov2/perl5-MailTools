package Mail::Internet;
use strict;
# use warnings?  probably breaking too much code

use Carp;
use Mail::Header;
use Mail::Util    qw/mailaddress/;
use Mail::Address;

=head1 NAME

Mail::Internet - manipulate email messages

=chapter SYNOPSIS

  use Mail::Internet;
  my $msg = Mail::Internet->new(\*STDIN);

=chapter DESCRIPTION

This package implements reading, creating, manipulating, and writing email
messages.  Sometimes, the implementation tries to be too smart, but in
the general case it works as expected.

If you start writing a B<new application>, you should use the L<Mail::Box>
distribution, which has more features and handles messages much better
according to the RFCs.  See L<http://perl.overmeer.net/mailbox/>.
You may also chose L<MIME::Entity>, to get at least some multipart
support in your application.

=chapter METHODS

=section Constructors

=ci_method new [ARG], [OPTIONS]

ARG is optional and may be either a file descriptor (reference to a GLOB)
or a reference to an array. If given the new object will be
initialized with headers and body either from the array of read from 
the file descriptor.

The M<Mail::Header::new()> OPTIONS C<Modify>, C<MailFrom> and C<FoldLength>
may also be given.

=option  Header Mail::Header
=default Header C<undef>

The value of this option should be a M<Mail::Header> object. If given then
C<Mail::Internet> will not attempt to read a mail header from C<ARG>, if
it was specified.

=option  Body ARRAY-of-LINES
=default Body []
The value of this option should be a reference to an array which contains
the lines for the body of the message. Each line should be terminated with
C<\n> (LF). If Body is given then C<Mail::Internet> will not attempt to
read the body from C<ARG> (even if it is specified).

=cut

sub new(@)
{   my $call  = shift;
    my $arg   = @_ % 2 ? shift : undef;
    my %opt   = @_;

    my $class = ref($call) || $call;
    my $self  = bless {}, $class;

    $self->{mail_inet_head} = $opt{Header} if exists $opt{Header};
    $self->{mail_inet_body} = $opt{Body}   if exists $opt{Body};

    my $head = $self->head;
    $head->fold_length(delete $opt{FoldLength} || 79);
    $head->mail_from($opt{MailFrom}) if exists $opt{MailFrom};
    $head->modify(exists $opt{Modify} ? $opt{Modify} : 1);

    if(!defined $arg) { }
    elsif(ref($arg) eq 'ARRAY')
    {   $self->header($arg) unless exists $opt{Header};
        $self->body($arg)   unless exists $opt{Body};
    }
    elsif(defined fileno($arg))
    {   $self->read_header($arg) unless exists $opt{Header};
        $self->read_body($arg)   unless exists $opt{Body};
    }
    else
    {   croak "couldn't understand $arg to Mail::Internet constructor";
    }

    $self;
}

=method read FILEHANDLE
Read a message from the FILEHANDLE into an already existing message
object.  Better use M<new()> with the FILEHANDLE as first argument.
=cut

sub read(@)
{   my $self = shift;
    $self->read_header(@_);
    $self->read_body(@_);
}

sub read_body($)
{   my ($self, $fd) = @_;
    $self->body( [ <$fd> ] );
}

sub read_header(@)
{   my $head = shift->head;
    $head->read(@_);
    $head->header;
}

=method extract ARRAY-of-LINES
Extract header and body from an ARRAY of message lines.  Requires an
object already created with M<new()>, which contents will get overwritten.
=cut

sub extract($)
{   my ($self, $lines) = @_;
    $self->head->extract($lines);
    $self->body($lines);
}

=method dup
Duplicate the message as a whole.  Both header and body will be
deep-copied: a new M<Mail::Internet> object is returned.
=cut

sub dup()
{   my $self = shift;
    my $dup  = ref($self)->new;

    my $body = $self->{mail_inet_body} || [];
    my $head = $self->{mail_inet_head};;

    $dup->{mail_inet_body} = [ @$body ];
    $dup->{mail_inet_head} = $head->dup if $head;
    $dup;
}

=section Accessors

=method body [BODY]

Returns the body of the message. This is a reference to an array.
Each entry in the array represents a single line in the message.

If I<BODY> is given, it can be a reference to an array or an array, then
the body will be replaced. If a reference is passed, it is used directly
and not copied, so any subsequent changes to the array will change the
contents of the body.
=cut

sub body(;$@)
{   my $self = shift;

    return $self->{mail_inet_body} ||= []
        unless @_;

    $self->{mail_inet_body} = ref $_[0] eq 'ARRAY' ? $_[0] : [ @_ ];
}

=method head
Returns the C<Mail::Header> object which holds the headers for the current
message
=cut

sub head         { shift->{mail_inet_head} ||= Mail::Header->new }

=section Processing the message as a whole

=method print [FILEHANDLE]
Print the header, body or whole message to file descriptor I<FILEHANDLE>.
I<$fd> should be a reference to a GLOB. If I<FILEHANDLE> is not given the
output will be sent to STDOUT.

=example
    $mail->print( \*STDOUT );  # Print message to STDOUT
=cut

sub print($)
{   my $self = shift;
    my $fd   = shift || \*STDOUT;

    $self->print_header($fd)
       and print $fd "\n"
       and $self->print_body($fd);
}

=method print_header [FILEHANDLE]
Print only the header to the FILEHANDLE (default STDOUT).

=method print_body [FILEHANDLE]
Print only the body to the FILEHANDLE (default STDOUT).
=cut

sub print_header($) { shift->head->print(@_) }

sub print_body($)
{   my $self = shift;
    my $fd   = shift || \*STDOUT;

    foreach my $ln (@{$self->body})
    {    print $fd $ln or return 0;
    }

    1;
}

=method as_string
Returns the message as a single string.
=cut

sub as_string()
{   my $self = shift;
    $self->head->as_string . "\n" . join '', @{$self->body};
}

=method as_mbox_string [ALREADY_ESCAPED]
Returns the message as a string in mbox format.  C<ALREADY_ESCAPED>, if
given and true, indicates that M<escape_from()> has already been called on
this object.
=cut

sub as_mbox_string($)
{   my $self    = shift->dup;
    my $escaped = shift;

    $self->head->delete('Content-Length');
    $self->escape_from unless $escaped;
    $self->as_string . "\n";
}

=section Processing the header

Most of these methods are simply wrappers around methods provided
by M<Mail::Header>.

=method header [ARRAY-of-LINES]
See M<Mail::Header::header()>.

=method fold [LENGTH]
See M<Mail::Header::fold()>.

=method fold_length [TAG], [LENGTH]
See M<Mail::Header::fold_length()>.

=method combine TAG, [WITH]
See M<Mail::Header::combine()>.
=cut

sub header       { shift->head->header(@_) }
sub fold         { shift->head->fold(@_) }
sub fold_length  { shift->head->fold_length(@_) }
sub combine      { shift->head->combine(@_) }

=method add PAIRS-of-FIELD
The PAIRS are field-name and field-content.  For each PAIR,
M<Mail::Header::add()> is called.  All fields are added after
existing fields.  The last addition is returned.
=cut

sub add(@)
{   my $head = shift->head;
    my $ret;
    while(@_)
    {   my ($tag, $line) = splice @_, 0, 2;
        $ret = $head->add($tag, $line, -1)
            or return undef;
    }

    $ret;
}

=method replace PAIRS-of-FIELD
The PAIRS are field-name and field-content.  For each PAIR,
M<Mail::Header::replace()> is called with INDEX 0. If a FIELD is already
in the header, it will be removed first.  Do not specified the same
field-name twice.
=cut

sub replace(@)
{   my $head = shift->head;
    my $ret;

    while(@_)
    {   my ($tag, $line) = splice @_, 0, 2;
        $ret = $head->replace($tag, $line, 0)
             or return undef;
    }

    $ret;
}

=method get TAG, [TAGs]
In LIST context, all fields with the name TAG are returned.  In SCALAR
context, only the first field which matches the earliest TAG is returned.
M<Mail::Header::get()> is called to collect the data.
=cut

sub get(@)
{   my $head = shift->head;

    return map { $head->get($_) } @_
        if wantarray;

    foreach my $tag (@_)
    {   my $r = $head->get($tag);
        return $r if defined $r;
    }

    undef;
}

=method delete TAG, [TAGs]
Delete all fields with the name TAG.  M<Mail::Header::delete()> is doing the
work.
=cut

sub delete(@)
{   my $head = shift->head;
    map { $head->delete($_) } @_;
}

# Undocumented; unused???
sub empty()
{   my $self = shift;
    %$self = ();
    1;
}

=section Processing the body

=method remove_sig [NLINES]
Attempts to remove a users signature from the body of a message. It does this 
by looking for a line equal to C<'-- '> within the last C<NLINES> of the
message. If found then that line and all lines after it will be removed. If
C<NLINES> is not given a default value of 10 will be used. This would be of
most use in auto-reply scripts.
=cut

sub remove_sig($)
{   my $body   = shift->body;
    my $nlines = shift || 10;
    my $start  = @$body;

    my $i    = 0;
    while($i++ < $nlines && $start--)
    {   next if $body->[$start] !~ /^--[ ]?[\r\n]/;

        splice @$body, $start, $i;
        last;
    }
}

=method sign OPTIONS
Add your signature to the body.  M<remove_sig()> will strip existing
signatures first.

=option  File FILEHANDLE
=default File C<undef>
Take from the FILEHANDLE all lines starting from the first C<< -- >>.

=option  Signature STRING|ARRAY-of-LINES
=default Signature []
=cut

sub sign(@)
{   my ($self, %arg) = @_;
    my ($sig, @sig);

    if($sig = delete $arg{File})
    {   local *SIG;

        if(open(SIG, $sig))
        {   local $_;
            while(<SIG>) { last unless /^(--)?\s*$/ }
            @sig = ($_, <SIG>, "\n");
            close SIG;
        }
    }
    elsif($sig = delete $arg{Signature})
    {    @sig = ref($sig) ? @$sig : split(/\n/, $sig);
    }

    if(@sig)
    {   $self->remove_sig;
        s/[\r\n]*$/\n/ for @sig;
        push @{$self->body}, "-- \n", @sig;
    }

    $self;
}

=method tidy_body
Removes all leading and trailing lines from the body that only contain
white spaces.
=cut

sub tidy_body()
{   my $body = shift->body;

    shift @$body while @$body && $body->[0]  =~ /^\s*$/;
    pop @$body   while @$body && $body->[-1] =~ /^\s*$/;
    $body;
}

=section High-level functionality

=method reply OPTIONS
Create a new object with header initialised for a reply to the current 
object. And the body will be a copy of the current message indented.

The C<.mailhdr> file in your home directory (if exists) will be read
first, to provide defaults.

=option  ReplyAll BOOLEAN
=default ReplyAll C<false>
Automatically include all To and Cc addresses of the original mail,
excluding those mentioned in the Bcc list.

=option  Indent STRING
=default Indent 'E<gt>'
Use as indentation string.  The string may contain C<%%> to get a single C<%>,
C<%f> to get the first from name, C<%F> is the first character of C<%f>,
C<%l> is the last name, C<%L> its first character, C<%n> the whole from
string, and C<%I> the first character of each of the names in the from string.

=option  Keep ARRAY-of-FIELDS
=default Keep []
Copy the listed FIELDS from the original message.

=option  Exclude ARRAY-of-FIELDS
=default Exclude []
Remove the listed FIELDS from the produced message.
=cut

sub reply(@)
{   my ($self, %arg) = @_;
    my $class = ref $self;
    my @reply;

    local *MAILHDR;
    if(open(MAILHDR, "$ENV{HOME}/.mailhdr")) 
    {    # User has defined a mail header template
         @reply = <MAILHDR>;
         close MAILHDR;
    }

    my $reply = $class->new(\@reply);

    # The Subject line
    my $subject = $self->get('Subject') || "";
    $subject = "Re: " . $subject
        if $subject =~ /\S+/ && $subject !~ /Re:/i;

    $reply->replace(Subject => $subject);

    # Locate who we are sending to
    my $to = $self->get('Reply-To')
          || $self->get('From')
          || $self->get('Return-Path')
          || "";

    my $sender = (Mail::Address->parse($to))[0];

    my $name = $sender->name;
    unless(defined $name)
    {    my $fr = $self->get('From');
         defined $fr and $fr   = (Mail::Address->parse($fr))[0];
         defined $fr and $name = $fr->name;
    }

    my $indent = $arg{Indent} || ">";
    if($indent =~ /\%/) 
    {   my %hash = ( '%' => '%');
        my @name = $name ? grep( {length $_} split /[\n\s]+/, $name) : '';

        $hash{f} = $name[0];
        $hash{F} = $#name ? substr($hash{f},0,1) : $hash{f};

        $hash{l} = $#name ? $name[$#name] : "";
        $hash{L} = substr($hash{l},0,1) || "";

        $hash{n} = $name || "";
        $hash{I} = join "", map {substr($_,0,1)} @name;

        $indent  =~ s/\%(.)/defined $hash{$1} ? $hash{$1} : $1/eg;
    }

    my $id     = $sender->address;
    $reply->replace(To => $id);

    # Find addresses not to include
    my $mailaddresses = $ENV{MAILADDRESSES} || "";

    my %nocc = (lc($id) => 1);
    $nocc{lc $_->address} = 1
        for Mail::Address->parse($reply->get('Bcc'), $mailaddresses);

    if($arg{ReplyAll})   # Who shall we copy this to
    {   my %cc;
        foreach my $addr (Mail::Address->parse($self->get('To'), $self->get('Cc'))) 
        {   my $lc   = lc $addr->address;
            $cc{$lc} = $addr->format
                 unless $nocc{$lc};
        }
        my $cc = join ', ', values %cc;
        $reply->replace(Cc => $cc);
    }

    # References
    my $refs    = $self->get('References') || "";
    my $mid     = $self->get('Message-Id');

    $refs      .= " " . $mid if defined $mid;
    $reply->replace(References => $refs);

    # In-Reply-To
    my $date    = $self->get('Date');
    my $inreply = "";

    if(defined $mid)
    {    $inreply  = $mid;
         $inreply .= ' from ' . $name if defined $name;
         $inreply .= ' on '   . $date if defined $date;
    }
    elsif(defined $name)
    {    $inreply  = $name    . "'s message";
         $inreply .= "of "    . $date if defined $date;
    }
    $reply->replace('In-Reply-To' => $inreply);

    # Quote the body
    my $body  = $reply->body;
    @$body = @{$self->body};    # copy body
    $reply->remove_sig;
    $reply->tidy_body;
    s/\A/$indent/ for @$body;

    # Add references
    unshift @{$body}, (defined $name ? $name . " " : "") . "<$id> writes:\n";

    if(defined $arg{Keep} && ref $arg{Keep} eq 'ARRAY')      # Include lines
    {   foreach my $keep (@{$arg{Keep}}) 
        {    my $ln = $self->get($keep);
             $reply->replace($keep => $ln) if defined $ln;
        }
    }

    if(defined $arg{Exclude} && ref $arg{Exclude} eq 'ARRAY') # Exclude lines
    {    $reply->delete(@{$arg{Exclude}});
    }

    $reply->head->cleanup;      # remove empty header lines
    $reply;
}

=method smtpsend [OPTIONS]

Send a Mail::Internet message using direct SMTP.  to the given
ADDRESSES, each can be either a string or a reference to a list of email
addresses. If none of C<To>, <Cc> or C<Bcc> are given then the addresses
are extracted from the message being sent.

The return value will be a list of email addresses that the message was sent
to. If the message was not sent the list will be empty.

Requires M<Net::SMTP> and M<Net::Domain> to be installed.

=option  Host HOSTNAME
=default Host C<$ENV{SMTPHOSTS}>

Name of the SMTP server to connect to, or a Net::SMTP object to use

If C<Host> is not given then the SMTP host is found by attempting
connections first to hosts specified in C<$ENV{SMTPHOSTS}>, a colon
separated list, then C<mailhost> and C<localhost>.

=option  MailFrom ADDRESS
=default MailFrom C<Mail::Util::mailaddress()>
The e-mail address which is used as sender.  By default,
M<Mail::Util::mailaddress()> provides the address of the sender.

=option  To ADDRESSES
=default To C<undef>
=option  Cc ADDRESSES
=default Cc C<undef>
=option  Bcc ADDRESSES
=default Bcc C<undef>

=option  Hello STRING
=default Hello C<localhost.localdomain>
Send a HELO (or EHLO) command to the server with the given name.

=option  Port INTEGER
=default Port 25
Port number to connect to on remote host

=option  Debug BOOLEAN
=default Debug <false>
Debug value to pass to Net::SMPT, see <Net::SMTP>
=cut

sub smtpsend($@)
{   my ($self, %opt) = @_;

    require Net::SMTP;
    require Net::Domain;

    my $host     = $opt{Host};
    my $envelope = $opt{MailFrom} || mailaddress();
    my $quit     = 1;

    my ($smtp, @hello);

    push @hello, Hello => $opt{Hello}
        if defined $opt{Hello};

    push @hello, Port => $opt{Port}
	if exists $opt{Port};

    push @hello, Debug => $opt{Debug}
	if exists $opt{Debug};

    if(!defined $host)
    {   local $SIG{__DIE__};
	my @hosts = qw(mailhost localhost);
	unshift @hosts, split /\:/, $ENV{SMTPHOSTS}
            if defined $ENV{SMTPHOSTS};

	foreach $host (@hosts)
        {   $smtp = eval { Net::SMTP->new($host, @hello) };
	    last if defined $smtp;
	}
    }
    elsif(ref($host) && UNIVERSAL::isa($host,'Net::SMTP'))
    {   $smtp = $host;
	$quit = 0;
    }
    else
    {   local $SIG{__DIE__};
	$smtp = eval { Net::SMTP->new($host, @hello) };
    }

    defined $smtp or return ();

    my $head = $self->cleaned_header_dup;

    # Who is it to

    my @rcpt = map { ref $_ ? @$_ : $_ } grep { defined } @opt{'To','Cc','Bcc'};
    @rcpt    = map { $head->get($_) } qw(To Cc Bcc)
	unless @rcpt;

    my @addr = map {$_->address} Mail::Address->parse(@rcpt);
    @addr or return ();

    $head->delete('Bcc');

    # Send it

    my $ok = $smtp->mail($envelope)
          && $smtp->to(@addr)
          && $smtp->data(join("", @{$head->header}, "\n", @{$self->body}));

    $quit && $smtp->quit;
    $ok ? @addr : ();
}

=method send [TYPE, [ARGS...]]
Send a Mail::Internet message using M<Mail::Mailer>.  TYPE and ARGS are
passed on to M<Mail::Mailer::new()>.
=cut

sub send($@)
{   my ($self, $type, @args) = @_;

    require Mail::Mailer;

    my $head  = $self->cleaned_header_dup;
    my $mailer = Mail::Mailer->new($type, @args);

    $mailer->open($head->header_hashref);
    $self->print_body($mailer);
    $mailer->close;
}

=method nntppost [OPTIONS]
Post an article via NNTP.  Requires M<Net::NNTP> to be installed.

=requires Host HOSTNAME|Net::NNTP object
Name of NNTP server to connect to, or a Net::NNTP object to use.

=option  Port INTEGER
=default Port 119
Port number to connect to on remote host

=option  Debug BOOLEAN
=default Debug <false>
Debug value to pass to Net::NNTP, see L<Net::NNTP>

=cut

sub nntppost
{   my ($self, %opt) = @_;

    require Net::NNTP;

    my $groups = $self->get('Newsgroups') || "";
    my @groups = split /[\s,]+/, $groups;
    @groups or return ();

    my $head   = $self->cleaned_header_dup;

    # Remove these incase the NNTP host decides to mail as well as me
    $head->delete(qw(To Cc Bcc)); 

    my $news;
    my $quit   = 1;

    my $host   = $opt{Host};
    if(ref($host) && UNIVERSAL::isa($host,'Net::NNTP'))
    {   $news = $host;
	$quit = 0;
    }
    else
    {   my @opt = $opt{Host};

	push @opt, Port => $opt{Port}
	    if exists $opt{Port};

	push @opt, Debug => $opt{Debug}
	    if exists $opt{Debug};

	$news = Net::NNTP->new(@opt)
	    or return ();
    }

    $news->post(@{$head->header}, "\n", @{$self->body});
    my $rc = $news->code;

    $news->quit if $quit;

    $rc == 240 ? @groups : ();
}

=method escape_from
It can cause problems with some applications if a message contains a line
starting with C<`From '>, in particular when attempting to split a folder.
This method inserts a leading C<`>'> on anyline that matches the regular
expression C</^>*From/>
=cut

sub escape_from
{   my $body = shift->body;
    scalar grep { s/\A(>*From) />$1 /o } @$body;
}


=method unescape_from ()
Remove the escaping added by M<escape_from()>.
=cut

sub unescape_from
{   my $body = shift->body;
    scalar grep { s/\A>(>*From) /$1 /o } @$body;
}

# Don't tell people it exists
sub cleaned_header_dup()
{   my $head = shift->head->dup;

    $head->delete('From '); # Just in case :-)

    # An original message should not have any Received lines
    $head->delete('Received');

    $head->replace('X-Mailer', "Perl5 Mail::Internet v".$Mail::Internet::VERSION)
        unless $head->count('X-Mailer');

    my $name = eval {local $SIG{__DIE__}; (getpwuid($>))[6]} || $ENV{NAME} ||"";

    while($name =~ s/\([^\(\)]*\)//) { 1; }

    if($name =~ /[^\w\s]/)
    {   $name =~ s/"/\"/g;
	$name = '"' . $name . '"';
    }

    my $from = sprintf "%s <%s>", $name, mailaddress();
    $from =~ s/\s{2,}/ /g;

    foreach my $tag (qw(From Sender))
    {   $head->get($tag) or $head->add($tag, $from);
    }

    $head;
}

1;
