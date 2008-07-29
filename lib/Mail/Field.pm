package Mail::Field;

use Carp;
use strict;
use Mail::Field::Generic;

=chapter NAME

Mail::Field - Base class for manipulation of mail header fields

=chapter SYNOPSIS

 use Mail::Field;
    
 my $field = Mail::Field->new('Subject', 'some subject text');
 my $field = Mail::Field->new(Subject => 'some subject text');
 print $field->tag,": ",$field->stringify,"\n";

 my $field = Mail::Field->subject('some subject text');

=chapter DESCRIPTION

C<Mail::Field> creates and manipulates fields in MIME headers, collected
within a M<Mail::Header> object.  Different field types have their
own sub-class (extension), defining additional useful accessors to the
field content.

People are invited to merge their implementation to special fields into
MailTools, to maintain a consistent set of packages and documentation.

=chapter METHODS
=cut

sub _header_pkg_name
{   my $header = lc shift;
    $header    =~ s/((\b|_)\w)/\U$1/g;

    if(length($header) > 8)
    {   my @header = split /[-_]+/, $header;
        my $chars  = int((7 + @header) / @header) || 1;
        $header    = substr join('', map {substr $_,0,$chars} @header), 0, 8;
    }
    else
    {   $header =~ s/[-_]+//g;
    }

    'Mail::Field::' . $header;
}

sub _require_dir
{   my($class,$dir,$dir_sep) = @_;

    local *DIR;
    opendir DIR, $dir
        or return;

    my @inc;
    foreach my $f (readdir DIR)
    {   $f =~ /^([\w\-]+)/ or next;
        my $p = $1;
        my $n = "$dir$dir_sep$p";

        if(-d $n )
        {   _require_dir("${class}::$f", $n, $dir_sep);
        }
        else
        {   $p =~ s/-/_/go;
            eval "require ${class}::$p";
        }
    }
    closedir DIR;
}

sub import
{   my $class = shift;

    if(@_)
    {   local $_;
        eval "require " . _header_pkg_name($_) || die $@
            for @_;
        return;
    }

    my($dir,$dir_sep);
    foreach my $f (keys %INC)
    {   next if $f !~ /^Mail(\W)Field\W/i;
        $dir_sep = $1;
        $dir = ($INC{$f} =~ /(.*Mail\W+Field)/i)[0] . $dir_sep;
        last;
    }

    _require_dir('Mail::Field', $dir, $dir_sep);
}

# register a header class, this creates a new method in Mail::Field
# which will call new on that class
sub register
{   my $thing  = shift;
    my $method = lc shift;
    my $class  = shift || ref($thing) || $thing;

    $method    =~ tr/-/_/;
    $class     = _header_pkg_name $method
	if $class eq "Mail::Field";

    croak "Re-register of $method"
	if Mail::Field->can($method);

    no strict 'refs';
    *{$method} = sub {
	shift;
	$class->can('stringify') or eval "require $class" or die $@;
	$class->_build(@_);
    };
}

# the *real* constructor
# if called with one argument then the `parse' method will be called
# otherwise the `create' method is called

sub _build
{   my $self = bless {}, shift;
    @_==1 ? $self->parse(@_) : $self->create(@_);
}

=section Constructors
Mail::Field (and it's sub-classes) define several methods which return
new objects. These can all be categorized as constructor.

=c_method new TAG [, STRING | OPTIONS]
Create an object in the class which defines the field specified by
the TAG argument.

=error Undefined subroutine <method> called
Mail::Field objects use autoloading to compile new functionality.
Apparently, the mehod called is not implemented for the specific
class of the field object.
=cut

sub new
{   my $class = shift;
    my $field = lc shift;
    $field =~ tr/-/_/;
    $class->$field(@_);
}

=c_method combine FIELDS

Take a LIST of C<Mail::Field> objects (which should all be of the same
sub-class) and create a new object in that same class.

=cut

sub combine {confess "Combine not implemented" }

our $AUTOLOAD;
sub AUTOLOAD
{   my $method = $AUTOLOAD;
    $method    =~ s/.*:://;

    $method    =~ /^[^A-Z\x00-\x1f\x80-\xff :]+$/
        or croak "Undefined subroutine &$AUTOLOAD called";

    my $class = _header_pkg_name $method;

    unless(eval "require $class")
    {   my $tag = $method;
        $tag    =~ s/_/-/g;
        $tag    = join '-',
            map { /^[b-df-hj-np-tv-z]+$|^MIME$/i ? uc($_) : ucfirst(lc $_) }
                split /\-/, $tag;

        no strict;
        @{"${class}::ISA"} = qw(Mail::Field::Generic);
        *{"${class}::tag"} = sub { $tag };
    }

    Mail::Field->can($method)
        or $class->register($method);

    goto &$AUTOLOAD;
}

=c_method extract TAG, HEAD [, INDEX ]
Takes as arguments the tag name, a C<Mail::Head> object
and optionally an index.

If the index argument is given then C<extract> will retrieve the given tag
from the C<Mail::Head> object and create a new C<Mail::Field> based object.
I<undef> will be returned in the field does not exist.

If the index argument is not given the the result depends on the context
in which C<extract> is called. If called in a scalar context the result
will be as if C<extract> was called with an index value of zero. If called
in an array context then all tags will be retrieved and a list of
C<Mail::Field> objects will be returned.
=cut

# Of course, the functionality should have been in the Mail::Header class
sub extract
{   my ($class, $tag, $head) = (shift, shift, shift);

    my $method = lc $tag;
    $method    =~ tr/-/_/;

    if(@_==0 && wantarray)
    {   my @ret;
        my $text;  # need real copy!
        foreach $text ($head->get($tag))
        {   chomp $text;
            push @ret, $class->$method($text);
        }
        return @ret;
    }

    my $idx  = shift || 0;
    my $text = $head->get($tag,$idx)
        or return undef;

    chomp $text;
    $class->$method($text);
}

=section "Fake" constructors

=method create OPTIONS
This constructor is used internally with preprocessed field information.
When called on an existing object, its original content will get
replaced.
=cut

# before 2.00, this method could be called as class method, however
# not all extensions supported that.
sub create
{   my ($self, %arg) = @_;
    %$self = ();
    $self->set(\%arg);
}

=method parse
Parse a field line.
=cut

# before 2.00, this method could be called as class method, however
# not all extensions supported that.
sub parse
{   my $class = ref shift;
    confess "parse() not implemented";
}

=section Accessors

=method stringify
Returns the field as a string.
=cut

sub stringify { confess "stringify() not implemented" } 

=ci_method tag
Return the tag (in the correct case) for this item.  Well, actually any
casing is OK, because the field tags are treated case-insentitive; however
people have some preferences.
=cut

sub tag
{   my $thing = shift;
    my $tag   = ref($thing) || $thing;
    $tag =~ s/.*:://;
    $tag =~ s/_/-/g;

    join '-',
        map { /^[b-df-hj-np-tv-z]+$|^MIME$/i ? uc($_) : ucfirst(lc $_) }
            split /\-/, $tag;
}

=method set OPTIONS
Change the settings (the content, but then smart) of this field.
=cut

sub set(@) { confess "set() not implemented" }

# prevent the calling of AUTOLOAD for DESTROY :-)
sub DESTROY {}

=section Smart accessors

=method text [STRING]
Without arguments, the field is returned as M<stringify()> does.  Otherwise,
the STRING is parsed with M<parse()> to replace the object's content.

It is more clear to call either M<stringify()> or M<parse()> directly, because
this method does not add additional processing.
=cut

sub text
{   my $self = shift;
    @_ ? $self->parse(@_) : $self->stringify;
}

=chapter DETAILS

=section SUB-CLASS PACKAGE NAMES

All sub-classes should be called Mail::Field::I<name> where I<name> is
derived from the tag using these rules.

=over 4

=item *
Consider a tag as being made up of elements separated by '-'

=item *
Convert all characters to lowercase except the first in each element, which
should be uppercase.

=item *
I<name> is then created from these elements by using the first
N characters from each element.

=item *
N is calculated by using the formula :-

    int((7 + #elements) / #elements)

=item *
I<name> is then limited to a maximum of 8 characters, keeping the first 8
characters.

=back

For an example of this take a look at the definition of the 
C<_header_pkg_name()> subroutine in C<Mail::Field>

=cut

1;
