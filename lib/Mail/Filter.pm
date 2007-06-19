use strict;
package Mail::Filter;

use Carp;
=head1 NAME

Mail::Filter - Filter mail through multiple subroutines

=head1 SYNOPSIS

 use Mail::Filter;
    
 my $filter = Mail::Filter->new( \&filter1, \&filter2 );
    
 my $mail   = Mail::Internet->new( [<>] );
 my $mail   = $filter->filter($mail);

 my $folder = Mail::Folder->new( .... );
 my $filter->filter($folder);

=head1 DESCRIPTION

C<Mail::Filter> provides an interface to filtering Email through multiple
subroutines.

C<Mail::Filter> filters mail by calling each filter subroutine in turn. Each
filter subroutine is called with two arguments, the first is the filter
object and the second is the mail or folder object being filtered.

The result from each filter sub is passed to the next filter as the mail
object. If a filter subroutine returns undef, then C<Mail::Filter> will abort
and return immediately.

The function returns the result from the last subroutine to operate on the 
mail object.  

=chapter METHODS

=section Constructors

=c_method new [FILTER [, ... ]]
Create a new C<Mail::Filter> object with the given filter subroutines. Each
filter may be either a code reference or the name of a method to call
on the <Mail::Filter> object.

=cut

sub new(@)
{   my $class = shift;
    bless { filters => [ @_ ] }, $class;
}

=section Accessors
=method add FILTER [, FILTER ...]
Add the given filters to the end of the fliter list.
=cut

sub add(@)
{   my $self = shift;
    push @{$self->{filters}}, @_;
}

=section Processing

=method filter MAIL-OBJECT | MAIL-FOLDER
If the first argument is a C<Mail::Internet> object, then this object will
be passed through the filter list. If the first argument is a C<Mail::Folder>
object, then each message in turn will be passed through the filter list.
=cut

sub _filter($)
{   my ($self, $mail) = @_;

    foreach my $sub ( @{$self->{filters}} )
    {   my $mail
          = ref $sub eq 'CODE' ? $sub->($self,$mail)
	  : !ref $sub          ? $self->$sub($mail)
	  : carp "Cannot call filter '$sub', ignored";

	ref $mail or last;
    }

    $mail;
}

sub filter
{   my ($self, $obj) = @_;
    if($obj->isa('Mail::Folder'))
    {   $self->{folder} = $obj;
	foreach my $m ($obj->message_list)
	{   my $mail = $obj->get_message($m) or next;
	    $self->{msgnum} = $m;
	    $self->_filter($mail);
	}
	delete $self->{folder};
	delete $self->{msgnum};
    }
    elsif($obj->isa('Mail::Internet'))
    {   return $self->filter($obj);
    }
    else
    {   carp "Cannot process '$obj'";
	return undef;
    }
}

=method folder
While the C<filter> method is called with a C<Mail::Folder> object, these
filter subroutines can call this method to obtain the folder object that is
being processed.
=cut

sub folder() {shift->{folder}}

=method msgnum
If the C<filter> method is called with a C<Mail::Folder> object, then the
filter subroutines may call this method to obtain the message number
of the message that is being processed.
=cut

sub msgnum() {shift->{msgnum}}

1;
