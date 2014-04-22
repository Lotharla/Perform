#!/usr/local/bin/perl
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0);
use Manage::Utils qw(
	_chomp
	_combine
	_getenv 
	_value_or_else 
);
use Manage::ViewComposite;
my @params = @ARGV ? @ARGV : _getenv('NAUTILUS_SCRIPT_SELECTED_FILE_PATHS');
my $ec = new ViewComposite(
	title => _getenv('title'), 
	width => _getenv('width'),
	params => \@params
);
MainLoop();
