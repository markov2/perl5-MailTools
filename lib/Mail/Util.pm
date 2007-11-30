use strict;

package Mail::Util;
use base 'Exporter';

our @EXPORT_OK = qw(read_mbox maildomain mailaddress);

use Carp;
sub Version { our $VERSION }

my ($domain, $mailaddress);
my @sendmailcf = qw(/etc /etc/sendmail /etc/ucblib
    /etc/mail /usr/lib /var/adm/sendmail);

=chapter NAME

Mail::Util - mail utility functions

=chapter SYNOPSIS

  use Mail::Util qw( ... );

=chapter DESCRIPTION

This package provides several mail related utility functions. Any function
required must by explicitly listed on the use line to be exported into
the calling package.

=chapter FUNCTIONS

=function read_mbox FILE
Read FILE, a binmail mailbox file, and return a list of  references.
Each reference is a reference to an array containg one message.

WARNING:
This method does not quote lines which accidentally also start with the
message separator C<From>, so this implementation can be considered
broken.  See M<Mail::Box::Mbox>
=cut

sub read_mbox($)
{   my $file  = shift;

    local *FH;
    open FH,'<', $file
	or croak "cannot open '$file': $!\n";

    local $_;
    my @mbox;
    my $mail  = [];
    my $blank = 1;

    while(<FH>)
    {   if($blank && /^From .*\d{4}/)
        {   push @mbox, $mail if @$mail;
	    $mail  = [ $_ ];
	    $blank = 0;
	}
	else
        {   $blank = m/^$/ ? 1 : 0;
	    push @$mail, $_;
	}
    }

    push @mbox, $mail if @$mail;
    close FH;

    wantarray ? @mbox : \@mbox;
}

=function maildomain
Attempt to determine the current uers mail domain string via the following
methods

=over 4

=item * Look for the MAILDOMAIN enviroment variable, which can be set from outside the program.  This is by far the best way to configure the domain.

=item * Look for a sendmail.cf file and extract DH parameter

=item * Look for a smail config file and usr the first host defined in hostname(s)

=item * Try an SMTP connect (if Net::SMTP exists) first to mailhost then localhost

=item * Use value from Net::Domain::domainname (if Net::Domain exists)

=back

WARNING:
On modern machines, there is only one good way to provide information to
this method: the first; always explicitly configure the MAILDOMAIN.

=example
 # in your main script
 $ENV{MAILDOMAIN} = 'example.com';

 # everywhere else
 use Mail::Util 'maildomain';
 print maildomain;
=cut

sub maildomain()
{   return $domain
	if defined $domain;

    $domain = $ENV{MAILDOMAIN}
        and return $domain;

    # Try sendmail configuration file

    my $config = (grep -r, map {"$_/sendmail.cf"} @sendmailcf)[0];

    local *CF;
    local $_;
    if(defined $config && open CF, '<', $config)
    {   my %var;
	while(<CF>)
        {   if(my ($v, $arg) = /^D([a-zA-Z])([\w.\$\-]+)/)
            {   $arg =~ s/\$([a-zA-Z])/exists $var{$1} ? $var{$1} : '$'.$1/eg;
		$var{$v} = $arg;
	    }
	}
	close CF;
	$domain = $var{j} if defined $var{j};
	$domain = $var{M} if defined $var{M};

        $domain = $1
            if $domain && $domain =~ m/([A-Za-z0-9](?:[\.\-A-Za-z0-9]+))/;

	return $domain
	    if defined $domain && $domain !~ /\$/;
    }

    # Try smail config file if exists

    if(open CF, '<', "/usr/lib/smail/config")
    {   while(<CF>)
        {   if( /\A\s*hostnames?\s*=\s*(\S+)/ )
            {   $domain = (split /\:/,$1)[0];
		last;
	    }
	}
	close CF;

	return $domain
	    if defined $domain;
    }

    # Try a SMTP connection to 'mailhost'

    if(eval {require Net::SMTP})
    {   foreach my $host (qw(mailhost localhost))
        {   # hosts are local, so short timeout
            my $smtp = eval { Net::SMTP->new($host, Timeout => 5) };
	    if(defined $smtp)
            {   $domain = $smtp->domain;
		$smtp->quit;
		last;
	    }
	}
    }

    # Use internet(DNS) domain name, if it can be found
    $domain = Net::Domain::domainname()
        if !defined $domain && eval {require Net::Domain};

    $domain ||= "localhost";
}

=function mailaddress

Return a guess at the current users mail address. The user can force
the return value by setting the MAILADDRESS environment variable.

WARNING:
When not supplied via the environment variable, <mailaddress> looks at
various configuration files and other environmental data. Although this
seems to be smart behavior, this is not predictable enough (IMHO) to
be used.  Please set the MAILADDRESS explicitly, and do not trust on
the "automatic detection", even when that produces a correct address
(on the moment)

=example
 # in your main script
 $ENV{MAILADDRESS} = 'me@example.com';

 # everywhere else
 use Mail::Util 'mailaddress';
 print mailaddress;
=cut

sub mailaddress()
{  return $mailaddress
       if defined $mailaddress;

    # Get user name from environment
    $mailaddress = $ENV{MAILADDRESS};

    unless($mailaddress || $^O ne 'MacOS')
    {   require Mac::InternetConfig;

        no strict;
	Mac::InternetConfig->import;
	$mailaddress = $InternetConfig{kICEmail()};
    }

    $mailaddress ||= $ENV{USER} || $ENV{LOGNAME} || eval {getpwuid $>}
                 ||  "postmaster";

    # Add domain if it does not exist
    $mailaddress .= '@' . maildomain
	if $mailaddress !~ /\@/;

    $mailaddress =~ s/(^.*<|>.*$)//g;
    $mailaddress;
}

1;
