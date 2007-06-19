require 5.005;

use ExtUtils::MakeMaker;

WriteMakefile
 ( DISTNAME  => 'MailTools'
 , VERSION   => '2.00_01'
 , NAME      => 'Mail'
 , AUTHOR    => 'Mark Overmeer <perl@overmeer.net>'
 , ABSTRACT  => 'Various Mail related modules'

 , PREREQ_PM =>
   { Net::SMTP   => 1.03
   , Net::Domain => 1.05
   , IO::Handle  => 0.00
   , Test::More  => 0.00
   , Test::Pod   => 1.00
   }
);

sub MY::postamble {

  return '' unless $] >= 5.00503;

<<'ESQ';

all:: ppd
dist: ppd

# for OODoc's oodist, DIST
RAWDIR		= ../public_html/mailtools/raw
DISTDIR		= ../public_html/mailtools/source
LICENSE		= artistic

# for OODoc's oodist, POD
FIRST_YEAR	= 1995
EMAIL		= perl@overmeer.net
WEBSITE		= http://perl.overmeer.net/log-report/

ESQ
}

