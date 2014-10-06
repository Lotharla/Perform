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
	_getenv 
	_value_or_else 
	_text_info
	@_inputs
	_inputs_title
);
use Manage::PageComposite;
my $title = _getenv('title', "View files ...");
(new PageComposite(
	title => $title eq 'Clipper' ? $title : _inputs_title($title), 
	params => \@_inputs
))->relaunch;

