use strict;

package Mail::Mailer::testfile;
use base 'Mail::Mailer::rfc822';

use Mail::Util qw/mailaddress/;

our %config = (outfile => 'mailer.testfile');
my $num = 0;

sub can_cc { 0 }

sub exec($$$)
{   my ($self, $exe, $args, $to) = @_;

    open F, '>>', $Mail::Mailer::testfile::config{outfile};
    print F "\n===\ntest ", ++$num, " ",
            (scalar localtime),
            "\nfrom: " . mailaddress(),
            "\nto: " . join(' ',@{$to}), "\n\n";
    close F;

    untie *$self if tied *$self;
    tie *$self, 'Mail::Mailer::testfile::pipe', $self;
    $self;
}

sub close { 1 }

package Mail::Mailer::testfile::pipe;

sub TIEHANDLE
{   my ($class, $self) = @_;
    bless \$self, $class;
}

sub PRINT
{   my $self = shift;
    open F, '>>', $Mail::Mailer::testfile::config{outfile};
    print F @_;
    close F;
}

1;
