#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'experimental';
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path __FILE__);
use Manage::ViewComposite;
(new ViewComposite(
	title => 'Clipper', 
))->relaunch;

