#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0);
use Manage::Utils qw(
	_getenv 
);
use Manage::EntryComposite;
my $ec = new EntryComposite(
	title => _getenv('title'), 
	label => _getenv('label'),
	width => _getenv('width'),
	params => \@ARGV,
	options => {"list-multiple" => _getenv("list-multiple", 0)}
);
$ec->give(_getenv 'item');
$ec->relaunch;
