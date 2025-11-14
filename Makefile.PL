require 5.008001;

use ExtUtils::MakeMaker;

my $version  = '2.23';
my $git      = "https://github.com/markov2/perl5-MailTools";
my $publish  = "../public_html/mailtools";
my $homepage = "http://perl.overmeer.net/CPAN/";

my %oodist   = (
	oodoc_version => 3.05,
	first_year => 1995,
	email    => "markov\@cpan.org",

	include  => [
	],

	use      => [
	],

	parser   => {
		syntax         => 'markov',
		skip_links     => [
		],
		pmhead         => undef,
	},

	tests    => {
	},

	release  => {
		publish        => "$publish/source",
	},

	raw      => {
		publish        => "$publish/raw",
	},

	generate => [
	  {
		# Add real pod to the releases
		format         => 'pod3',
		podtail        => "PODTAIL.txt",
	  },
 	  # You may add HTML formatters here.
 		  # You may add exporter configurations here.
	],
);

my %requires = (
	'Date::Format' => 0,
	'Date::Parse'  => 0,
	'IO::Handle'   => 0.00,
	'Net::Domain'  => 1.05,
	'Net::SMTP'    => 1.28,
	'Test::More'   => 0,

#XXX next deps missing on purpose, to avoid installing a lot which is rarely used:
#	'Authen::SASL'
#	'Net::SMTP::SSL'
);

WriteMakefile
	NAME      => 'MailTools',
	DISTNAME  => 'MailTools',
	VERSION   => $version,
	AUTHOR    => 'Mark Overmeer <markov@cpan.org>',
	ABSTRACT  => 'Various ancient e-mail related modules',
	LICENSE   => 'perl_5',
	PREREQ_PM => \%requires,   # support old Perls

	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources   => {
			repository => {
				type => 'git',
				url  => "$git.git",
				web  => $git,
			},
			bugtracker => {
				web  => "$git/issues",
			},
			homepage => $homepage,
			license  => [ 'http//dev.perl.org/licenses/' ],
		},
		prereqs => {
			runtime => {
#				requires => \%requires,
			},
			develop => {
				requires => {
					'OODoc' => '3.00',
				},
			},
			test => {
				requires => {
#					'Test::More' => 1.00,
					'Test::Pod'  => 1.00,
				},
			},
		},

		# You may use multiple set-ups, see "oodist --make"
		x_oodist => \%oodist,
	};
