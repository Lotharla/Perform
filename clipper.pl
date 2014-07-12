#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_chomp
	_getenv 
	_value_or_else 
	_files_in_dir
	_clipdir
);
use Manage::Resolver qw(
	@given
	given_title
);
use Manage::ViewComposite;
my $dir = _clipdir;
my @files = _files_in_dir($dir, 1);
push @files, '';
(new ViewComposite(
	title => $dir, 
	params => \@files
))->relaunch;

