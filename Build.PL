
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Distribute (biological) analyses on the local SGE grid",
  "dist_author" => [
    "Joachim Bargsten <jwb\@cpan.org>"
  ],
  "dist_name" => "Bio-Grid-Run-SGE",
  "dist_version" => "0.031",
  "license" => "perl",
  "module_name" => "Bio::Grid::Run::SGE",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
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
  "script_files" => [
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
  "test_requires" => {
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.3601",
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
