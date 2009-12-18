package Mail::Header;

use strict;
use Carp;

my $MAIL_FROM = 'KEEP';
my %HDR_LENGTHS = ();

# Pattern to match a RFC822 Field name ( Extract from RFC #822)
#
#     field       =  field-name ":" [ field-body ] CRLF
#
#     field-name  =  1*<any CHAR, excluding CTLs, SPACE, and ":">
#
#     CHAR        =  <any ASCII character>        ; (  0-177,  0.-127.)
#     CTL         =  <any ASCII control           ; (  0- 37,  0.- 31.)
#		      character and DEL>          ; (    177,     127.)
# I have included the trailing ':' in the field-name
#
our $FIELD_NAME = '[^\x00-\x1f\x7f-\xff :]+:';

=head1 NAME

Mail::Header - manipulate MIME headers

=head1 SYNOPSIS

 use Mail::Header;
    
 my $head = Mail::Header->new;
 my $head = Mail::Header->new( \*STDIN );
 my $head = Mail::Header->new( [<>], Modify => 0);

=chapter DESCRIPTION
Read, write, create, and manipulate MIME headers, the leading part
of each modern e-mail message, but also used in other protocols
like HTTP.  The fields are kept in M<Mail::Field> objects.

Be aware that the header fields each have a name part, which shall
be treated case-insensitive, and a content part, which may be folded
over multiple lines.  

Mail::Header does not always follow the RFCs strict enough, does not
help you with character encodings.  It does not use weak references
where it could (because those did not exist when the module was written)
which costs some performance and make the implementation a little more
complicated.  The M<Mail::Message::Head> implementation is much newer
and therefore better.

=cut

##
## Private functions
##

sub _error { warn @_; () }

# tidy up internal hash table and list

sub _tidy_header
{   my $self    = shift;
    my $deleted = 0;

    for(my $i = 0 ; $i < @{$self->{mail_hdr_list}}; $i++)
    {   next if defined $self->{mail_hdr_list}[$i];

        splice @{$self->{mail_hdr_list}}, $i, 1;
        $deleted++;
        $i--;
    }

    if($deleted)
    {   local $_;
        my @del;

        while(my ($key,$ref) = each %{$self->{mail_hdr_hash}} )
        {   push @del, $key
	       unless @$ref = grep { ref $_ && defined $$_ } @$ref;
        }

        delete $self->{'mail_hdr_hash'}{$_} for @del;
    }
}

# fold the line to the given length

my %STRUCTURE = map { (lc $_ => undef) }
  qw{ To Cc Bcc From Date Reply-To Sender
      Resent-Date Resent-From Resent-Sender Resent-To Return-Path
      list-help list-post list-unsubscribe Mailing-List
      Received References Message-ID In-Reply-To
      Content-Length Content-Type Content-Disposition
      Delivered-To
      Lines
      MIME-Version
      Precedence
      Status
    };

sub _fold_line
{   my($ln,$maxlen) = @_;

    $maxlen = 20
       if $maxlen < 20;

    my $max = int($maxlen - 5);         # 4 for leading spcs + 1 for [\,\;]
    my $min = int($maxlen * 4 / 5) - 4;

    $_[0] =~ s/[\r\n]+//og;        # Remove new-lines
    $_[0] =~ s/\s*\Z/\n/so;        # End line with a EOLN

    return if $_[0] =~ /^From\s/io;

    if(length($_[0]) > $maxlen)
    {   if($_[0] =~ /^([-\w]+)/ && exists $STRUCTURE{ lc $1 } )
        {   #Split the line up
            # first bias towards splitting at a , or a ; >4/5 along the line
            # next split a whitespace
            # else we are looking at a single word and probably don't want to split
            my $x = "";
            $x .= "$1\n " while $_[0] =~
                s/^\s*
                   ( [^"]{$min,$max} [,;]
                   | [^"]{1,$max}    [,;\s]
                   | [^\s"]*(?:"[^"]*"[ \t]?[^\s"]*)+\s
                   ) //x;

            $x .= $_[0];
            $_[0] = $x;
            $_[0] =~ s/(\A\s+|[\t ]+\Z)//sog;
            $_[0] =~ s/\s+\n/\n/sog;
        }
        else
        {   $_[0] =~ s/(.{$min,$max})(\s)/$1\n$2/g;
            $_[0] =~ s/\s*$/\n/s;
        }
    }

    $_[0] =~ s/\A(\S+)\n\s*(?=\S)/$1 /so; 
}

# Tags are case-insensitive, but there is a (slightly) prefered construction
# being all characters are lowercase except the first of each word. Also
# if the word is an `acronym' then all characters are uppercase. We decide
# a word is an acronym if it does not contain a vowel.
# In general, this change of capitization is a bad idea, but it is in
# the code for ages, and therefore probably crucial for existing
# applications.

sub _tag_case
{   my $tag = shift;
    $tag =~ s/\:$//;
    join '-'
      , map { /^[b-df-hj-np-tv-z]+$|^(?:MIME|SWE|SOAP|LDAP|ID)$/i
              ? uc($_) : ucfirst(lc($_))
            } split m/\-/, $tag, -1;
}

# format a complete line
#  ensure line starts with the given tag
#  ensure tag is correct case
#  change the 'From ' tag as required
#  fold the line

sub _fmt_line
{   my ($self, $tag, $line, $modify) = @_;
    $modify ||= $self->{mail_hdr_modify};
    my $ctag = undef;

    ($tag) = $line =~ /^($FIELD_NAME|From )/oi
        unless defined $tag;

    if(defined $tag && $tag =~ /^From /io && $self->{mail_hdr_mail_from} ne 'KEEP')
    {   if($self->{mail_hdr_mail_from} eq 'COERCE')
        {   $line =~ s/^From /Mail-From: /o;
            $tag = "Mail-From:";
        }
        elsif($self->{mail_hdr_mail_from} eq 'IGNORE')
        {   return ();
        }
        elsif($self->{mail_hdr_mail_from} eq 'ERROR')
        {    return _error "unadorned 'From ' ignored: <$line>";
        }
    }

    if(defined $tag)
    {   $tag  = _tag_case($ctag = $tag);
        $ctag = $tag if $modify;
        $ctag =~ s/([^ :])$/$1:/o if defined $ctag;
    }

    defined $ctag && $ctag =~ /^($FIELD_NAME|From )/oi
        or croak "Bad RFC822 field name '$tag'\n";

    # Ensure the line starts with tag
    if(defined $ctag && ($modify || $line !~ /^\Q$ctag\E/i))
    {   (my $xtag = $ctag) =~ s/\s*\Z//o;
        $line =~ s/^(\Q$ctag\E)?\s*/$xtag /i;
    }

    my $maxlen = $self->{mail_hdr_lengths}{$tag}
              || $HDR_LENGTHS{$tag}
              || $self->fold_length;

    _fold_line $line, $maxlen
        if $modify && defined $maxlen;

    $line =~ s/\n*$/\n/so;
    ($tag, $line);
}

sub _insert
{   my ($self, $tag, $line, $where) = @_;

    if($where < 0)
    {   $where = @{$self->{mail_hdr_list}} + $where + 1;
        $where = 0 if $where < 0;
    }
    elsif($where >= @{$self->{mail_hdr_list}})
    {   $where = @{$self->{mail_hdr_list}};
    }

    my $atend = $where == @{$self->{mail_hdr_list}};
    splice @{$self->{mail_hdr_list}}, $where, 0, $line;

    $self->{mail_hdr_hash}{$tag} ||= [];
    my $ref = \${$self->{mail_hdr_list}}[$where];

    my $def = $self->{mail_hdr_hash}{$tag};
    if($def && $where)
    {   if($atend) { push @$def, $ref }
        else
        {   my $i = 0;
            foreach my $ln (@{$self->{mail_hdr_list}})
            {   my $r = \$ln;
                last if $r == $ref;
                $i++ if $r == $def->[$i];
            }
            splice @$def, $i, 0, $ref;
        }
    }
    else
    {    unshift @$def, $ref;
    }
}

=chapter METHODS

=section Constructors

=ci_method new [ARG], [OPTIONS]

ARG may be either a file descriptor (reference to a GLOB)
or a reference to an array. If given the new object will be
initialized with headers either from the array of read from 
the file descriptor.

OPTIONS is a list of options given in the form of key-value
pairs, just like a hash table. Valid options are

=option  Modify BOOLEAN
=default Modify C<true>

If this value is I<true> then the headers will be re-formatted,
otherwise the format of the header lines will remain unchanged.

=option  MailFrom 'IGNORE'|'COERCE'|'KEEP'|'ERROR'
=default MailFrom 'KEEP'
See method M<mail_from()>.

=option  FoldLength INTEGER
=default FoldLength 79
The default length of line to be used when folding header lines.
See M<fold_length()>.
=cut

sub new
{   my $call  = shift;
    my $class = ref($call) || $call;
    my $arg   = @_ % 2 ? shift : undef;
    my %opt   = @_;

    $opt{Modify} = delete $opt{Reformat}
        unless exists $opt{Modify};

    my $self = bless
      { mail_hdr_list     => []
      , mail_hdr_hash     => {}
      , mail_hdr_modify   => (delete $opt{Modify} || 0)
      , mail_hdr_foldlen  => 79
      , mail_hdr_lengths  => {}
      }, $class;

    $self->mail_from( uc($opt{MailFrom} || $MAIL_FROM) );

    $self->fold_length($opt{FoldLength})
        if exists $opt{FoldLength};

    if(!ref $arg)               {}
    elsif(ref($arg) eq 'ARRAY') { $self->extract( [ @$arg ] ) }
    elsif(defined fileno($arg)) { $self->read($arg) }

    $self;
}

=method dup
Create a duplicate of the current object.
=cut

sub dup
{   my $self = shift;
    my $dup  = ref($self)->new;

    %$dup    = %$self;
    $dup->empty;      # rebuild tables

    $dup->{mail_hdr_list} = [ @{$self->{mail_hdr_list}} ];

    foreach my $ln ( @{$dup->{mail_hdr_list}} )
    {    my $tag = _tag_case +($ln =~ /^($FIELD_NAME|From )/oi)[0];
         push @{$dup->{mail_hdr_hash}{$tag}}, \$ln;
    }

    $dup;
}

=section "Fake" constructors
Be warned that the next constructors all require an already created
header object, of which the original content will be destroyed.

=method extract ARRAY
Extract a header from the given array into an existing Mail::Header
object. C<extract> B<will modify> this array.
Returns the object that the method was called on.
=cut

sub extract
{   my ($self, $lines) = @_;
    $self->empty;

    while(@$lines && $lines->[0] =~ /^($FIELD_NAME|From )/o)
    {    my $tag  = $1;
         my $line = shift @$lines;
         $line   .= shift @$lines
             while @$lines && $lines->[0] =~ /^[ \t]+/o;

         ($tag, $line) = _fmt_line $self, $tag, $line;

         _insert $self, $tag, $line, -1
             if defined $line;
    }

    shift @$lines
        if @$lines && $lines->[0] =~ /^\s*$/o;

    $self;
}

=method read FILEHANDLE
Read a header from the given file descriptor into an existing Mail::Header
object.
=cut

sub read
{   my ($self, $fd) = @_;

    $self->empty;

    my ($tag, $line);
    my $ln = '';
    while(1)
    {   $ln = <$fd>;

        if(defined $ln && defined $line && $ln =~ /\A[ \t]+/o)
        {   $line .= $ln;
            next;
        }

        if(defined $line)
        {   ($tag, $line) = _fmt_line $self, $tag, $line;
            _insert $self, $tag, $line, -1
	        if defined $line;
        }

        defined $ln && $ln =~ /^($FIELD_NAME|From )/o
            or last;

        ($tag, $line) = ($1, $ln);
    }

    $self;
}

=method empty
Empty an existing C<Mail::Header> object of all lines.
=cut

sub empty
{   my $self = shift;
    $self->{mail_hdr_list} = [];
    $self->{mail_hdr_hash} = {};
    $self;
}

=method header [ARRAY]
C<header> does multiple operations. First it will extract a header from
the ARRAY, if given. It will then reformat the header (if reformatting
is permitted), and finally return a reference to an array which
contains the header in a printable form.
=cut

sub header
{   my $self = shift;

    $self->extract(@_)
	if @_;

    $self->fold
        if $self->{mail_hdr_modify};

    [ @{$self->{mail_hdr_list}} ];
}

=method header_hashref [HASH]
As M<header()>, but it will eventually set headers from a hash
reference, and it will return the headers as a hash reference.

=example
 $fields->{From} = 'Tobias Brox <tobix@cpan.org>';
 $fields->{To}   = ['you@somewhere', 'me@localhost'];
 $head->header_hashref($fields);
=cut

### text kept, for educational purpose... originates from 2000/03
# This can probably be optimized. I didn't want to mess much around with
# the internal implementation as for now...
# -- Tobias Brox <tobix@cpan.org>

sub header_hashref
{   my ($self, $hashref) = @_;

    while(my ($key, $value) = each %$hashref)
    {   $self->add($key, $_) for ref $value ? @$value : $value;
    }

    $self->fold
        if $self->{mail_hdr_modify};

    defined wantarray  # MO, added minimal optimization
        or return;

    +{ map { ($_ => [$self->get($_)] ) }   # MO: Eh?
           keys %{$self->{mail_hdr_hash}}
     }; 
}

=section Accessors

=method modify [VALUE]
If C<VALUE> is I<false> then C<Mail::Header> will not do any automatic
reformatting of the headers, other than to ensure that the line
starts with the tags given.
=cut

sub modify
{   my $self = shift;
    my $old  = $self->{mail_hdr_modify};

    $self->{mail_hdr_modify} = 0 + shift
	if @_;

    $old;
}

=method mail_from 'IGNORE'|'COERCE'|'KEEP'|'ERROR'
This specifies what to do when a C<`From '> line is encountered.
Valid values are C<IGNORE> - ignore and discard the header,
C<ERROR> - invoke an error (call die), C<COERCE> - rename them as Mail-From
and C<KEEP> - keep them.
=cut

sub mail_from
{   my $thing  = shift;
    my $choice = uc shift;

    $choice =~ /^(IGNORE|ERROR|COERCE|KEEP)$/ 
	or die "bad Mail-From choice: '$choice'";

    if(ref $thing) { $thing->{mail_hdr_mail_from} = $choice }
    else           { $MAIL_FROM = $choice }

    $thing;
}

=method fold_length [TAG], [LENGTH]
Set the default fold length for all tags or just one. With no arguments
the default fold length is returned. With two arguments it sets the fold
length for the given tag and returns the previous value. If only C<LENGTH>
is given it sets the default fold length for the current object.

In the two argument form C<fold_length> may be called as a static method,
setting default fold lengths for tags that will be used by B<all>
C<Mail::Header> objects. See the C<fold> method for
a description on how C<Mail::Header> uses these values.
=cut

sub fold_length
{   my $thing = shift;
    my $old;

    if(@_ == 2)
    {   my $tag = _tag_case shift;
        my $len = shift;

        my $hash = ref $thing ? $thing->{mail_hdr_lengths} : \%HDR_LENGTHS;
        $old     = $hash->{$tag};
        $hash->{$tag} = $len > 20 ? $len : 20;
    }
    else
    {   my $self = $thing;
        my $len  = shift;
        $old = $self->{mail_hdr_foldlen};

        if(defined $len)
        {    $self->{mail_hdr_foldlen} = $len > 20 ? $len : 20;
             $self->fold if $self->{mail_hdr_modify};
        }
    }

    $old;
}

=section Processing

=method fold [LENGTH]
Fold the header. If LENGTH is not given, then C<Mail::Header> uses the
following rules to determine what length to fold a line.
=cut

sub fold
{   my ($self, $maxlen) = @_;

    while(my ($tag, $list) = each %{$self->{mail_hdr_hash}})
    {   my $len = $maxlen
             || $self->{mail_hdr_lengths}{$tag}
             || $HDR_LENGTHS{$tag}
             || $self->fold_length;

        foreach my $ln (@$list)
        {    _fold_line $$ln, $len
                 if defined $ln;
        }
    }

    $self;
}

=method unfold [TAG]
Unfold all instances of the given tag so that they do not spread across
multiple lines. If C<TAG> is not given then all lines are unfolded.

The unfolding process is wrong but (for compatibility reasons) will
not be repaired: only one blank at the start of the line should be
removed, not all of them.
=cut

sub unfold
{   my $self = shift;

    if(@_)
    {   my $tag  = _tag_case shift;
        my $list = $self->{mail_hdr_hash}{$tag}
            or return $self;

        foreach my $ln (@$list)
        {   $$ln =~ s/\r?\n\s+/ /sog
                if defined $ln && defined $$ln;
        }

        return $self;
    }

    while( my ($tag, $list) = each %{$self->{mail_hdr_hash}})
    {   foreach my $ln (@$list)
        {   $$ln =~ s/\r?\n\s+/ /sog
	        if defined $ln && defined $$ln;
        }
    }

    $self;
}

=method add TAG, LINE [, INDEX]

Add a new line to the header. If TAG is C<undef> the the tag will be
extracted from the beginning of the given line. If INDEX is given,
the new line will be inserted into the header at the given point, otherwise
the new line will be appended to the end of the header.
=cut

sub add
{   my ($self, $tag, $text, $where) = @_;
    ($tag, my $line) = _fmt_line $self, $tag, $text;

    defined $tag && defined $line
        or return undef;

    defined $where
        or $where = -1;

    _insert $self, $tag, $line, $where;

    $line =~ /^\S+\s(.*)/os;
    $1;
}

=method replace TAG, LINE [, INDEX ]
Replace a line in the header.  If TAG is C<undef> the the tag will be
extracted from the beginning of the given line. If INDEX is given
the new line will replace the Nth instance of that tag, otherwise the
first instance of the tag is replaced. If the tag does not appear in the
header then a new line will be appended to the header.
=cut

sub replace
{   my $self = shift;
    my $idx  = @_ % 2 ? pop @_ : 0;

    my ($tag, $line);
  TAG:
    while(@_)
    {   ($tag,$line) = _fmt_line $self, splice(@_,0,2);

        defined $tag && defined $line
            or return undef;

        my $field = $self->{mail_hdr_hash}{$tag};
        if($field && defined $field->[$idx])
             { ${$field->[$idx]} = $line }
        else { _insert $self, $tag, $line, -1 }
    }

    $line =~ /^\S+\s*(.*)/os;
    $1;
}

=method combine TAG [, WITH]
Combine all instances of TAG into one. The lines will be
joined together WITH, or a single space if not given. The new
item will be positioned in the header where the first instance was, all
other instances of TAG will be removed.
=cut

sub combine
{   my $self = shift;
    my $tag  = _tag_case shift;
    my $with = shift || ' ';

    $tag =~ /^From /io && $self->{mail_hdr_mail_from} ne 'KEEP'
        and return _error "unadorned 'From ' ignored";

    my $def = $self->{mail_hdr_hash}{$tag}
        or return undef;

    return $def->[0]
        if @$def <= 1;

    my @lines = $self->get($tag);
    chomp @lines;

    my $line = (_fmt_line $self, $tag, join($with,@lines), 1)[1];

    $self->{mail_hdr_hash}{$tag} = [ \$line ];
    $line;
}

=method get TAG [, INDEX]

Get the text from a line. If an INDEX is given, then the text of the Nth
instance will be returned. If it is not given the return value depends on the
context in which C<get> was called. In an array context a list of all the
text from all the instances of the TAG will be returned. In a scalar context
the text for the first instance will be returned.

The lines are unfolded, but still terminated with a new-line (see C<chomp>)
=cut

sub get
{   my $self = shift;
    my $tag = _tag_case shift;
    my $idx = shift;

    my $def = $self->{mail_hdr_hash}{$tag}
        or return ();

    my $l = length $tag;
    $l   += 1 if $tag !~ / $/o;

    if(defined $idx || !wantarray)
    {    $idx ||= 0;
         defined $def->[$idx] or return undef;
         my $val = ${$def->[$idx]};
         defined $val or return undef;

	 $val = substr $val, $l;
	 $val =~ s/^\s+//;
         return $val;
    }

    map { my $tmp = substr $$_,$l; $tmp =~ s/^\s+//; $tmp } @$def;
}


=method count TAG
Returns the number of times the given atg appears in the header
=cut

sub count
{   my $self = shift;
    my $tag  = _tag_case shift;
    my $def  = $self->{mail_hdr_hash}{$tag};
    defined $def ? scalar(@$def) : 0;
}


=method delete TAG [, INDEX ]
Delete a tag from the header. If an INDEX id is given, then the Nth instance
of the tag will be removed. If no INDEX is given, then all instances
of tag will be removed.
=cut

sub delete
{   my $self = shift;
    my $tag  = _tag_case shift;
    my $idx  = shift;
    my @val;

    if(my $def = $self->{mail_hdr_hash}{$tag})
    {   my $l = length $tag;
        $l   += 2 if $tag !~ / $/;

        if(defined $idx)
        {   if(defined $def->[$idx])
            {   push @val, substr ${$def->[$idx]}, $l;
                undef ${$def->[$idx]};
            }
        }
        else
        {   @val = map {my $x = substr $$_,$l; undef $$_; $x } @$def;
        }

        _tidy_header($self);
    }

    @val;
}


=method print [FILEHANDLE]
Print the header to the given file descriptor, or C<STDOUT> if no
file descriptor is given.
=cut

sub print
{   my $self = shift;
    my $fd   = shift || \*STDOUT;

    foreach my $ln (@{$self->{mail_hdr_list}})
    {   defined $ln or next;
        print $fd $ln or return 0;
    }

    1;
}

=method as_string
Returns the header as a single string.
=cut

sub as_string { join '', grep {defined} @{shift->{mail_hdr_list}} }

=method tags
Returns an array of all the tags that exist in the header. Each tag will
only appear in the list once. The order of the tags is not specified.
=cut

sub tags { keys %{shift->{mail_hdr_hash}} }

=method cleanup
Remove any header line that, other than the tag, only contains whitespace
=cut

sub cleanup
{   my $self = shift;
    my $deleted = 0;

    foreach my $key (@_ ? @_ : keys %{$self->{mail_hdr_hash}})
    {   my $fields = $self->{mail_hdr_hash}{$key};
        foreach my $field (@$fields)
        {   next if $$field =~ /^\S+\s+\S/s;
            undef $$field;
            $deleted++;
        }
    }

    _tidy_header $self
        if $deleted;

    $self;  
}

1;
