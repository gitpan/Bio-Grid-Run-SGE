
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Distribute (biological) analyses on the local SGE grid",
  "AUTHOR" => "Joachim Bargsten <jwb\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Bio-Grid-Run-SGE",
  "EXE_FILES" => [
    "bin/mail.pl",
    "bin/cat_by_regex.pl",
    "bin/dummy_worker.pl",
    "bin/test_sendmail.pl",
    "bin/qstat-jwb",
    "bin/cl_muscle_example.pl",
    "bin/qfake.pl",
    "bin/rmrex",
    "bin/distribution",
    "bin/mail.sh",
    "bin/jclone",
    "bin/cat.pl",
    "bin/rocksblast",
    "bin/log2debug.pl",
    "bin/qtime-dist",
    "bin/qtime"
  ],
  "LICENSE" => "perl",
  "NAME" => "Bio::Grid::Run::SGE",
  "PREREQ_PM" => {
    "Bio::Gonzales" => 0,
    "Clone" => 0,
    "Config::Auto" => 0,
    "Config::IniFiles" => 0,
    "Data::Printer" => 0,
    "Error" => 0,
    "File::HomeDir" => 0,
    "File::Slurp" => 0,
    "File::Spec" => 0,
    "Getopt::Long::Descriptive" => 0,
    "HTTP::Date" => 0,
    "IO::Prompt::Tiny" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => 0,
    "Mail::Sendmail" => 0,
    "Mouse" => 0,
    "Params::Util" => 0,
    "Storable" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "XML::LibXML" => 0,
    "parent" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "0.01",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Bio::Gonzales" => 0,
  "Clone" => 0,
  "Config::Auto" => 0,
  "Config::IniFiles" => 0,
  "Data::Printer" => 0,
  "Error" => 0,
  "File::HomeDir" => 0,
  "File::Slurp" => 0,
  "File::Spec" => 0,
  "Getopt::Long::Descriptive" => 0,
  "HTTP::Date" => 0,
  "IO::Prompt::Tiny" => 0,
  "List::MoreUtils" => 0,
  "List::Util" => 0,
  "Mail::Sendmail" => 0,
  "Mouse" => 0,
  "Params::Util" => 0,
  "Storable" => 0,
  "Test::More" => 0,
  "Try::Tiny" => 0,
  "URI" => 0,
  "XML::LibXML" => 0,
  "parent" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



