#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'experimental';
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_getenv 
	_value_or_else 
	_text_info
	@_inputs
	_xselection
);

