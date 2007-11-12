package Mail::Cap;
use strict;

sub Version { our $VERSION }

=chapter NAME

Mail::Cap - Parse mailcap files

=chapter SYNOPSIS

 my $mc = new Mail::Cap;
 $desc = $mc->description('image/gif');

 print "GIF desc: $desc\n";
 $cmd = $mc->viewCmd('text/plain; charset=iso-8859-1', 'file.txt');

=chapter DESCRIPTION

Parse mailcap files as specified in "RFC 1524 --A User Agent
Configuration Mechanism For Multimedia Mail Format Information>.  In
the description below C<$type> refers to the MIME type as specified in
the C<Content-Type> header of mail or HTTP messages.  Examples of
types are:

  image/gif
  text/html
  text/plain; charset=iso-8859-1

You could also take a look at the M<File::MimeInfo> distribution, which
are accessing tables which are used by many applications on a system,
and therefore have succeeded the mail-cap specifications on modern
(UNIX) systems.
=cut

our $useCache = 1;  # don't evaluate tests every time

my @path;
if($^O eq "MacOS")
{   @path = split /\,/, $ENV{MAILCAPS} || "$ENV{HOME}mailcap";
}
else
{   @path = split /\:/
      , ( $ENV{MAILCAPS} || (defined $ENV{HOME} ? "$ENV{HOME}/.mailcap:" : '')
        . '/etc/mailcap:/usr/etc/mailcap:/usr/local/etc/mailcap'
        );   # this path is specified under RFC1524 appendix A 
}

=chapter METHODS

=section Constructors

=c_method new OPTIONS
Create and initialize a new Mail::Cap object.  If you give it an
argument it will try to parse the specified file.  Without any
arguments it will search for the mailcap file using the standard
mailcap path, or the MAILCAPS environment variable if it is defined.

=option take 'ALL'|'FIRST'
=default take 'FIRST'
Include all mailcap files you can find.  By default, only the first
file is parsed, however the RFC tells us to include ALL.  To maintain
backwards compatibility, the default only takes the FIRST.

=option  filename FILENAME
=default filename C<undef>
Add the specified file to the list to standard locations.  This file
is tried first.

=examples
  $mcap = new Mail::Cap;
  $mcap = new Mail::Cap "/mydir/mailcap";
  $mcap = new Mail::Cap filename => "/mydir/mailcap";
  $mcap = new Mail::Cap take => 'ALL';
  $mcap = Mail::Cap->new(take => 'ALL');

=cut

sub new
{   my $class = shift;
    
    unshift @_, 'filename' if @_ % 2;
    my %args  = @_;

    my $take_all = $args{take} && uc $args{take} eq 'ALL';

    my $self  = bless {_count => 0}, $class;

    $self->_process_file($args{filename})
        if defined $args{filename} && -r $args{filename};

    if(!defined $args{filename} || $take_all)
    {   foreach my $fname (@path)
        {   -r $fname or next;

            $self->_process_file($fname);
            last unless $take_all;
        }
    }

    unless($self->{_count})
    {   # Set up default mailcap
        $self->{'audio/*'} = [{'view' => "showaudio %s"}];
        $self->{'image/*'} = [{'view' => "xv %s"}];
        $self->{'message/rfc822'} = [{'view' => "xterm -e metamail %s"}];
    }

    $self;
}

sub _process_file
{   my $self = shift;
    my $file = shift or return;

    local *MAILCAP;
    open MAILCAP, $file
        or return;

    $self->{_file} = $file;

    local $_;
    while(<MAILCAP>)
    {   next if /^\s*#/; # comment
        next if /^\s*$/; # blank line
        $_ .= <MAILCAP> while s/\\\s*$//; # continuation line
        chomp;
        s/\0//g;            # ensure no NULs in the line
        s/([^\\]);/$1\0/g;  # make field separator NUL

        my @parts = split /\s*\0\s*/, $_;
        my $type  = shift @parts;
        $type    .= "/*" if $type !~ m[/];

        my $view  = shift @parts;
        $view     =~ s/\\;/;/g;
        my %field = (view => $view);

        foreach (@parts)
        {   my($key, $val) = split /\s*\=\s*/, $_, 2;
            $val =~ s/\\;/;/g if defined $val;
            $field{$key} = defined $val ? $val : 1;
        }

        if(my $test = $field{test})
        {   unless ($test =~ /\%/)
            {   # No parameters in test, can perform it right away
                system $test;
                next if $?;
            }
        }

        # record this entry
        unless(exists $self->{$type})
        {   $self->{$type} = [];
            $self->{_count}++; 
        }
        push @{$self->{$type}}, \%field;
    }

    close MAILCAP;
}

=section Run commands
These methods invoke a suitable progam presenting or manipulating the
media object in the specified file.  They all return C<1> if a command
was found, and C<0> otherwise.  You might test C<$?> for the outcome
of the command.

=method view TYPE, FILE
=method compose TYPE, FILE
=method edit TYPE, FILE
=method print TYPE, FILE
=cut

sub view    { my $self = shift; $self->_run($self->viewCmd(@_))    }
sub compose { my $self = shift; $self->_run($self->composeCmd(@_)) }
sub edit    { my $self = shift; $self->_run($self->editCmd(@_))    }
sub print   { my $self = shift; $self->_run($self->printCmd(@_))   }

sub _run($)
{   my ($self, $cmd) = @_;
    defined $cmd or return 0;

    system $cmd;
    1;
}

=section Command creator

These methods return a string that is suitable for feeding to system()
in order to invoke a suitable progam presenting or manipulating the
media object in the specified file.  It will return C<undef> if no
suitable specification exists.

=method viewCmd TYPE, FILE
=method composeCmd TYPE, FILE
=method editCmd TYPE, FILE
=method printCmd TYPE, FILE
=cut

sub viewCmd    { shift->_createCommand(view    => @_) }
sub composeCmd { shift->_createCommand(compose => @_) }
sub editCmd    { shift->_createCommand(edit    => @_) }
sub printCmd   { shift->_createCommand(print   => @_) }

sub _createCommand($$$)
{   my ($self, $method, $type, $file) = @_;
    my $entry = $self->getEntry($type, $file);

    $entry && exists $entry->{$method}
        or return undef;

    $self->expandPercentMacros($entry->{$method}, $type, $file);
}

sub makeName($$)
{   my ($self, $type, $basename) = @_;
    my $template = $self->nametemplate($type)
        or return $basename;

    $template =~ s/%s/$basename/g;
    $template;
}

=section Look-up definitions
Methods return the corresponding mailcap field for the type.

=method field TYPE, FIELD
Returns the specified field for the type.  Returns undef if no
specification exsists.
=cut

sub field($$)
{   my($self, $type, $field) = @_;
    my $entry = $self->getEntry($type);
    $entry->{$field};
}

=method description TYPE
=method textualnewlines TYPE
=method x11_bitmap TYPE
=method nametemplate TYPE
=cut

sub description     { shift->field(shift, 'description');     }
sub textualnewlines { shift->field(shift, 'textualnewlines'); }
sub x11_bitmap      { shift->field(shift, 'x11-bitmap');      }
sub nametemplate    { shift->field(shift, 'nametemplate');    }

sub getEntry
{   my($self, $origtype, $file) = @_;

    return $self->{_cache}{$origtype}
        if $useCache && exists $self->{_cache}{$origtype};

    my ($fulltype, @params) = split /\s*;\s*/, $origtype;
    my ($type, $subtype)    = split m[/], $fulltype, 2;
    $subtype ||= '';

    my $entry;
    foreach (@{$self->{"$type/$subtype"}}, @{$self->{"$type/*"}})
    {   if(exists $_->{'test'})
        {   # must run test to see if it applies
            my $test = $self->expandPercentMacros($_->{'test'},
        					  $origtype, $file);
            system $test;
            next if $?;
        }
        $entry = { %$_ };  # make copy
        last;
    }
    $self->{_cache}{$origtype} = $entry if $useCache;
    $entry;
}

sub expandPercentMacros
{   my ($self, $text, $type, $file) = @_;
    defined $type or return $text;
    defined $file or $file = "";

    my ($fulltype, @params) = split /\s*;\s*/, $type;
    ($type, my $subtype)    = split m[/], $fulltype, 2;

    my %params;
    foreach (@params)
    {   my($key, $val) = split /\s*=\s*/, $_, 2;
        $params{$key} = $val;
    }
    $text =~ s/\\%/\0/g;        # hide all escaped %'s
    $text =~ s/%t/$fulltype/g;  # expand %t
    $text =~ s/%s/$file/g;      # expand %s
    {   # expand %{field}
        local $^W = 0;  # avoid warnings when expanding %params
        $text =~ s/%\{\s*(.*?)\s*\}/$params{$1}/g;
    }
    $text =~ s/\0/%/g;
    $text;
}

# This following procedures can be useful for debugging purposes

sub dumpEntry
{   my($hash, $prefix) = @_;
    defined $prefix or $prefix = "";
    print "$prefix$_ = $hash->{$_}\n"
        for sort keys %$hash;
}

sub dump
{   my $self = shift;
    foreach (keys %$self)
    {   next if /^_/;
        print "$_\n";
        foreach (@{$self->{$_}})
        {   dumpEntry($_, "\t");
            print "\n";
        }
    }

    if(exists $self->{_cache})
    {   print "Cached types\n";
        print "\t$_\n"
            for keys %{$self->{_cache}};
    }
}

1;
