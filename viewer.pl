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
	_combine
	_getenv 
	_value_or_else 
	_text_info
);
use Manage::Resolver qw(
	@inputs
	inputs_title
);
use Manage::PageComposite;
my $params = @inputs ? \@inputs : \@ARGV;
(new PageComposite(
	title => inputs_title("View files ..."), 
	width => _getenv('width'),
	params => $params
))->relaunch;

