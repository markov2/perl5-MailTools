#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Mail::Field::Date;
use base 'Mail::Field';

use strict;
use warnings;

use Date::Format qw/time2str/;
use Date::Parse  qw/str2time/;

(bless [])->register('Date');

#--------------------
=chapter NAME

Mail::Field::Date - a date header field

=chapter SYNOPSIS
  use HTTP::Date 'time2iso';
  my $field = Mail::Field->new(Date => time2iso());

=chapter DESCRIPTION
Represents one "Date" header field.

=chapter METHODS

=method set %options
=option  Time SECONDS
=default Time undef

=option  TimeStr STRING
=default TimeStr undef
A string acceptable to Date::Parse.

=cut

sub set()
{	my $self = shift;
	my $arg = @_ == 1 ? shift : { @_ };

	foreach my $s (qw(Time TimeStr))
	{	if(exists $arg->{$s})
		     { $self->{$s} = $arg->{$s} }
		else { delete $self->{$s} }
	}

	$self;
}

sub parse($)
{	my $self = shift;
	delete $self->{Time};
	$self->{TimeStr} = shift;
	$self;
}

#--------------------
=section Smart accessors

=method time [$time]
Query (or change) the $time (as stored in the field) in seconds.
=cut

sub time(;$)
{	my $self = shift;

	if(@_)
	{	delete $self->{TimeStr};
		return $self->{Time} = shift;
	}

	$self->{Time} ||= str2time $self->{TimeStr};
}

sub stringify
{	my $self = shift;
	$self->{TimeStr} ||= time2str("%a, %e %b %Y %T %z", $self->time);
}

sub reformat
{	my $self = shift;
	$self->time($self->time);
	$self->stringify;
}

1;
