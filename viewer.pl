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
	@given
	given_title
);
use Manage::ViewComposite;
my $params = @given ? \@given : \@ARGV;
(new ViewComposite(
	title => given_title("View files ..."), 
	width => _getenv('width'),
	params => $params
))->relaunch;

