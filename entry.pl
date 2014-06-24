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
	_chomp
	_combine
	_getenv 
	_value_or_else 
);
use Manage::EntryComposite;
new EntryComposite(
	title => _getenv('title'), 
	label => _getenv('label'),
	width => _getenv('width'),
	params => \@ARGV
);
MainLoop();
